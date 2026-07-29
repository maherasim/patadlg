/// A secretary's most recent GPS ping, as shown on the ADLG's Live Map tab.
class LiveLocation {
  LiveLocation({
    required this.secretaryId,
    required this.name,
    this.unionCouncilId,
    this.unionCouncil,
    required this.lat,
    required this.lng,
    this.accuracyMeters,
    this.lastSeenAt,
    required this.fresh,
  });

  factory LiveLocation.fromJson(Map<String, dynamic> json) => LiveLocation(
        secretaryId: json['secretary_id'] as int,
        name: json['name'] as String? ?? '—',
        unionCouncilId: json['union_council_id'] as int?,
        unionCouncil: json['union_council'] as String?,
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
        lastSeenAt: json['last_seen_at'] != null ? DateTime.tryParse(json['last_seen_at'] as String) : null,
        fresh: json['fresh'] as bool? ?? false,
      );

  final int secretaryId;
  final String name;
  final int? unionCouncilId;
  final String? unionCouncil;
  final double lat;
  final double lng;
  final double? accuracyMeters;
  final DateTime? lastSeenAt;
  final bool fresh;
}
