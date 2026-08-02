import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/attendance_record.dart';
import '../models/live_location.dart';
import 'api_client.dart';

class AttendanceActionResult<T> {
  AttendanceActionResult.success(this.data) : errorMessage = null;
  AttendanceActionResult.failure(this.errorMessage) : data = null;

  final T? data;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

class AttendanceMeta {
  AttendanceMeta({required this.total, required this.today, required this.unionCouncils, required this.filtered});

  factory AttendanceMeta.fromJson(Map<String, dynamic> json) => AttendanceMeta(
        total: json['total'] as int? ?? 0,
        today: json['today'] as int? ?? 0,
        unionCouncils: json['union_councils'] as int? ?? 0,
        filtered: json['filtered'] as int? ?? 0,
      );

  final int total;
  final int today;
  final int unionCouncils;
  final int filtered;
}

class LiveLocationPing {
  LiveLocationPing({required this.insideGeofence, this.distanceMeters, this.isNewViolation = false});

  factory LiveLocationPing.fromJson(Map<String, dynamic> json) => LiveLocationPing(
        insideGeofence: json['inside_geofence'] as bool? ?? true,
        distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
        isNewViolation: json['is_new_violation'] as bool? ?? false,
      );

  final bool insideGeofence;
  final double? distanceMeters;
  final bool isNewViolation;
}

class AttendanceService {
  AttendanceService._();

  static final AttendanceService instance = AttendanceService._();

  Dio get _dio => ApiClient.instance.dio;

  String _errorFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
      final firstError = firstKey != null ? errors[firstKey] : null;
      if (firstError is List && firstError.isNotEmpty) return firstError.first.toString();
    }
    if (data is Map && data['message'] != null) return data['message'].toString();
    return fallback;
  }

  /// Secretary mark-in — GPS + selfie are required; device_biometric_confirmed
  /// is the mobile app's local Face ID/fingerprint gate (see BiometricService),
  /// sent as a plain boolean rather than a WebAuthn credential.
  Future<AttendanceActionResult<AttendanceRecord>> markIn({
    required double lat,
    required double lng,
    required File photo,
    required bool deviceBiometricConfirmed,
  }) async {
    try {
      final formData = FormData.fromMap({
        'lat': lat,
        'lng': lng,
        // Laravel's `boolean` rule only accepts [true, false, 0, 1, '0', '1']
        // — multipart fields are always sent as strings, and Dart's
        // true/false.toString() ('true'/'false') isn't in that list, so this
        // must be sent as '1'/'0' or every submission fails validation.
        'device_biometric_confirmed': deviceBiometricConfirmed ? '1' : '0',
        'photo': await MultipartFile.fromFile(photo.path, filename: 'attendance.jpg'),
      });

      final response = await _dio.post('/api/sec/attendance/mark-in', data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = response.data['data'] as Map<String, dynamic>;
        return AttendanceActionResult.success(AttendanceRecord.fromJson(json));
      }

      return AttendanceActionResult.failure(_errorFrom(
        DioException(requestOptions: response.requestOptions, response: response),
        'Could not mark attendance.',
      ));
    } on DioException catch (e) {
      return AttendanceActionResult.failure(_errorFrom(e, 'Could not mark attendance. Check your connection.'));
    }
  }

  Future<List<AttendanceRecord>> myHistory() async {
    final response = await _dio.get('/api/sec/attendance');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(AttendanceRecord.fromJson).toList();
  }

  Future<AttendanceActionResult<MovementLog>> logMovement({
    required String reason,
    String? details,
    double? lat,
    double? lng,
  }) async {
    try {
      final response = await _dio.post('/api/sec/attendance/log-movement', data: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = response.data['data'] as Map<String, dynamic>;
        return AttendanceActionResult.success(MovementLog.fromJson(json));
      }

      return AttendanceActionResult.failure('Could not log movement.');
    } on DioException catch (e) {
      return AttendanceActionResult.failure(_errorFrom(e, 'Could not log movement. Check your connection.'));
    }
  }

  /// Periodic ping while the attendance screen is open / background tracking is
  /// active — feeds the ADLG's live-location list and reports back whether the
  /// secretary is currently inside their UC's geofence, so the caller can show
  /// a local "you're outside your UC" notification. Returns null on failure
  /// since this fires on a timer and shouldn't surface transient network blips.
  Future<LiveLocationPing?> pingLiveLocation({required double lat, required double lng, double? accuracy}) async {
    try {
      final response = await _dio.post('/api/sec/attendance/live-location', data: {
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
      });
      return LiveLocationPing.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Reported by the client the moment it detects device location services are
  /// switched off — the server has no other way to know since no ping arrives
  /// at all in that case. Best-effort like pingLiveLocation.
  Future<void> reportLocationDisabled() async {
    try {
      await _dio.post('/api/sec/attendance/location-disabled');
    } catch (_) {
      // Best-effort.
    }
  }

  /// Records that this secretary completed the app's "Register Fingerprint"
  /// screen — called once right after they pass a real device biometric
  /// check. Unlike the other best-effort calls in this file, this one is
  /// NOT swallowed: the enrollment screen needs to know if it actually
  /// succeeded before letting the secretary into the app.
  Future<bool> enrollBiometric() async {
    try {
      final response = await _dio.post('/api/sec/biometric-enrollment');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// ADLG's tehsil-wide attendance list, with optional union_council_id/from/to
  /// filters — returns both the records and the summary meta the web app shows
  /// as KPI tiles.
  Future<(List<AttendanceRecord>, AttendanceMeta)> indexForAdlg({
    int? unionCouncilId,
    String? from,
    String? to,
  }) async {
    final response = await _dio.get('/api/adlg/attendance', queryParameters: {
      if (unionCouncilId != null) 'union_council_id': unionCouncilId,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });

    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    final meta = AttendanceMeta.fromJson(response.data['meta'] as Map<String, dynamic>);
    return (list.map(AttendanceRecord.fromJson).toList(), meta);
  }

  Future<List<MovementLog>> movementIndexForAdlg() async {
    final response = await _dio.get('/api/adlg/movement-log');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(MovementLog.fromJson).toList();
  }

  /// Union Councils in the ADLG's own tehsil — just enough (id/uc_no/name)
  /// to populate the Attendance filter dropdown, not a full UC model.
  Future<List<Map<String, dynamic>>> unionCouncilsForAdlg() async {
    final response = await _dio.get('/api/adlg/union-councils');
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Secretaries' most recent GPS pings across the ADLG's tehsil — feeds the
  /// Live Map tab.
  Future<List<LiveLocation>> liveLocations() async {
    final response = await _dio.get('/api/adlg/live-locations');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(LiveLocation.fromJson).toList();
  }

  /// Downloads the styled attendance Excel export (same workbook the web
  /// dashboard's "Export Excel" button produces) and saves it to the app's
  /// temp directory, ready to hand to the share sheet.
  Future<File> exportAttendance({int? unionCouncilId, String? from, String? to}) {
    return _downloadFile(
      '/api/adlg/attendance/analytics-export',
      queryParameters: {
        if (unionCouncilId != null) 'union_council_id': unionCouncilId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
      fallbackFilename: 'Attendance_Export.xlsx',
    );
  }

  /// Downloads the movement registry Excel export.
  Future<File> exportMovementLog() {
    return _downloadFile('/api/adlg/movement-log/export', fallbackFilename: 'Movement_Registry.xlsx');
  }

  /// DDLG's district-wide attendance list — same shape as [indexForAdlg] but
  /// spans every secretary under every tehsil in the district. DDLG has no
  /// live-locations route (view-only, no Live Map tab on the web app either).
  Future<(List<AttendanceRecord>, AttendanceMeta)> indexForDdlg({
    int? unionCouncilId,
    String? from,
    String? to,
  }) async {
    final response = await _dio.get('/api/ddlg/attendance', queryParameters: {
      if (unionCouncilId != null) 'union_council_id': unionCouncilId,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });

    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    final meta = AttendanceMeta.fromJson(response.data['meta'] as Map<String, dynamic>);
    return (list.map(AttendanceRecord.fromJson).toList(), meta);
  }

  Future<List<MovementLog>> movementIndexForDdlg() async {
    final response = await _dio.get('/api/ddlg/movement-log');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(MovementLog.fromJson).toList();
  }

  Future<File> exportAttendanceDdlg({int? unionCouncilId, String? from, String? to}) {
    return _downloadFile(
      '/api/ddlg/attendance/analytics-export',
      queryParameters: {
        if (unionCouncilId != null) 'union_council_id': unionCouncilId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
      fallbackFilename: 'Attendance_Export.xlsx',
    );
  }

  Future<File> exportMovementLogDdlg() {
    return _downloadFile('/api/ddlg/movement-log/export', fallbackFilename: 'Movement_Registry.xlsx');
  }

  Future<File> _downloadFile(
    String path, {
    Map<String, dynamic>? queryParameters,
    required String fallbackFilename,
  }) async {
    final response = await _dio.get<List<int>>(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw DioException(requestOptions: response.requestOptions, response: response);
    }

    final filename = _filenameFromContentDisposition(response.headers.value('content-disposition')) ?? fallbackFilename;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.data!);
    return file;
  }

  String? _filenameFromContentDisposition(String? header) {
    if (header == null) return null;
    final match = RegExp('filename="?([^";]+)"?').firstMatch(header);
    return match?.group(1);
  }
}
