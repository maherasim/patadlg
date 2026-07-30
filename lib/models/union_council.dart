double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class UnionCouncil {
  UnionCouncil({
    required this.id,
    required this.tehsilId,
    this.ucNo,
    required this.name,
    this.code,
    this.address,
    this.lat,
    this.lng,
    required this.geofenceRadius,
    required this.active,
    this.secretary,
    this.secretaryId,
    this.tehsil,
    this.district,
  });

  factory UnionCouncil.fromJson(Map<String, dynamic> json) => UnionCouncil(
        id: json['id'] as int,
        tehsilId: json['tehsil_id'] as int? ?? 0,
        ucNo: json['uc_no'] as int?,
        name: json['name'] as String? ?? '',
        code: json['code'] as String?,
        address: json['address'] as String?,
        lat: _parseDouble(json['lat']),
        lng: _parseDouble(json['lng']),
        geofenceRadius: (json['geofence_radius'] as num?)?.toInt() ?? 150,
        active: json['active'] as bool? ?? true,
        secretary: json['secretary'] as String?,
        secretaryId: json['secretary_id'] as int?,
        tehsil: json['tehsil'] as String?,
        district: json['district'] as String?,
      );

  final int id;
  final int tehsilId;
  final int? ucNo;
  final String name;
  final String? code;
  final String? address;
  final double? lat;
  final double? lng;
  final int geofenceRadius;
  final bool active;
  final String? secretary;
  final int? secretaryId;
  final String? tehsil;
  final String? district;

  bool get isVacant => secretary == null;
  bool get hasGeofence => lat != null && lng != null;
}

class Tehsil {
  Tehsil({
    required this.id,
    required this.name,
    required this.districtId,
    this.district,
    this.division,
    required this.adlgActivated,
    required this.active,
    this.unionCouncilsCount,
  });

  factory Tehsil.fromJson(Map<String, dynamic> json) => Tehsil(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        districtId: json['district_id'] as int? ?? 0,
        district: json['district'] as String?,
        division: json['division'] as String?,
        adlgActivated: json['adlg_activated'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
        unionCouncilsCount: (json['union_councils_count'] as num?)?.toInt(),
      );

  final int id;
  final String name;
  final int districtId;
  final String? district;
  final String? division;
  final bool adlgActivated;
  final bool active;
  final int? unionCouncilsCount;
}
