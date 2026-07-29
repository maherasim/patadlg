/// Laravel serializes decimal-cast columns (lat/lng) as JSON strings to
/// preserve precision, not numbers — parse either shape defensively.
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    this.secretary,
    this.unionCouncil,
    this.attendanceDate,
    this.checkInTime,
    required this.status,
    required this.insideGeofence,
    required this.biometricVerified,
    this.lat,
    this.lng,
    this.distanceMeters,
    this.photoUrl,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int,
      secretary: json['secretary'] as String?,
      unionCouncil: json['union_council'] as String?,
      attendanceDate: json['attendance_date'] as String?,
      checkInTime: json['check_in_time'] as String?,
      status: json['status'] as String? ?? 'present',
      insideGeofence: json['inside_geofence'] as bool? ?? false,
      biometricVerified: json['biometric_verified'] as bool? ?? false,
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lng']),
      distanceMeters: json['distance_meters'] as int?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  final int id;
  final String? secretary;
  final String? unionCouncil;
  final String? attendanceDate;
  final String? checkInTime;
  final String status;
  final bool insideGeofence;
  final bool biometricVerified;
  final double? lat;
  final double? lng;
  final int? distanceMeters;
  final String? photoUrl;

  bool get isLate => status == 'late';
}

class MovementLog {
  MovementLog({
    required this.id,
    this.secretary,
    this.unionCouncil,
    required this.reason,
    this.details,
    this.distanceMeters,
    this.occurredAt,
  });

  factory MovementLog.fromJson(Map<String, dynamic> json) {
    return MovementLog(
      id: json['id'] as int,
      secretary: json['secretary'] as String?,
      unionCouncil: json['union_council'] as String?,
      reason: json['reason'] as String? ?? '',
      details: json['details'] as String?,
      distanceMeters: json['distance_meters'] as int?,
      occurredAt: json['occurred_at'] as String?,
    );
  }

  final int id;
  final String? secretary;
  final String? unionCouncil;
  final String reason;
  final String? details;
  final int? distanceMeters;
  final String? occurredAt;
}
