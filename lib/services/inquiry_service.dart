import 'dart:io';

import 'package:dio/dio.dart';

import '../models/inquiry.dart';
import 'api_client.dart';
import 'case_service.dart' show CaseActionResult;

/// Inquiry Requests — ADLG (and DDLG, filing on their own behalf) upload a
/// file with remarks; Super Admin drafts and returns a formal report.
/// DDLG's list also includes every inquiry filed by ADLGs in their district
/// (see InquiryController::indexForDdlg on the backend).
class InquiryService {
  InquiryService._();

  static final InquiryService instance = InquiryService._();

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

  Future<List<Inquiry>> indexForAdlg() async {
    final response = await _dio.get('/api/adlg/inquiries');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(Inquiry.fromJson).toList();
  }

  Future<List<Inquiry>> indexForDdlg() async {
    final response = await _dio.get('/api/ddlg/inquiries');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(Inquiry.fromJson).toList();
  }

  Future<CaseActionResult<Inquiry>> submit({
    required String role,
    required String subject,
    int? unionCouncilId,
    required String remarks,
    required File file,
  }) async {
    try {
      final map = <String, dynamic>{
        'subject': subject,
        if (unionCouncilId != null) 'union_council_id': unionCouncilId,
        'remarks': remarks,
        'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
      };

      final response = await _dio.post('/api/$role/inquiries', data: FormData.fromMap(map));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(Inquiry.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not submit inquiry.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not submit inquiry. Check your connection.'));
    }
  }
}
