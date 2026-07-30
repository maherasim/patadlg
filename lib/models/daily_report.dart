/// One entry in a DailyReport's custom_fields array — either an ADLG-defined
/// standing field answer (fieldDefinitionId != null) or the secretary's own
/// ad-hoc field (fieldDefinitionId == null). The web app doesn't visually
/// distinguish these two cases; this app does, since the API already carries
/// the distinction.
class ReportFieldEntry {
  ReportFieldEntry({required this.label, required this.value, this.fieldDefinitionId});

  factory ReportFieldEntry.fromJson(Map<String, dynamic> json) => ReportFieldEntry(
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
        fieldDefinitionId: json['field_definition_id'] as int?,
      );

  final String label;
  final String value;
  final int? fieldDefinitionId;

  bool get isAdlgRequired => fieldDefinitionId != null;
}

class DailyReport {
  DailyReport({
    required this.id,
    this.secretary,
    this.unionCouncil,
    this.tehsil,
    this.district,
    required this.reportDate,
    required this.remarks,
    required this.nikahCount,
    required this.birthCount,
    required this.deathCount,
    required this.complaintCount,
    required this.customFields,
    this.attachmentUrl,
    required this.reviewed,
    this.reviewedAt,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) => DailyReport(
        id: json['id'] as int,
        secretary: json['secretary'] as String?,
        unionCouncil: json['union_council'] as String?,
        tehsil: json['tehsil'] as String?,
        district: json['district'] as String?,
        reportDate: json['report_date'] as String? ?? '',
        remarks: json['remarks'] as String? ?? '',
        nikahCount: (json['nikah_count'] as num?)?.toInt() ?? 0,
        birthCount: (json['birth_count'] as num?)?.toInt() ?? 0,
        deathCount: (json['death_count'] as num?)?.toInt() ?? 0,
        complaintCount: (json['complaint_count'] as num?)?.toInt() ?? 0,
        customFields: ((json['custom_fields'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(ReportFieldEntry.fromJson)
            .toList(),
        attachmentUrl: json['attachment_url'] as String?,
        reviewed: json['reviewed'] as bool? ?? false,
        reviewedAt: json['reviewed_at'] as String?,
      );

  final int id;
  final String? secretary;
  final String? unionCouncil;
  final String? tehsil;
  final String? district;
  final String reportDate;
  final String remarks;
  final int nikahCount;
  final int birthCount;
  final int deathCount;
  final int complaintCount;
  final List<ReportFieldEntry> customFields;
  final String? attachmentUrl;
  final bool reviewed;
  final String? reviewedAt;
}

/// An ADLG-defined standing report field — plain text label + active toggle,
/// no type system (unlike the separate Performa-forms feature).
class ReportFieldDefinition {
  ReportFieldDefinition({required this.id, required this.label, required this.active, this.adlg});

  factory ReportFieldDefinition.fromJson(Map<String, dynamic> json) => ReportFieldDefinition(
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        adlg: json['adlg'] as String?,
      );

  final int id;
  final String label;
  final bool active;
  final String? adlg;
}
