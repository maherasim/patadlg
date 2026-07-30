/// A secretary's additional (secondary) UC charge — covering more than one
/// Union Council beyond their primary assignment.
class UcCharge {
  UcCharge({required this.unionCouncilId, required this.unionCouncil, this.assignedAt});

  factory UcCharge.fromJson(Map<String, dynamic> json) => UcCharge(
        unionCouncilId: json['union_council_id'] as int? ?? 0,
        unionCouncil: json['union_council'] as String? ?? '',
        assignedAt: json['assigned_at'] as String?,
      );

  final int unionCouncilId;
  final String unionCouncil;
  final String? assignedAt;
}

class SecretaryProfileLite {
  SecretaryProfileLite({
    this.unionCouncilId,
    this.unionCouncil,
    this.fatherName,
    required this.geofenceSet,
    required this.deviceBiometricEnrolled,
    this.tehsil,
    this.district,
    required this.additionalCharges,
  });

  factory SecretaryProfileLite.fromJson(Map<String, dynamic> json) => SecretaryProfileLite(
        unionCouncilId: json['union_council_id'] as int?,
        unionCouncil: json['union_council'] as String?,
        fatherName: json['father_name'] as String?,
        geofenceSet: json['geofence_set'] as bool? ?? false,
        deviceBiometricEnrolled: json['device_biometric_enrolled'] as bool? ?? false,
        tehsil: json['tehsil'] as String?,
        district: json['district'] as String?,
        additionalCharges: ((json['additional_charges'] as List?) ?? []).cast<Map<String, dynamic>>().map(UcCharge.fromJson).toList(),
      );

  final int? unionCouncilId;
  final String? unionCouncil;
  final String? fatherName;
  final bool geofenceSet;
  final bool deviceBiometricEnrolled;
  final String? tehsil;
  final String? district;
  final List<UcCharge> additionalCharges;
}

class AdlgProfileLite {
  AdlgProfileLite({this.tehsilId, this.tehsil, this.grade});

  factory AdlgProfileLite.fromJson(Map<String, dynamic> json) => AdlgProfileLite(
        tehsilId: json['tehsil_id'] as int?,
        tehsil: json['tehsil'] as String?,
        grade: json['grade'] as String?,
      );

  final int? tehsilId;
  final String? tehsil;
  final String? grade;
}

/// A user as returned by the shared `UserResource` — used here for the
/// Secretary and ADLG directory/management screens (ADLG's own tehsil, or
/// DDLG's district-wide read-only view).
class DirectoryUser {
  DirectoryUser({
    required this.id,
    required this.role,
    required this.name,
    required this.username,
    this.email,
    this.phone,
    this.cnic,
    required this.active,
    this.secretaryProfile,
    this.adlgProfile,
  });

  factory DirectoryUser.fromJson(Map<String, dynamic> json) => DirectoryUser(
        id: json['id'] as int,
        role: json['role'] as String? ?? '',
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        cnic: json['cnic'] as String?,
        active: json['active'] as bool? ?? true,
        secretaryProfile: json['secretary_profile'] != null ? SecretaryProfileLite.fromJson(json['secretary_profile'] as Map<String, dynamic>) : null,
        adlgProfile: json['adlg_profile'] != null ? AdlgProfileLite.fromJson(json['adlg_profile'] as Map<String, dynamic>) : null,
      );

  final int id;
  final String role;
  final String name;
  final String username;
  final String? email;
  final String? phone;
  final String? cnic;
  final bool active;
  final SecretaryProfileLite? secretaryProfile;
  final AdlgProfileLite? adlgProfile;
}
