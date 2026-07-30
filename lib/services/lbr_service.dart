import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/lbr_case.dart';
import 'api_client.dart';
import 'case_service.dart' show CaseActionResult;

/// Local Birth Registration — mirrors CaseService's shape/conventions
/// (multipart submits, CaseActionResult-style error unwrapping, PDF/Excel
/// downloads to a temp file for the share sheet).
class LbrService {
  LbrService._();

  static final LbrService instance = LbrService._();

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

  Future<List<LbrCase>> indexForSecretary() async {
    final response = await _dio.get('/api/sec/lbr-cases');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(LbrCase.fromJson).toList();
  }

  Future<LbrCase> showForSecretary(int id) async {
    final response = await _dio.get('/api/sec/lbr-cases/$id');
    return LbrCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<LbrCase>> indexForAdlg({String? status}) async {
    final response = await _dio.get('/api/adlg/lbr-cases', queryParameters: {if (status != null) 'status': status});
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(LbrCase.fromJson).toList();
  }

  Future<LbrCase> showForAdlg(int id) async {
    final response = await _dio.get('/api/adlg/lbr-cases/$id');
    return LbrCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<LbrCase>> indexForDdlg({String? status}) async {
    final response = await _dio.get('/api/ddlg/lbr-cases', queryParameters: {if (status != null) 'status': status});
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(LbrCase.fromJson).toList();
  }

  Future<LbrCase> showForDdlg(int id) async {
    final response = await _dio.get('/api/ddlg/lbr-cases/$id');
    return LbrCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<LbrCase>> index({required String role, String? status}) {
    if (role == 'adlg') return indexForAdlg(status: status);
    if (role == 'ddlg') return indexForDdlg(status: status);
    return indexForSecretary();
  }

  Future<LbrCase> show({required String role, required int id}) {
    if (role == 'adlg') return showForAdlg(id);
    if (role == 'ddlg') return showForDdlg(id);
    return showForSecretary(id);
  }

  // -------------------------------------------------------- Secretary: submit

  /// [docs] maps a fixed doc-slot key (or a synthetic `extra_<n>` key for
  /// dynamically added documents) to a file. [extraLabels] supplies the
  /// free-text label typed for each `extra_<n>` key.
  Future<CaseActionResult<LbrCase>> storeCase({
    required String category,
    required String dob,
    required String delayReason,
    required String childName,
    required String childGender,
    required String childBirthPlace,
    String? childBirthType,
    String? childHospital,
    required String applicantName,
    required String applicantCnic,
    String? applicantRelation,
    required String applicantFatherName,
    required String applicantMotherName,
    required String applicantAddress,
    String? applicantPhone,
    String? secretaryRemarks,
    required Map<String, File> docs,
    Map<String, String> extraLabels = const {},
  }) async {
    try {
      final map = <String, dynamic>{
        'category': category,
        'dob': dob,
        'delay_reason': delayReason,
        'child_name': childName,
        'child_gender': childGender,
        'child_birth_place': childBirthPlace,
        if (childBirthType != null && childBirthType.isNotEmpty) 'child_birth_type': childBirthType,
        if (childHospital != null && childHospital.isNotEmpty) 'child_hospital': childHospital,
        'applicant_name': applicantName,
        'applicant_cnic': applicantCnic,
        if (applicantRelation != null && applicantRelation.isNotEmpty) 'applicant_relation': applicantRelation,
        'applicant_father_name': applicantFatherName,
        'applicant_mother_name': applicantMotherName,
        'applicant_address': applicantAddress,
        if (applicantPhone != null && applicantPhone.isNotEmpty) 'applicant_phone': applicantPhone,
        if (secretaryRemarks != null && secretaryRemarks.isNotEmpty) 'secretary_remarks': secretaryRemarks,
      };

      for (final entry in docs.entries) {
        map['documents[${entry.key}]'] = await MultipartFile.fromFile(entry.value.path, filename: entry.value.path.split('/').last);
      }
      for (final entry in extraLabels.entries) {
        map['extra_labels[${entry.key}]'] = entry.value;
      }

      final response = await _dio.post('/api/sec/lbr-cases', data: FormData.fromMap(map));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(LbrCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not submit application.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not submit application. Check your connection.'));
    }
  }

  Future<CaseActionResult<LbrCase>> resubmit({
    required int id,
    required String dob,
    required String delayReason,
    required String childName,
    required String childGender,
    required String childBirthPlace,
    String? childBirthType,
    String? childHospital,
    required String applicantName,
    required String applicantCnic,
    String? applicantRelation,
    required String applicantFatherName,
    required String applicantMotherName,
    required String applicantAddress,
    String? applicantPhone,
    String? secretaryRemarks,
    required Map<String, File> docs,
    Map<String, String> extraLabels = const {},
  }) async {
    try {
      final map = <String, dynamic>{
        'dob': dob,
        'delay_reason': delayReason,
        'child_name': childName,
        'child_gender': childGender,
        'child_birth_place': childBirthPlace,
        if (childBirthType != null && childBirthType.isNotEmpty) 'child_birth_type': childBirthType,
        if (childHospital != null && childHospital.isNotEmpty) 'child_hospital': childHospital,
        'applicant_name': applicantName,
        'applicant_cnic': applicantCnic,
        if (applicantRelation != null && applicantRelation.isNotEmpty) 'applicant_relation': applicantRelation,
        'applicant_father_name': applicantFatherName,
        'applicant_mother_name': applicantMotherName,
        'applicant_address': applicantAddress,
        if (applicantPhone != null && applicantPhone.isNotEmpty) 'applicant_phone': applicantPhone,
        if (secretaryRemarks != null && secretaryRemarks.isNotEmpty) 'secretary_remarks': secretaryRemarks,
      };

      for (final entry in docs.entries) {
        map['documents[${entry.key}]'] = await MultipartFile.fromFile(entry.value.path, filename: entry.value.path.split('/').last);
      }
      for (final entry in extraLabels.entries) {
        map['extra_labels[${entry.key}]'] = entry.value;
      }

      final response = await _dio.post('/api/sec/lbr-cases/$id/resubmit', data: FormData.fromMap(map));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(LbrCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not resubmit application.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not resubmit application. Check your connection.'));
    }
  }

  Future<CaseActionResult<LbrCase>> registerCertificate({
    required int id,
    required String certificateNo,
    required String certificateDate,
    String? certificateRemarks,
  }) async {
    try {
      final response = await _dio.post('/api/sec/lbr-cases/$id/register-certificate', data: {
        'certificate_no': certificateNo,
        'certificate_date': certificateDate,
        if (certificateRemarks != null && certificateRemarks.isNotEmpty) 'certificate_remarks': certificateRemarks,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(LbrCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not register certificate.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not register certificate. Check your connection.'));
    }
  }

  // -------------------------------------------------------------- ADLG/DDLG

  Future<CaseActionResult<LbrCase>> review({
    required String role,
    required int id,
    required String action,
    required String observations,
    String? orderNo,
  }) async {
    try {
      final path = role == 'ddlg' ? '/api/ddlg/lbr-cases/$id/review' : '/api/adlg/lbr-cases/$id/review';
      final response = await _dio.post(path, data: {
        'action': action,
        'observations': observations,
        if (orderNo != null && orderNo.isNotEmpty) 'order_no': orderNo,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(LbrCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not submit decision.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not submit decision. Check your connection.'));
    }
  }

  // --------------------------------------------------------------- Export

  Future<File> _downloadFile(String path, Map<String, dynamic>? query, String fallbackFilename) async {
    final response = await _dio.get<List<int>>(path, queryParameters: query, options: Options(responseType: ResponseType.bytes));

    if (response.statusCode != 200 || response.data == null) {
      throw DioException(requestOptions: response.requestOptions, response: response);
    }

    final filename = _filenameFromContentDisposition(response.headers.value('content-disposition')) ?? fallbackFilename;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.data!);
    return file;
  }

  Future<File> downloadNotesheet({required String role, required int id}) {
    return _downloadFile('/api/$role/lbr-cases/$id/notesheet', null, 'LBR_Notesheet.pdf');
  }

  /// ADLG/DDLG-only Excel export of the birth-registration registry.
  Future<File> exportCases({required String role, String? status}) {
    final path = role == 'ddlg' ? '/api/ddlg/lbr-cases-export' : '/api/adlg/lbr-cases-export';
    return _downloadFile(path, {if (status != null) 'status': status}, 'Birth_Registration_Export.xlsx');
  }

  String? _filenameFromContentDisposition(String? header) {
    if (header == null) return null;
    final match = RegExp('filename="?([^";]+)"?').firstMatch(header);
    return match?.group(1);
  }
}
