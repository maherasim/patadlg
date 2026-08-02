/// An inquiry request an ADLG (or DDLG, filing on their own behalf) submits
/// for the Super Admin to draft a formal report on — mirrors InquiryResource
/// on the backend exactly.
class Inquiry {
  Inquiry({
    required this.id,
    required this.ref,
    required this.subject,
    this.remarks,
    required this.status,
    this.fileUrl,
    this.reportFileUrl,
    this.reportRemarks,
    this.adlg,
    this.unionCouncil,
    this.submittedAt,
    this.draftedAt,
  });

  factory Inquiry.fromJson(Map<String, dynamic> json) => Inquiry(
        id: json['id'] as int,
        ref: json['ref'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        remarks: json['remarks'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        fileUrl: json['file_url'] as String?,
        reportFileUrl: json['report_file_url'] as String?,
        reportRemarks: json['report_remarks'] as String?,
        adlg: json['adlg'] as String?,
        unionCouncil: json['union_council'] as String?,
        submittedAt: json['submitted_at'] as String?,
        draftedAt: json['drafted_at'] as String?,
      );

  final int id;
  final String ref;
  final String subject;
  final String? remarks;
  final String status;
  final String? fileUrl;
  final String? reportFileUrl;
  final String? reportRemarks;
  final String? adlg;
  final String? unionCouncil;
  final String? submittedAt;
  final String? draftedAt;

  bool get drafted => status == 'DRAFTED';
}
