import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/dv_case.dart';
import 'api_client.dart';

class CaseActionResult<T> {
  CaseActionResult.success(this.data) : errorMessage = null;
  CaseActionResult.failure(this.errorMessage) : data = null;

  final T? data;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

/// One photo/file selected for a party (divorcer/respondent) or a Khula
/// court-decree upload — carries the file plus whether it's an image, since
/// Khula documents can be images or PDFs.
class CaseFileInput {
  CaseFileInput(this.file);

  final File file;
}

class CaseService {
  CaseService._();

  static final CaseService instance = CaseService._();

  Dio get _dio => ApiClient.instance.dio;

  String _errorFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
      final firstError = firstKey != null ? errors[firstKey] : null;
      if (firstError is List && firstError.isNotEmpty) return firstError.first.toString();
    }
    if (data is Map && data['message'] != null) return data['message'].toString();
    return fallback;
  }

  // ---------------------------------------------------------------- Reading

  Future<List<DvCase>> indexForSecretary({String? status}) async {
    final response = await _dio.get('/api/sec/cases', queryParameters: {if (status != null) 'status': status});
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DvCase.fromJson).toList();
  }

  Future<DvCase> showForSecretary(int caseId) async {
    final response = await _dio.get('/api/sec/cases/$caseId');
    return DvCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<DvCase>> indexForAdlg({String? status}) async {
    final response = await _dio.get('/api/adlg/cases', queryParameters: {if (status != null) 'status': status});
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DvCase.fromJson).toList();
  }

  Future<DvCase> showForAdlg(int caseId) async {
    final response = await _dio.get('/api/adlg/cases/$caseId');
    return DvCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<DvCase>> indexForDdlg({String? status}) async {
    final response = await _dio.get('/api/ddlg/cases', queryParameters: {if (status != null) 'status': status});
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DvCase.fromJson).toList();
  }

  Future<DvCase> showForDdlg(int caseId) async {
    final response = await _dio.get('/api/ddlg/cases/$caseId');
    return DvCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<DvCase> show({required String role, required int caseId}) {
    if (role == 'adlg') return showForAdlg(caseId);
    if (role == 'ddlg') return showForDdlg(caseId);
    return showForSecretary(caseId);
  }

  // ------------------------------------------------------- Secretary: submit

  /// Submits a new Divorce/Khula case. [attachment] is the single "Divorce
  /// Deed" file (divorce only); [khulaDocuments] is Khula's multi-file
  /// "Court Decree" (images or PDFs); [divorcerPhotos]/[respondentPhotos] are
  /// each party's optional photo gallery.
  Future<CaseActionResult<DvCase>> storeCase({
    required String caseNo,
    required String type,
    required String receiptDate,
    String? address,
    required String divorcerName,
    required String divorcerCnic,
    String? divorcerPhone,
    required String respondentName,
    required String respondentCnic,
    String? respondentPhone,
    String? marriageDate,
    String? nikahRegistrar,
    String? mahrAmount,
    String? childrenCount,
    String? remarks,
    File? attachment,
    List<File> khulaDocuments = const [],
    List<File> divorcerPhotos = const [],
    List<File> respondentPhotos = const [],
  }) async {
    try {
      final map = <String, dynamic>{
        'case_no': caseNo,
        'type': type,
        'receipt_date': receiptDate,
        'address': address ?? '',
        'divorcer_name': divorcerName,
        'divorcer_cnic': divorcerCnic,
        'divorcer_phone': divorcerPhone ?? '',
        'respondent_name': respondentName,
        'respondent_cnic': respondentCnic,
        'respondent_phone': respondentPhone ?? '',
        'marriage_date': marriageDate ?? '',
        'nikah_registrar': nikahRegistrar ?? '',
        'mahr_amount': mahrAmount ?? '',
        'children_count': childrenCount ?? '',
        'remarks': remarks ?? '',
      };

      if (attachment != null) {
        map['attachment'] = await MultipartFile.fromFile(attachment.path, filename: attachment.path.split('/').last);
      }
      if (khulaDocuments.isNotEmpty) {
        map['khula_documents[]'] = await Future.wait(
          khulaDocuments.map((f) => MultipartFile.fromFile(f.path, filename: f.path.split('/').last)),
        );
      }
      if (divorcerPhotos.isNotEmpty) {
        map['divorcer_photos[]'] = await Future.wait(
          divorcerPhotos.map((f) => MultipartFile.fromFile(f.path, filename: f.path.split('/').last)),
        );
      }
      if (respondentPhotos.isNotEmpty) {
        map['respondent_photos[]'] = await Future.wait(
          respondentPhotos.map((f) => MultipartFile.fromFile(f.path, filename: f.path.split('/').last)),
        );
      }

      final response = await _dio.post('/api/sec/cases', data: FormData.fromMap(map));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DvCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(
        DioException(requestOptions: response.requestOptions, response: response),
        'Could not submit case.',
      ));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not submit case. Check your connection.'));
    }
  }

  // ------------------------------------------------- Secretary: arbitration

  Future<CaseActionResult<DvCase>> constituteArbitration({
    required int caseId,
    required String husbandRepName,
    required String husbandRepCnic,
    String? husbandRepPhone,
    String? husbandRepDesignation,
    required String wifeRepName,
    required String wifeRepCnic,
    String? wifeRepPhone,
    String? wifeRepDesignation,
  }) async {
    try {
      final response = await _dio.post('/api/sec/cases/$caseId/constitute-arbitration', data: {
        'husband_rep_name': husbandRepName,
        'husband_rep_cnic': husbandRepCnic,
        if (husbandRepPhone != null && husbandRepPhone.isNotEmpty) 'husband_rep_phone': husbandRepPhone,
        if (husbandRepDesignation != null && husbandRepDesignation.isNotEmpty) 'husband_rep_designation': husbandRepDesignation,
        'wife_rep_name': wifeRepName,
        'wife_rep_cnic': wifeRepCnic,
        if (wifeRepPhone != null && wifeRepPhone.isNotEmpty) 'wife_rep_phone': wifeRepPhone,
        if (wifeRepDesignation != null && wifeRepDesignation.isNotEmpty) 'wife_rep_designation': wifeRepDesignation,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DvCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(
        DioException(requestOptions: response.requestOptions, response: response),
        'Could not constitute arbitration.',
      ));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not constitute arbitration. Check your connection.'));
    }
  }

  // ------------------------------------------------------------- ADLG: flow

  Future<CaseActionResult<DvCase>> markSeen(int caseId) async {
    try {
      final response = await _dio.post('/api/adlg/cases/$caseId/mark-seen');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DvCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(
        DioException(requestOptions: response.requestOptions, response: response),
        'Could not mark as seen.',
      ));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not mark as seen. Check your connection.'));
    }
  }

  Future<CaseActionResult<DvCase>> issueNotice({
    required int caseId,
    required String noticeNo,
    required String issueDate,
    required String hearingDate,
  }) async {
    try {
      final response = await _dio.post('/api/adlg/cases/$caseId/issue-notice', data: {
        'notice_no': noticeNo,
        'issue_date': issueDate,
        'hearing_date': hearingDate,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DvCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(
        DioException(requestOptions: response.requestOptions, response: response),
        'Could not issue notice.',
      ));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not issue notice. Check your connection.'));
    }
  }

  Future<CaseActionResult<DvCase>> passDecision({
    required int caseId,
    required String type,
    required String orderNo,
    String? remarks,
  }) async {
    try {
      final response = await _dio.post('/api/adlg/cases/$caseId/pass-decision', data: {
        'type': type,
        'order_no': orderNo,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DvCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(
        DioException(requestOptions: response.requestOptions, response: response),
        'Could not pass decision.',
      ));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not pass decision. Check your connection.'));
    }
  }

  // --------------------------------------------------------- Both: hearings

  /// Records a hearing/proceeding — shared by both roles (server dispatches
  /// authorization by role). A party marked present REQUIRES a photo of them
  /// (server enforces this too; the UI should pre-check before calling this).
  Future<CaseActionResult<DvCase>> addProceeding({
    required String role,
    required int caseId,
    required String date,
    String? venue,
    required bool petitionerPresent,
    required bool respondentPresent,
    required bool petitionerBiometric,
    required bool respondentBiometric,
    File? petitionerPhoto,
    File? respondentPhoto,
    String? petRepName,
    String? petRepCnic,
    String? resRepName,
    String? resRepCnic,
    String? petStatement,
    String? resStatement,
    String? reconciliation,
    required bool adjourned,
    String? adjournReason,
    String? nextHearingDate,
    required bool noticeIssued,
    String? noticeRef,
    String? noticeDate,
    String? noticeDetails,
    String? adlgObservation,
    String? adlgDirection,
  }) async {
    try {
      final map = <String, dynamic>{
        'date': date,
        if (venue != null && venue.isNotEmpty) 'venue': venue,
        'petitioner_present': petitionerPresent ? '1' : '0',
        'respondent_present': respondentPresent ? '1' : '0',
        'petitioner_biometric': petitionerBiometric ? '1' : '0',
        'respondent_biometric': respondentBiometric ? '1' : '0',
        if (petRepName != null && petRepName.isNotEmpty) 'pet_rep_name': petRepName,
        if (petRepCnic != null && petRepCnic.isNotEmpty) 'pet_rep_cnic': petRepCnic,
        if (resRepName != null && resRepName.isNotEmpty) 'res_rep_name': resRepName,
        if (resRepCnic != null && resRepCnic.isNotEmpty) 'res_rep_cnic': resRepCnic,
        if (petStatement != null && petStatement.isNotEmpty) 'pet_statement': petStatement,
        if (resStatement != null && resStatement.isNotEmpty) 'res_statement': resStatement,
        if (reconciliation != null && reconciliation.isNotEmpty) 'reconciliation': reconciliation,
        'adjourned': adjourned ? '1' : '0',
        if (adjourned && adjournReason != null) 'adjourn_reason': adjournReason,
        if (adjourned && nextHearingDate != null) 'next_hearing_date': nextHearingDate,
        'notice_issued': noticeIssued ? '1' : '0',
        if (noticeIssued && noticeRef != null) 'notice_ref': noticeRef,
        if (noticeIssued && noticeDate != null) 'notice_date': noticeDate,
        if (noticeIssued && noticeDetails != null && noticeDetails.isNotEmpty) 'notice_details': noticeDetails,
        if (adlgObservation != null && adlgObservation.isNotEmpty) 'adlg_observation': adlgObservation,
        if (adlgDirection != null && adlgDirection.isNotEmpty) 'adlg_direction': adlgDirection,
      };

      if (petitionerPhoto != null) {
        map['petitioner_photo'] = await MultipartFile.fromFile(petitionerPhoto.path, filename: 'petitioner.jpg');
      }
      if (respondentPhoto != null) {
        map['respondent_photo'] = await MultipartFile.fromFile(respondentPhoto.path, filename: 'respondent.jpg');
      }

      final response = await _dio.post('/api/$role/cases/$caseId/proceedings', data: FormData.fromMap(map));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DvCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(
        DioException(requestOptions: response.requestOptions, response: response),
        'Could not record hearing.',
      ));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not record hearing. Check your connection.'));
    }
  }

  // --------------------------------------------------------------- Export

  Future<File> _downloadPdf(String path, String fallbackFilename) async {
    final response = await _dio.get<List<int>>(path, options: Options(responseType: ResponseType.bytes));

    if (response.statusCode != 200 || response.data == null) {
      throw DioException(requestOptions: response.requestOptions, response: response);
    }

    final filename = _filenameFromContentDisposition(response.headers.value('content-disposition')) ?? fallbackFilename;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.data!);
    return file;
  }

  Future<File> downloadNotesheet({required String role, required int caseId}) {
    return _downloadPdf('/api/$role/cases/$caseId/notesheet', 'Notesheet.pdf');
  }

  Future<File> downloadFullCaseFile({required String role, required int caseId}) {
    return _downloadPdf('/api/$role/cases/$caseId/full-file', 'Case_File.pdf');
  }

  /// ADLG-only Excel export (case summary + detail + hearings), downloaded
  /// and saved locally, ready to hand to the share sheet.
  Future<File> exportCases({String? status}) async {
    final response = await _dio.get<List<int>>(
      '/api/adlg/cases-export',
      queryParameters: {if (status != null) 'status': status},
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw DioException(requestOptions: response.requestOptions, response: response);
    }

    final filename = _filenameFromContentDisposition(response.headers.value('content-disposition')) ?? 'Arbitration_Registry_Export.xlsx';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.data!);
    return file;
  }

  String? _filenameFromContentDisposition(String? header) {
    if (header == null) return null;
    final match = RegExp('filename="?([^";]+)"?').firstMatch(header);
    return match?.group(1);
  }
}
