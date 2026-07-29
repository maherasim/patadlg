import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';
import 'location_service.dart';
import '../utils/time_format.dart';

const _alertChannel = AndroidNotificationChannel(
  'default_channel',
  'General Notifications',
  description: 'Attendance reminders and case updates',
  importance: Importance.high,
);

/// Runs in Android's persistent foreground service (its own isolate/engine —
/// see flutter_foreground_task's architecture), so it can't reach the main
/// isolate's ApiClient singleton directly. It rebuilds a Dio client pointed at
/// the same on-disk cookie jar path ApiClient uses, which is enough to pick up
/// the already-authenticated session cookie without a fresh login.
@pragma('vm:entry-point')
void startLocationTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(_AttendanceLocationTaskHandler());
}

class _AttendanceLocationTaskHandler extends TaskHandler {
  Dio? _dio;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _notificationsReady = false;

  // In-memory debounce flags — this isolate is re-created whenever the
  // foreground service (re)starts, so these naturally reset on app restart.
  bool _wasLocationDisabled = false;
  bool _wasOutsideGeofence = false;

  Future<void> _ensureNotificationsReady() async {
    if (_notificationsReady) return;
    _notificationsReady = true;

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_alertChannel);
  }

  Future<void> _showAlert(int id, String title, String body) async {
    await _ensureNotificationsReady();
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(_alertChannel.id, _alertChannel.name, channelDescription: _alertChannel.description),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  bool _isSunday() => DateTime.now().weekday == DateTime.sunday;

  Future<Dio> _client() async {
    if (_dio != null) return _dio!;

    final dir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(ignoreExpires: true, storage: FileStorage('${dir.path}/.cookies/'));

    final dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      // Sanctum only treats a request as session/cookie-based with a matching
      // Origin/Referer header present — see api_client.dart for the full note.
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': kApiBaseUrl,
        'Origin': kApiBaseUrl,
      },
      validateStatus: (status) => status != null && status < 500,
    ));
    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final cookies = await cookieJar.loadForRequest(Uri.parse(kApiBaseUrl));
      for (final cookie in cookies) {
        if (cookie.name == 'XSRF-TOKEN') {
          options.headers['X-XSRF-TOKEN'] = Uri.decodeComponent(cookie.value);
          break;
        }
      }
      handler.next(options);
    }));

    _dio = dio;
    return dio;
  }

  Future<void> _pingOnce() async {
    final onWorkingDay = !_isSunday();

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (onWorkingDay && !_wasLocationDisabled) {
          _wasLocationDisabled = true;
          await _showAlert(
            9001,
            'Location is turned off',
            "Please turn your device location back on — your ADLG has been notified.",
          );
        }
        if (onWorkingDay) {
          final dio = await _client();
          await dio.post('/api/sec/attendance/location-disabled');
        }
        FlutterForegroundTask.updateService(
          notificationTitle: 'Location tracking paused',
          notificationText: 'Device location is turned off',
        );
        return;
      }
      _wasLocationDisabled = false;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final dio = await _client();
      final response = await dio.post('/api/sec/attendance/live-location', data: {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
      });

      final data = response.data;
      final insideGeofence = data is Map ? (data['inside_geofence'] as bool? ?? true) : true;

      if (onWorkingDay && !insideGeofence && !_wasOutsideGeofence) {
        _wasOutsideGeofence = true;
        await _showAlert(
          9002,
          "You're outside your Union Council",
          'Your current location is outside your assigned area — your ADLG has been notified.',
        );
      } else if (insideGeofence) {
        _wasOutsideGeofence = false;
      }

      FlutterForegroundTask.updateService(
        notificationTitle: 'Location tracking active',
        notificationText: 'Last update: ${formatDateTime12h(DateTime.now())}',
      );
    } catch (_) {
      // Best-effort — a missed ping (no signal, momentary network drop) just
      // waits for the next repeat interval rather than surfacing an error.
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _pingOnce();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _pingOnce();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}
}

/// Main-isolate facade — call [start] once the secretary is signed in and has
/// granted foreground + background location permission; [stop] on logout.
class LocationTrackingService {
  LocationTrackingService._();

  static final LocationTrackingService instance = LocationTrackingService._();

  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'attendance_location_tracking',
        channelName: 'Attendance Location Tracking',
        channelDescription: 'Keeps your location updated for your ADLG during working hours.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> ensureNotificationPermission() async {
    final status = await FlutterForegroundTask.checkNotificationPermission();
    if (status == NotificationPermission.granted) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  /// Foreground permission first (required before Android will even offer
  /// "Allow all the time" for background), then start the tracking service.
  /// Call right after login for a secretary — the app must keep reporting
  /// location whether or not the Attendance screen is ever opened.
  Future<void> ensureStartedForSecretary() async {
    try {
      await LocationService.instance.getCurrentPosition();
      if (!await LocationService.instance.hasBackgroundPermission()) {
        await LocationService.instance.requestBackgroundPermission();
      }
      await start();
    } catch (_) {
      // Silent — attendance itself doesn't depend on background tracking; a
      // secretary who denies it can still mark attendance and log movements.
    }
  }

  Future<void> start() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _ensureInitialized();
    await ensureNotificationPermission();

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 501,
      notificationTitle: 'Location tracking active',
      notificationText: "PA TO AD'sLG is sharing your location with your ADLG",
      callback: startLocationTrackingCallback,
    );
  }

  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
