/// A field definition for a form-mode Performa (dynamic in-app form built by
/// the ADLG) — type drives which keyboard/input the secretary sees.
class PerformaField {
  PerformaField({required this.id, required this.label, required this.type});

  factory PerformaField.fromJson(Map<String, dynamic> json) => PerformaField(
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
        type: json['type'] as String? ?? 'text', // 'text' | 'number' | 'date'
      );

  final int id;
  final String label;
  final String type;
}

class PerformaResponseValue {
  PerformaResponseValue({required this.fieldId, required this.label, required this.value});

  factory PerformaResponseValue.fromJson(Map<String, dynamic> json) => PerformaResponseValue(
        fieldId: json['field_id'] as int? ?? 0,
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );

  final int fieldId;
  final String label;
  final String value;
}

/// One secretary's submission for a Performa — 'form' type carries [values],
/// 'excel' type carries [fileUrl]. `secretary`/`unionCouncil` come back null
/// on the direct submit response (the backend doesn't eager-load those there)
/// but populated when read back via a list, so both are nullable.
class PerformaResponse {
  PerformaResponse({
    required this.id,
    required this.performaId,
    required this.type,
    this.secretary,
    this.unionCouncil,
    this.fileUrl,
    required this.values,
    required this.responseDate,
  });

  factory PerformaResponse.fromJson(Map<String, dynamic> json) => PerformaResponse(
        id: json['id'] as int,
        performaId: json['performa_id'] as int? ?? 0,
        type: json['type'] as String? ?? 'form',
        secretary: json['secretary'] as String?,
        unionCouncil: json['union_council'] as String?,
        fileUrl: json['file_url'] as String?,
        values: ((json['values'] as List?) ?? []).cast<Map<String, dynamic>>().map(PerformaResponseValue.fromJson).toList(),
        responseDate: json['response_date'] as String? ?? '',
      );

  final int id;
  final int performaId;
  final String type; // 'form' | 'excel'
  final String? secretary;
  final String? unionCouncil;
  final String? fileUrl;
  final List<PerformaResponseValue> values;
  final String responseDate;
}

/// A published Performa template — always live the moment it's created
/// (there's no draft/close state on the web app this mirrors), broadcast to
/// every secretary in the ADLG's tehsil.
class Performa {
  Performa({
    required this.id,
    required this.title,
    this.description,
    required this.mode,
    required this.reportType,
    this.deadline,
    required this.hasTemplate,
    required this.fields,
    this.createdAt,
    this.responsesCount,
    this.myResponse,
    this.needsToday,
  });

  factory Performa.fromJson(Map<String, dynamic> json) => Performa(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        mode: json['mode'] as String? ?? 'form', // 'form' | 'excel'
        reportType: json['report_type'] as String? ?? 'onetime', // 'onetime' | 'daily'
        deadline: json['deadline'] as String?,
        hasTemplate: json['has_template'] as bool? ?? false,
        fields: ((json['fields'] as List?) ?? []).cast<Map<String, dynamic>>().map(PerformaField.fromJson).toList(),
        createdAt: json['created_at'] as String?,
        responsesCount: (json['responses_count'] as num?)?.toInt(),
        myResponse: json['my_response'] != null ? PerformaResponse.fromJson(json['my_response'] as Map<String, dynamic>) : null,
        needsToday: json['needs_today'] as bool?,
      );

  final int id;
  final String title;
  final String? description;
  final String mode;
  final String reportType;
  final String? deadline;
  final bool hasTemplate;
  final List<PerformaField> fields;
  final String? createdAt;
  final int? responsesCount;
  final PerformaResponse? myResponse;
  final bool? needsToday;

  bool get isExcelMode => mode == 'excel';
  bool get isDaily => reportType == 'daily';

  /// Secretary-side "is this settled" check — daily performas reset every
  /// calendar day (`needsToday`), one-time performas are done forever once a
  /// response exists.
  bool get isDoneForSecretary => isDaily ? !(needsToday ?? true) : myResponse != null;
}
