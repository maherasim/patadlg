import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';

/// Runs when a push arrives while the app is fully backgrounded/terminated —
/// must be a top-level function, registered before runApp(). Android delivers
/// "data-only" pushes here; notification-style pushes are shown by the OS
/// automatically without this handler even firing.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nothing to do yet — the OS already shows the notification tray entry for
  // a standard FCM "notification" payload. Data-only background processing
  // (e.g. silently refreshing local state) can be added here later.
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channel = AndroidNotificationChannel(
    'default_channel',
    'General Notifications',
    description: 'Attendance reminders and case updates',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Safe to call even before a Firebase project/config exists on this
  /// platform — every step is guarded so a missing google-services.json or
  /// GoogleService-Info.plist just skips push setup instead of crashing boot.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[NotificationService] Firebase not configured for this platform yet: $e');
      return;
    }

    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    // Foreground pushes don't show a system tray notification on their own —
    // this is what makes them actually visible while the app is open.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name, channelDescription: _channel.description),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });

    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
  }

  /// Call once after login — sends the device's FCM token to the backend so
  /// scheduled reminders / case-update pushes can actually reach this device.
  Future<void> registerToken() async {
    if (!_initialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      debugPrint('[NotificationService] Could not fetch FCM token: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiClient.instance.dio.post('/api/device-tokens', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (e) {
      debugPrint('[NotificationService] Could not register device token: $e');
    }
  }

  /// Call on logout so a shared/reinstalled device stops receiving this
  /// user's pushes.
  Future<void> unregisterToken() async {
    if (!_initialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiClient.instance.dio.delete('/api/device-tokens', data: {'token': token});
      }
    } catch (_) {
      // Best-effort.
    }
  }
}
