/// Status machine: FORWARDED -> (ADLG) APPROVED|REJECTED|RETURNED, where
/// APPROVED on a '1-7' or 'ABROAD' case becomes PENDING_DDLG_APPROVAL instead
/// (DDLG committee then resolves it), while '7+' (court decree) is decided
/// directly by ADLG — the DDLG-skip rule is the OPPOSITE of LBR's (there it's
/// '7+' that's ADLG-final; here '7+' is still ADLG-final but the other two
/// categories both need the DDLG committee). APPROVED -> (Secretary
/// registers certificate) REGISTERED. RETURNED -> (Secretary resubmits) back
/// to FORWARDED.
const Map<String, String> kLdrStatusLabels = {
  'FORWARDED': 'Forwarded to ADLG',
  'PENDING_DDLG_APPROVAL': 'Pending DDLG Committee Approval',
  'APPROVED': 'Approved — Ready to Register',
  'REJECTED': 'Rejected',
  'RETURNED': 'Returned for Correction',
  'REGISTERED': 'Death Registered',
};

const Map<String, String> kLdrCategoryLabels = {
  '1-7': '1–7 Years (Domestic)',
  '7+': 'Over 7 Years (Court Decree)',
  'ABROAD': 'Pakistani Abroad (6+ Months)',
};

/// Fixed document slot keys, in display order. `categoryOnly` restricts a
/// slot to one category ('7+' court decree, or 'ABROAD' passport/visa);
/// null means visible for every category.
class LdrDocSlotDef {
  const LdrDocSlotDef({
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

const List<LdrDocSlotDef> kLdrDocSlots = [
  LdrDocSlotDef(key: 'affidavit', label: 'Affidavit (Stamp Paper Rs. 300, 2 Witnesses)', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LdrDocSlotDef(key: 'cnic_deceased', label: 'CNIC / Birth Certificate of Deceased', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LdrDocSlotDef(key: 'cnic_applicant', label: 'Applicant CNIC (copy)', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LdrDocSlotDef(key: 'death_slip', label: 'Hospital Death Slip (if applicable)', required: false, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LdrDocSlotDef(key: 'burial_slip', label: 'Burial Slip (if available)', required: false, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']),
  LdrDocSlotDef(key: 'court_decree', label: 'Court Decree (Copy)', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], categoryOnly: '7+'),
  LdrDocSlotDef(key: 'passport_copy', label: 'Passport Copy', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], categoryOnly: 'ABROAD'),
  LdrDocSlotDef(key: 'visa_copy', label: 'Visa Copy', required: true, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], categoryOnly: 'ABROAD'),
  LdrDocSlotDef(key: 'other_doc', label: 'Other Supporting Document', required: false, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], categoryOnly: 'ABROAD'),
];

const List<String> kLdrDelayReasons = [
  'Unawareness of registration law',
  'Home death, no documentation',
  'Financial hardship',
  'Remote / rural area, no UC access',
  'Original documents lost',
  'Family did not report in time',
  'Other',
];

class LdrDocument {
  LdrDocument({required this.docKey, required this.label, required this.fileUrl, this.uploadedAt});

  factory LdrDocument.fromJson(Map<String, dynamic> json) => LdrDocument(
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

class LdrTimelineEvent {
  LdrTimelineEvent({required this.stage, required this.eventDate, this.note, this.actor});

  factory LdrTimelineEvent.fromJson(Map<String, dynamic> json) => LdrTimelineEvent(
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

class LdrCertificate {
  LdrCertificate({required this.certificateNo, required this.certificateDate, this.certificateRemarks});

  factory LdrCertificate.fromJson(Map<String, dynamic> json) => LdrCertificate(
        certificateNo: json['certificate_no'] as String? ?? '',
        certificateDate: json['certificate_date'] as String? ?? '',
        certificateRemarks: json['certificate_remarks'] as String?,
      );

  final String certificateNo;
  final String certificateDate;
  final String? certificateRemarks;
}

class LdrCourtDecree {
  LdrCourtDecree({required this.decreeNo, required this.decreeDate, required this.courtName});

  factory LdrCourtDecree.fromJson(Map<String, dynamic> json) => LdrCourtDecree(
        decreeNo: json['decree_no'] as String? ?? '',
        decreeDate: json['decree_date'] as String? ?? '',
        courtName: json['court_name'] as String? ?? '',
      );

  final String decreeNo;
  final String decreeDate;
  final String courtName;
}

class LdrAbroad {
  LdrAbroad({required this.countryOfDeath, required this.passportNo});

  factory LdrAbroad.fromJson(Map<String, dynamic> json) => LdrAbroad(
        countryOfDeath: json['country_of_death'] as String? ?? '',
        passportNo: json['passport_no'] as String? ?? '',
      );

  final String countryOfDeath;
  final String passportNo;
}

class DeathCase {
  DeathCase({
    required this.id,
    required this.deathId,
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
    required this.dateOfDeath,
    this.delayYears,
    required this.delayReason,
    required this.deceasedName,
    required this.deceasedGender,
    this.deceasedCnic,
    this.causeOfDeath,
    this.placeOfDeath,
    this.burialPlace,
    required this.applicantName,
    required this.applicantCnic,
    this.applicantRelation,
    this.applicantAddress,
    this.applicantPhone,
    this.courtDecree,
    this.abroad,
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

  factory DeathCase.fromJson(Map<String, dynamic> json) {
    final deceased = json['deceased'] as Map<String, dynamic>? ?? {};
    final applicant = json['applicant'] as Map<String, dynamic>? ?? {};
    return DeathCase(
      id: json['id'] as int,
      deathId: json['death_id'] as String? ?? '',
      status: json['status'] as String? ?? 'FORWARDED',
      statusLabel: json['status_label'] as String? ?? kLdrStatusLabels[json['status']] ?? '',
      category: json['category'] as String? ?? '1-7',
      categoryLabel: json['category_label'] as String? ?? kLdrCategoryLabels[json['category']] ?? '',
      locked: json['locked'] as bool? ?? false,
      unionCouncil: json['union_council'] as String?,
      unionCouncilId: json['union_council_id'] as int?,
      tehsil: json['tehsil'] as String?,
      secretary: json['secretary'] as String?,
      adlg: json['adlg'] as String?,
      ddlg: json['ddlg'] as String?,
      dateOfDeath: json['date_of_death'] as String? ?? '',
      delayYears: (json['age_at_application'] as num?)?.toDouble(),
      delayReason: json['delay_reason'] as String? ?? '',
      deceasedName: (deceased['name'] as String?) ?? '',
      deceasedGender: (deceased['gender'] as String?) ?? 'Male',
      deceasedCnic: deceased['cnic'] as String?,
      causeOfDeath: deceased['cause_of_death'] as String?,
      placeOfDeath: deceased['place_of_death'] as String?,
      burialPlace: deceased['burial_place'] as String?,
      applicantName: (applicant['name'] as String?) ?? '',
      applicantCnic: (applicant['cnic'] as String?) ?? '',
      applicantRelation: applicant['relation'] as String?,
      applicantAddress: applicant['address'] as String?,
      applicantPhone: applicant['phone'] as String?,
      courtDecree: json['court_decree'] != null ? LdrCourtDecree.fromJson(json['court_decree'] as Map<String, dynamic>) : null,
      abroad: json['abroad'] != null ? LdrAbroad.fromJson(json['abroad'] as Map<String, dynamic>) : null,
      secretaryRemarks: json['secretary_remarks'] as String?,
      adlgObservations: json['adlg_observations'] as String?,
      adlgOrderNo: json['adlg_order_no'] as String?,
      ddlgObservations: json['ddlg_observations'] as String?,
      ddlgOrderNo: json['ddlg_order_no'] as String?,
      certificate: json['certificate'] != null ? LdrCertificate.fromJson(json['certificate'] as Map<String, dynamic>) : null,
      documents: ((json['documents'] as List?) ?? []).cast<Map<String, dynamic>>().map(LdrDocument.fromJson).toList(),
      timeline: ((json['timeline'] as List?) ?? []).cast<Map<String, dynamic>>().map(LdrTimelineEvent.fromJson).toList(),
      createdAt: json['created_at'] as String?,
    );
  }

  final int id;
  final String deathId;
  final String status;
  final String statusLabel;
  final String category; // '1-7' | '7+' | 'ABROAD'
  final String categoryLabel;
  final bool locked;
  final String? unionCouncil;
  final int? unionCouncilId;
  final String? tehsil;
  final String? secretary;
  final String? adlg;
  final String? ddlg;
  final String dateOfDeath;
  final double? delayYears;
  final String delayReason;
  final String deceasedName;
  final String deceasedGender;
  final String? deceasedCnic;
  final String? causeOfDeath;
  final String? placeOfDeath;
  final String? burialPlace;
  final String applicantName;
  final String applicantCnic;
  final String? applicantRelation;
  final String? applicantAddress;
  final String? applicantPhone;
  final LdrCourtDecree? courtDecree;
  final LdrAbroad? abroad;
  final String? secretaryRemarks;
  final String? adlgObservations;
  final String? adlgOrderNo;
  final String? ddlgObservations;
  final String? ddlgOrderNo;
  final LdrCertificate? certificate;
  final List<LdrDocument> documents;
  final List<LdrTimelineEvent> timeline;
  final String? createdAt;

  /// Only '7+' (court decree) is decided directly by ADLG — 1-7 and ABROAD
  /// both need the DDLG committee's final decision.
  bool get isFinalAtAdlg => category == '7+';
}
