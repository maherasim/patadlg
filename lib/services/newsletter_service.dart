import 'package:dio/dio.dart';

import '../models/newsletter.dart';
import 'api_client.dart';
import 'case_service.dart' show CaseActionResult;

/// Directives & Newsletters — Super Admin publishes, ADLG/DDLG each respond
/// independently. Both roles hit route-prefixed but otherwise identical
/// endpoints, matching the web app's adlg/ddlg Newsletters.jsx pages.
class NewsletterService {
  NewsletterService._();

  static final NewsletterService instance = NewsletterService._();

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

  Future<List<Newsletter>> indexForAdlg() async {
    final response = await _dio.get('/api/adlg/newsletters');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    return list.map(Newsletter.fromJson).toList();
  }

  Future<List<Newsletter>> indexForDdlg() async {
    final response = await _dio.get('/api/ddlg/newsletters');
    final list = (response.data as List).cast<Map<String, dynamic>>();
    return list.map(Newsletter.fromJson).toList();
  }

  Future<CaseActionResult<void>> respond({
    required String role,
    required int newsletterId,
    required int optionId,
    String? remarks,
  }) async {
    try {
      final response = await _dio.post('/api/$role/newsletters/$newsletterId/respond', data: {
        'newsletter_option_id': optionId,
        if (remarks != null) 'remarks': remarks,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(null);
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not submit response.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not submit response. Check your connection.'));
    }
  }
}
