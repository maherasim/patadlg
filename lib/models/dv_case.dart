/// Status machine: SUBMITTED -> SEEN -> NOTICE_ISSUED -> ARB_CONSTITUTED ->
/// IN_PROCEEDINGS -> one of DISPOSED_RECONCILED / DISPOSED_EFFECTIVE / FILED_NON_RESPONSE.
const List<String> kActiveCaseStatuses = ['SUBMITTED', 'SEEN', 'NOTICE_ISSUED', 'ARB_CONSTITUTED', 'IN_PROCEEDINGS'];

const List<String> kDisposedCaseStatuses = ['DISPOSED_RECONCILED', 'DISPOSED_EFFECTIVE', 'FILED_NON_RESPONSE'];

const Map<String, String> kCaseStatusLabels = {
  'SUBMITTED': 'Submitted to ADLG',
  'SEEN': 'Seen by ADLG',
  'NOTICE_ISSUED': 'Notice Issued',
  'ARB_CONSTITUTED': 'Arbitration Constituted',
  'IN_PROCEEDINGS': 'In Proceedings',
  'DISPOSED_RECONCILED': 'Disposed — Reconciled',
  'DISPOSED_EFFECTIVE': 'Disposed — Effective',
  'FILED_NON_RESPONSE': 'Filed — Non-Response',
};

class CaseNotice {
  CaseNotice({required this.noticeNo, required this.issueDate, this.hearingDate});

  factory CaseNotice.fromJson(Map<String, dynamic> json) => CaseNotice(
        noticeNo: json['notice_no'] as String? ?? '',
        issueDate: json['issue_date'] as String? ?? '',
        hearingDate: json['hearing_date'] as String?,
      );

  final String noticeNo;
  final String issueDate;
  final String? hearingDate;
}

class CaseArbitration {
  CaseArbitration({
    required this.husbandRepName,
    this.husbandRepDesignation,
    required this.wifeRepName,
    this.wifeRepDesignation,
    this.constitutedAt,
  });

  factory CaseArbitration.fromJson(Map<String, dynamic> json) => CaseArbitration(
        husbandRepName: json['husband_rep_name'] as String? ?? '',
        husbandRepDesignation: json['husband_rep_designation'] as String?,
        wifeRepName: json['wife_rep_name'] as String? ?? '',
        wifeRepDesignation: json['wife_rep_designation'] as String?,
        constitutedAt: json['constituted_at'] as String?,
      );

  final String husbandRepName;
  final String? husbandRepDesignation;
  final String wifeRepName;
  final String? wifeRepDesignation;
  final String? constitutedAt;
}

class CaseDecision {
  CaseDecision({required this.type, this.orderNo, required this.decidedAt, this.remarks});

  factory CaseDecision.fromJson(Map<String, dynamic> json) => CaseDecision(
        type: json['type'] as String? ?? '',
        orderNo: json['order_no'] as String?,
        decidedAt: json['decided_at'] as String? ?? '',
        remarks: json['remarks'] as String?,
      );

  final String type;
  final String? orderNo;
  final String decidedAt;
  final String? remarks;
}

class CaseTimelineEvent {
  CaseTimelineEvent({required this.stage, required this.eventDate, this.note, this.actor});

  factory CaseTimelineEvent.fromJson(Map<String, dynamic> json) => CaseTimelineEvent(
        stage: json['stage'] as String? ?? '',
        eventDate: json['event_date'] as String? ?? '',
        note: json['note'] as String?,
        actor: json['actor'] as String?,
      );

  final String stage;
  final String eventDate;
  final String? note;
  final String? actor;
}

class CaseProceeding {
  CaseProceeding({
    required this.id,
    required this.procNo,
    required this.date,
    this.venue,
    this.chairmanName,
    required this.petitionerPresent,
    required this.respondentPresent,
    required this.petitionerBiometric,
    required this.respondentBiometric,
    this.petitionerPhotoUrl,
    this.respondentPhotoUrl,
    this.petRepName,
    this.resRepName,
    this.petStatement,
    this.resStatement,
    this.reconciliation,
    this.adlgObservation,
    this.adlgDirection,
    required this.adjourned,
    this.adjournReason,
    this.nextHearingDate,
    required this.noticeIssued,
    this.noticeRef,
    this.noticeDate,
    this.noticeDetails,
    this.recordedBy,
    this.recordedAt,
  });

  factory CaseProceeding.fromJson(Map<String, dynamic> json) => CaseProceeding(
        id: json['id'] as int,
        procNo: json['proc_no'] as String? ?? '',
        date: json['date'] as String? ?? '',
        venue: json['venue'] as String?,
        chairmanName: json['chairman_name'] as String?,
        petitionerPresent: json['petitioner_present'] as bool? ?? false,
        respondentPresent: json['respondent_present'] as bool? ?? false,
        petitionerBiometric: json['petitioner_biometric'] as bool? ?? false,
        respondentBiometric: json['respondent_biometric'] as bool? ?? false,
        petitionerPhotoUrl: json['petitioner_photo_url'] as String?,
        respondentPhotoUrl: json['respondent_photo_url'] as String?,
        petRepName: json['pet_rep_name'] as String?,
        resRepName: json['res_rep_name'] as String?,
        petStatement: json['pet_statement'] as String?,
        resStatement: json['res_statement'] as String?,
        reconciliation: json['reconciliation'] as String?,
        adlgObservation: json['adlg_observation'] as String?,
        adlgDirection: json['adlg_direction'] as String?,
        adjourned: json['adjourned'] as bool? ?? false,
        adjournReason: json['adjourn_reason'] as String?,
        nextHearingDate: json['next_hearing_date'] as String?,
        noticeIssued: json['notice_issued'] as bool? ?? false,
        noticeRef: json['notice_ref'] as String?,
        noticeDate: json['notice_date'] as String?,
        noticeDetails: json['notice_details'] as String?,
        recordedBy: json['recorded_by'] as String?,
        recordedAt: json['recorded_at'] as String?,
      );

  final int id;
  final String procNo;
  final String date;
  final String? venue;
  final String? chairmanName;
  final bool petitionerPresent;
  final bool respondentPresent;
  final bool petitionerBiometric;
  final bool respondentBiometric;
  final String? petitionerPhotoUrl;
  final String? respondentPhotoUrl;
  final String? petRepName;
  final String? resRepName;
  final String? petStatement;
  final String? resStatement;
  final String? reconciliation;
  final String? adlgObservation;
  final String? adlgDirection;
  final bool adjourned;
  final String? adjournReason;
  final String? nextHearingDate;
  final bool noticeIssued;
  final String? noticeRef;
  final String? noticeDate;
  final String? noticeDetails;
  final String? recordedBy;
  final String? recordedAt;
}

class DvCase {
  DvCase({
    required this.id,
    required this.caseNo,
    required this.type,
    required this.status,
    required this.statusLabel,
    this.unionCouncil,
    this.unionCouncilId,
    this.secretary,
    this.adlg,
    required this.divorcerName,
    required this.divorcerCnic,
    this.divorcerPhone,
    required this.respondentName,
    required this.respondentCnic,
    this.respondentPhone,
    this.marriageDate,
    this.nikahRegistrar,
    this.mahrAmount,
    this.childrenCount,
    this.address,
    required this.receiptDate,
    this.daysRemaining,
    required this.isUrgent,
    required this.attachmentOk,
    this.attachmentUrl,
    required this.divorcerPhotos,
    required this.respondentPhotos,
    required this.khulaDocuments,
    this.remarks,
    this.notice,
    this.arbitration,
    this.decision,
    required this.timeline,
    required this.proceedings,
  });

  factory DvCase.fromJson(Map<String, dynamic> json) => DvCase(
        id: json['id'] as int,
        caseNo: json['case_no'] as String? ?? '',
        type: json['type'] as String? ?? 'divorce',
        status: json['status'] as String? ?? 'SUBMITTED',
        statusLabel: json['status_label'] as String? ?? kCaseStatusLabels[json['status']] ?? '',
        unionCouncil: json['union_council'] as String?,
        unionCouncilId: json['union_council_id'] as int?,
        secretary: json['secretary'] as String?,
        adlg: json['adlg'] as String?,
        divorcerName: json['divorcer_name'] as String? ?? '',
        divorcerCnic: json['divorcer_cnic'] as String? ?? '',
        divorcerPhone: json['divorcer_phone'] as String?,
        respondentName: json['respondent_name'] as String? ?? '',
        respondentCnic: json['respondent_cnic'] as String? ?? '',
        respondentPhone: json['respondent_phone'] as String?,
        marriageDate: json['marriage_date'] as String?,
        nikahRegistrar: json['nikah_registrar'] as String?,
        mahrAmount: json['mahr_amount'] as String?,
        childrenCount: json['children_count'] as String?,
        address: json['address'] as String?,
        receiptDate: json['receipt_date'] as String? ?? '',
        daysRemaining: (json['days_remaining'] as num?)?.toInt(),
        isUrgent: json['is_urgent'] as bool? ?? false,
        attachmentOk: json['attachment_ok'] as bool? ?? false,
        attachmentUrl: json['attachment_url'] as String?,
        divorcerPhotos: ((json['divorcer_photos'] as List?) ?? []).cast<String>(),
        respondentPhotos: ((json['respondent_photos'] as List?) ?? []).cast<String>(),
        khulaDocuments: ((json['khula_documents'] as List?) ?? []).cast<String>(),
        remarks: json['remarks'] as String?,
        notice: json['notice'] != null ? CaseNotice.fromJson(json['notice'] as Map<String, dynamic>) : null,
        arbitration: json['arbitration'] != null ? CaseArbitration.fromJson(json['arbitration'] as Map<String, dynamic>) : null,
        decision: json['decision'] != null ? CaseDecision.fromJson(json['decision'] as Map<String, dynamic>) : null,
        timeline: ((json['timeline'] as List?) ?? []).cast<Map<String, dynamic>>().map(CaseTimelineEvent.fromJson).toList(),
        proceedings: ((json['proceedings'] as List?) ?? []).cast<Map<String, dynamic>>().map(CaseProceeding.fromJson).toList(),
      );

  final int id;
  final String caseNo;
  final String type; // 'divorce' | 'khula'
  final String status;
  final String statusLabel;
  final String? unionCouncil;
  final int? unionCouncilId;
  final String? secretary;
  final String? adlg;
  final String divorcerName;
  final String divorcerCnic;
  final String? divorcerPhone;
  final String respondentName;
  final String respondentCnic;
  final String? respondentPhone;
  final String? marriageDate;
  final String? nikahRegistrar;
  final String? mahrAmount;
  final String? childrenCount;
  final String? address;
  final String receiptDate;
  final int? daysRemaining;
  final bool isUrgent;
  final bool attachmentOk;
  final String? attachmentUrl;
  final List<String> divorcerPhotos;
  final List<String> respondentPhotos;
  final List<String> khulaDocuments;
  final String? remarks;
  final CaseNotice? notice;
  final CaseArbitration? arbitration;
  final CaseDecision? decision;
  final List<CaseTimelineEvent> timeline;
  final List<CaseProceeding> proceedings;

  bool get isKhula => type == 'khula';
  bool get isActive => kActiveCaseStatuses.contains(status);
  bool get isDisposed => kDisposedCaseStatuses.contains(status);
  bool get canRecordHearing => ['NOTICE_ISSUED', 'ARB_CONSTITUTED', 'IN_PROCEEDINGS'].contains(status);

  /// Divorcer label flips by case type, matching the web app exactly.
  String get divorcerLabel => isKhula ? 'Divorcer (Wife)' : 'Divorcer (Husband)';
  String get respondentLabel => isKhula ? 'Respondent (Husband)' : 'Respondent (Wife)';
}
