/// Status machine: FORWARDED -> (ADLG) APPROVED|REJECTED|RETURNED, where
/// APPROVED on a '7+' case becomes PENDING_DDLG_APPROVAL instead, which DDLG
/// then resolves to APPROVED|REJECTED|RETURNED. APPROVED -> (Secretary
/// registers certificate) REGISTERED. RETURNED -> (Secretary resubmits) back
/// to FORWARDED.
const Map<String, String> kLbrStatusLabels = {
  'FORWARDED': 'Forwarded to ADLG',
  'PENDING_DDLG_APPROVAL': 'Pending DDLG Final Approval',
  'APPROVED': 'Approved — Ready to Register',
  'REJECTED': 'Rejected',
  'RETURNED': 'Returned for Correction',
  'REGISTERED': 'Birth Registered',
};

const Map<String, String> kLbrCategoryLabels = {
  '1-7': '1–7 Years',
  '7+': 'Over 7 Years',
};

/// Fixed document slot keys, in display order. `categoryOnly` restricts a
/// slot to one category ('7+' for the delay-justification docs); null means
/// visible for both.
class LbrDocSlotDef {
  const LbrDocSlotDef({
    required this.key,
    required this.label,
    required this.required,
    required this.allowedExtensions,
    this.categoryOnly,
  });

  final String key;
  final String label;
  final bool required;
  final List<String> allowedExtensions;
  final String? categoryOnly;
}

const List<LbrDocSlotDef> kLbrDocSlots = [
  LbrDocSlotDef(key: 'cnic', label: 'Applicant CNIC (copy)', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LbrDocSlotDef(key: 'photo1', label: 'Child Photograph (1st)', required: true, allowedExtensions: ['jpg', 'jpeg', 'png']),
  LbrDocSlotDef(key: 'photo2', label: 'Child Photograph (2nd)', required: true, allowedExtensions: ['jpg', 'jpeg', 'png']),
  LbrDocSlotDef(key: 'forma', label: 'Form A (mandatory)', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LbrDocSlotDef(key: 'slip', label: 'Hospital Birth Slip', required: false, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LbrDocSlotDef(key: 'vacc', label: 'Vaccination Card', required: false, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LbrDocSlotDef(key: 'bform', label: 'Child B-Form / CNIC / Smart Card / Passport', required: false, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], categoryOnly: '7+'),
  LbrDocSlotDef(key: 'newspaper_notice', label: 'Newspaper Advertisement / Publication Notice', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], categoryOnly: '7+'),
  LbrDocSlotDef(key: 'stamp_paper', label: 'Stamp Paper (Affidavit)', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], categoryOnly: '7+'),
];

const List<String> kLbrDelayReasons = [
  'Unawareness of registration law',
  'Hospital / facility not registered',
  'Home delivery, no documentation',
  'Financial hardship',
  'Remote / rural area, no UC access',
  'Original documents lost',
  'Other',
];

class LbrDocument {
  LbrDocument({required this.docKey, required this.label, required this.fileUrl, this.uploadedAt});

  factory LbrDocument.fromJson(Map<String, dynamic> json) => LbrDocument(
        docKey: json['doc_key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        fileUrl: json['file_url'] as String? ?? '',
        uploadedAt: json['uploaded_at'] as String?,
      );

  final String docKey;
  final String label;
  final String fileUrl;
  final String? uploadedAt;
}

class LbrTimelineEvent {
  LbrTimelineEvent({required this.stage, required this.eventDate, this.note, this.actor});

  factory LbrTimelineEvent.fromJson(Map<String, dynamic> json) => LbrTimelineEvent(
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

class LbrCertificate {
  LbrCertificate({required this.certificateNo, required this.certificateDate, this.certificateRemarks});

  factory LbrCertificate.fromJson(Map<String, dynamic> json) => LbrCertificate(
        certificateNo: json['certificate_no'] as String? ?? '',
        certificateDate: json['certificate_date'] as String? ?? '',
        certificateRemarks: json['certificate_remarks'] as String?,
      );

  final String certificateNo;
  final String certificateDate;
  final String? certificateRemarks;
}

class LbrCase {
  LbrCase({
    required this.id,
    required this.lbrId,
    required this.status,
    required this.statusLabel,
    required this.category,
    required this.categoryLabel,
    required this.locked,
    this.unionCouncil,
    this.unionCouncilId,
    this.tehsil,
    this.secretary,
    this.adlg,
    this.ddlg,
    required this.dob,
    this.ageAtApplication,
    required this.delayReason,
    required this.childName,
    required this.childGender,
    this.childBirthPlace,
    this.childBirthType,
    this.childHospital,
    required this.applicantName,
    required this.applicantCnic,
    this.applicantRelation,
    this.applicantFatherName,
    this.applicantMotherName,
    this.applicantAddress,
    this.applicantPhone,
    this.secretaryRemarks,
    this.adlgObservations,
    this.adlgOrderNo,
    this.ddlgObservations,
    this.ddlgOrderNo,
    this.certificate,
    required this.documents,
    required this.timeline,
    this.createdAt,
  });

  factory LbrCase.fromJson(Map<String, dynamic> json) {
    final child = json['child'] as Map<String, dynamic>? ?? {};
    final applicant = json['applicant'] as Map<String, dynamic>? ?? {};
    return LbrCase(
      id: json['id'] as int,
      lbrId: json['lbr_id'] as String? ?? '',
      status: json['status'] as String? ?? 'FORWARDED',
      statusLabel: json['status_label'] as String? ?? kLbrStatusLabels[json['status']] ?? '',
      category: json['category'] as String? ?? '1-7',
      categoryLabel: json['category_label'] as String? ?? kLbrCategoryLabels[json['category']] ?? '',
      locked: json['locked'] as bool? ?? false,
      unionCouncil: json['union_council'] as String?,
      unionCouncilId: json['union_council_id'] as int?,
      tehsil: json['tehsil'] as String?,
      secretary: json['secretary'] as String?,
      adlg: json['adlg'] as String?,
      ddlg: json['ddlg'] as String?,
      dob: json['dob'] as String? ?? '',
      ageAtApplication: (json['age_at_application'] as num?)?.toDouble(),
      delayReason: json['delay_reason'] as String? ?? '',
      childName: (child['name'] as String?) ?? '',
      childGender: (child['gender'] as String?) ?? 'Male',
      childBirthPlace: child['birth_place'] as String?,
      childBirthType: child['birth_type'] as String?,
      childHospital: child['hospital'] as String?,
      applicantName: (applicant['name'] as String?) ?? '',
      applicantCnic: (applicant['cnic'] as String?) ?? '',
      applicantRelation: applicant['relation'] as String?,
      applicantFatherName: applicant['father_name'] as String?,
      applicantMotherName: applicant['mother_name'] as String?,
      applicantAddress: applicant['address'] as String?,
      applicantPhone: applicant['phone'] as String?,
      secretaryRemarks: json['secretary_remarks'] as String?,
      adlgObservations: json['adlg_observations'] as String?,
      adlgOrderNo: json['adlg_order_no'] as String?,
      ddlgObservations: json['ddlg_observations'] as String?,
      ddlgOrderNo: json['ddlg_order_no'] as String?,
      certificate: json['certificate'] != null ? LbrCertificate.fromJson(json['certificate'] as Map<String, dynamic>) : null,
      documents: ((json['documents'] as List?) ?? []).cast<Map<String, dynamic>>().map(LbrDocument.fromJson).toList(),
      timeline: ((json['timeline'] as List?) ?? []).cast<Map<String, dynamic>>().map(LbrTimelineEvent.fromJson).toList(),
      createdAt: json['created_at'] as String?,
    );
  }

  final int id;
  final String lbrId;
  final String status;
  final String statusLabel;
  final String category; // '1-7' | '7+'
  final String categoryLabel;
  final bool locked;
  final String? unionCouncil;
  final int? unionCouncilId;
  final String? tehsil;
  final String? secretary;
  final String? adlg;
  final String? ddlg;
  final String dob;
  final double? ageAtApplication;
  final String delayReason;
  final String childName;
  final String childGender;
  final String? childBirthPlace;
  final String? childBirthType;
  final String? childHospital;
  final String applicantName;
  final String applicantCnic;
  final String? applicantRelation;
  final String? applicantFatherName;
  final String? applicantMotherName;
  final String? applicantAddress;
  final String? applicantPhone;
  final String? secretaryRemarks;
  final String? adlgObservations;
  final String? adlgOrderNo;
  final String? ddlgObservations;
  final String? ddlgOrderNo;
  final LbrCertificate? certificate;
  final List<LbrDocument> documents;
  final List<LbrTimelineEvent> timeline;
  final String? createdAt;

  bool get isSevenPlus => category == '7+';
  bool get isFinalAtAdlg => category == '1-7';
}
