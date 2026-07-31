import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/death_case.dart';
import 'api_client.dart';
import 'case_service.dart' show CaseActionResult;

/// Late Death Registration (LDR) — mirrors LbrService's shape/conventions
/// (multipart submits, CaseActionResult-style error unwrapping, PDF/Excel
/// downloads to a temp file for the share sheet).
class DeathCaseService {
  DeathCaseService._();

  static final DeathCaseService instance = DeathCaseService._();

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

  Future<List<DeathCase>> indexForSecretary() async {
    final response = await _dio.get('/api/sec/death-cases');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DeathCase.fromJson).toList();
  }

  Future<DeathCase> showForSecretary(int id) async {
    final response = await _dio.get('/api/sec/death-cases/$id');
    return DeathCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<DeathCase>> indexForAdlg({String? status}) async {
    final response = await _dio.get('/api/adlg/death-cases', queryParameters: {if (status != null) 'status': status});
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DeathCase.fromJson).toList();
  }

  Future<DeathCase> showForAdlg(int id) async {
    final response = await _dio.get('/api/adlg/death-cases/$id');
    return DeathCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<DeathCase>> indexForDdlg({String? status}) async {
    final response = await _dio.get('/api/ddlg/death-cases', queryParameters: {if (status != null) 'status': status});
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DeathCase.fromJson).toList();
  }

  Future<DeathCase> showForDdlg(int id) async {
    final response = await _dio.get('/api/ddlg/death-cases/$id');
    return DeathCase.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<DeathCase>> index({required String role, String? status}) {
    if (role == 'adlg') return indexForAdlg(status: status);
    if (role == 'ddlg') return indexForDdlg(status: status);
    return indexForSecretary();
  }

  Future<DeathCase> show({required String role, required int id}) {
    if (role == 'adlg') return showForAdlg(id);
    if (role == 'ddlg') return showForDdlg(id);
    return showForSecretary(id);
  }

  // -------------------------------------------------------- Secretary: submit

  /// [docs] maps a fixed doc-slot key to a file. [courtDecreeNo]/etc. only
  /// apply to category '7+'; [countryOfDeath]/[passportNo] only to 'ABROAD'.
  Future<CaseActionResult<DeathCase>> storeCase({
    required String category,
    required String dateOfDeath,
    required String delayReason,
    required String deceasedName,
    required String deceasedGender,
    String? deceasedCnic,
    String? causeOfDeath,
    String? placeOfDeath,
    String? burialPlace,
    required String applicantName,
    required String applicantCnic,
    required String applicantRelation,
    required String applicantAddress,
    String? applicantPhone,
    String? courtDecreeNo,
    String? courtDecreeDate,
    String? courtName,
    String? countryOfDeath,
    String? passportNo,
    String? secretaryRemarks,
    required Map<String, File> docs,
  }) async {
    try {
      final map = <String, dynamic>{
        'category': category,
        'date_of_death': dateOfDeath,
        'delay_reason': delayReason,
        'deceased_name': deceasedName,
        'deceased_gender': deceasedGender,
        if (deceasedCnic != null && deceasedCnic.isNotEmpty) 'deceased_cnic': deceasedCnic,
        if (causeOfDeath != null && causeOfDeath.isNotEmpty) 'cause_of_death': causeOfDeath,
        if (placeOfDeath != null && placeOfDeath.isNotEmpty) 'place_of_death': placeOfDeath,
        if (burialPlace != null && burialPlace.isNotEmpty) 'burial_place': burialPlace,
        'applicant_name': applicantName,
        'applicant_cnic': applicantCnic,
        'applicant_relation': applicantRelation,
        'applicant_address': applicantAddress,
        if (applicantPhone != null && applicantPhone.isNotEmpty) 'applicant_phone': applicantPhone,
        if (category == '7+' && courtDecreeNo != null) 'court_decree_no': courtDecreeNo,
        if (category == '7+' && courtDecreeDate != null) 'court_decree_date': courtDecreeDate,
        if (category == '7+' && courtName != null) 'court_name': courtName,
        if (category == 'ABROAD' && countryOfDeath != null) 'country_of_death': countryOfDeath,
        if (category == 'ABROAD' && passportNo != null) 'passport_no': passportNo,
        if (secretaryRemarks != null && secretaryRemarks.isNotEmpty) 'secretary_remarks': secretaryRemarks,
      };

      for (final entry in docs.entries) {
        map['documents[${entry.key}]'] = await MultipartFile.fromFile(entry.value.path, filename: entry.value.path.split('/').last);
      }

      final response = await _dio.post('/api/sec/death-cases', data: FormData.fromMap(map));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DeathCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not submit application.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not submit application. Check your connection.'));
    }
  }

  Future<CaseActionResult<DeathCase>> resubmit({
    required int id,
    required String category,
    required String dateOfDeath,
    required String delayReason,
    required String deceasedName,
    required String deceasedGender,
    String? deceasedCnic,
    String? causeOfDeath,
    String? placeOfDeath,
    String? burialPlace,
    required String applicantName,
    required String applicantCnic,
    required String applicantRelation,
    required String applicantAddress,
    String? applicantPhone,
    String? courtDecreeNo,
    String? courtDecreeDate,
    String? courtName,
    String? countryOfDeath,
    String? passportNo,
    String? secretaryRemarks,
    required Map<String, File> docs,
  }) async {
    try {
      final map = <String, dynamic>{
        'date_of_death': dateOfDeath,
        'delay_reason': delayReason,
        'deceased_name': deceasedName,
        'deceased_gender': deceasedGender,
        if (deceasedCnic != null && deceasedCnic.isNotEmpty) 'deceased_cnic': deceasedCnic,
        if (causeOfDeath != null && causeOfDeath.isNotEmpty) 'cause_of_death': causeOfDeath,
        if (placeOfDeath != null && placeOfDeath.isNotEmpty) 'place_of_death': placeOfDeath,
        if (burialPlace != null && burialPlace.isNotEmpty) 'burial_place': burialPlace,
        'applicant_name': applicantName,
        'applicant_cnic': applicantCnic,
        'applicant_relation': applicantRelation,
        'applicant_address': applicantAddress,
        if (applicantPhone != null && applicantPhone.isNotEmpty) 'applicant_phone': applicantPhone,
        if (category == '7+' && courtDecreeNo != null) 'court_decree_no': courtDecreeNo,
        if (category == '7+' && courtDecreeDate != null) 'court_decree_date': courtDecreeDate,
        if (category == '7+' && courtName != null) 'court_name': courtName,
        if (category == 'ABROAD' && countryOfDeath != null) 'country_of_death': countryOfDeath,
        if (category == 'ABROAD' && passportNo != null) 'passport_no': passportNo,
        if (secretaryRemarks != null && secretaryRemarks.isNotEmpty) 'secretary_remarks': secretaryRemarks,
      };

      for (final entry in docs.entries) {
        map['documents[${entry.key}]'] = await MultipartFile.fromFile(entry.value.path, filename: entry.value.path.split('/').last);
      }

      final response = await _dio.post('/api/sec/death-cases/$id/resubmit', data: FormData.fromMap(map));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DeathCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not resubmit application.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not resubmit application. Check your connection.'));
    }
  }

  Future<CaseActionResult<DeathCase>> registerCertificate({
    required int id,
    required String certificateNo,
    required String certificateDate,
    String? certificateRemarks,
  }) async {
    try {
      final response = await _dio.post('/api/sec/death-cases/$id/register-certificate', data: {
        'certificate_no': certificateNo,
        'certificate_date': certificateDate,
        if (certificateRemarks != null && certificateRemarks.isNotEmpty) 'certificate_remarks': certificateRemarks,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DeathCase.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not register certificate.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not register certificate. Check your connection.'));
    }
  }

  // -------------------------------------------------------------- ADLG/DDLG

  Future<CaseActionResult<DeathCase>> review({
    required String role,
    required int id,
    required String action,
    required String observations,
    String? orderNo,
  }) async {
    try {
      final path = role == 'ddlg' ? '/api/ddlg/death-cases/$id/review' : '/api/adlg/death-cases/$id/review';
      final response = await _dio.post(path, data: {
        'action': action,
        'observations': observations,
        if (orderNo != null && orderNo.isNotEmpty) 'order_no': orderNo,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DeathCase.fromJson(response.data['data'] as Map<String, dynamic>));
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
    return _downloadFile('/api/$role/death-cases/$id/notesheet', null, 'LDR_Notesheet.pdf');
  }

  /// ADLG/DDLG-only Excel export of the death-registration registry.
  /// (No export route exists for Secretary — matches the web app.)
  Future<File> exportCases({required String role, String? status}) {
    final path = role == 'ddlg' ? '/api/ddlg/death-cases-export' : '/api/adlg/death-cases-export';
    return _downloadFile(path, {if (status != null) 'status': status}, 'Death_Registration_Export.xlsx');
  }

  String? _filenameFromContentDisposition(String? header) {
    if (header == null) return null;
    final match = RegExp('filename="?([^";]+)"?').firstMatch(header);
    return match?.group(1);
  }
}
