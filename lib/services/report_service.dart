import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/daily_report.dart';
import 'api_client.dart';

class ReportActionResult<T> {
  ReportActionResult.success(this.data) : errorMessage = null;
  ReportActionResult.failure(this.errorMessage) : data = null;

  final T? data;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

/// A secretary's ad-hoc "Additional Field" — free label + free value, added
/// on the fly. Only rows with a non-blank label are actually sent, mirroring
/// the web app's own filter.
class CustomFieldInput {
  CustomFieldInput({this.label = '', this.value = ''});

  String label;
  String value;
}

class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

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

  /// Standing fields the ADLG has defined for the secretary's own tehsil —
  /// active ones only, each answered as plain text on the submission form.
  Future<List<ReportFieldDefinition>> fieldsForSecretary() async {
    final response = await _dio.get('/api/sec/report-fields');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(ReportFieldDefinition.fromJson).toList();
  }

  Future<List<DailyReport>> myHistory() async {
    final response = await _dio.get('/api/sec/reports');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DailyReport.fromJson).toList();
  }

  /// Submits today's daily report. [fieldResponses] keys are
  /// ReportFieldDefinition ids; every currently-shown standing field is sent
  /// (even blank), matching the web app's own behavior — only [customFields]
  /// rows with a non-blank label are actually included.
  Future<ReportActionResult<DailyReport>> submit({
    required String remarks,
    required int nikahCount,
    required int birthCount,
    required int deathCount,
    required int complaintCount,
    required Map<int, String> fieldResponses,
    required List<CustomFieldInput> customFields,
    File? attachment,
  }) async {
    try {
      final data = <String, dynamic>{
        'remarks': remarks,
        'nikah_count': nikahCount,
        'birth_count': birthCount,
        'death_count': deathCount,
        'complaint_count': complaintCount,
      };

      var i = 0;
      for (final entry in fieldResponses.entries) {
        data['field_responses[$i][field_definition_id]'] = entry.key;
        data['field_responses[$i][value]'] = entry.value;
        i++;
      }

      var j = 0;
      for (final field in customFields) {
        if (field.label.trim().isEmpty) continue;
        data['custom_fields[$j][label]'] = field.label;
        data['custom_fields[$j][value]'] = field.value;
        j++;
      }

      if (attachment != null) {
        data['attachment'] = await MultipartFile.fromFile(attachment.path, filename: attachment.path.split('/').last);
      }

      final response = await _dio.post('/api/sec/reports', data: FormData.fromMap(data));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = response.data['data'] as Map<String, dynamic>;
        return ReportActionResult.success(DailyReport.fromJson(json));
      }

      return ReportActionResult.failure(_errorFrom(
        DioException(requestOptions: response.requestOptions, response: response),
        'Could not submit report.',
      ));
    } on DioException catch (e) {
      return ReportActionResult.failure(_errorFrom(e, 'Could not submit report. Check your connection.'));
    }
  }

  /// ADLG's tehsil-wide reports feed — newest 200, no server-side filters
  /// (matches the web app's own behavior; filtering happens client-side).
  Future<List<DailyReport>> indexForAdlg() async {
    final response = await _dio.get('/api/adlg/reports');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DailyReport.fromJson).toList();
  }

  Future<bool> markReviewed(int reportId) async {
    try {
      final response = await _dio.patch('/api/adlg/reports/$reportId/mark-reviewed');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// All standing fields for the ADLG's own tehsil, active and inactive —
  /// used by the "Manage Additional Fields" screen.
  Future<List<ReportFieldDefinition>> fieldsForAdlg() async {
    final response = await _dio.get('/api/adlg/report-fields');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(ReportFieldDefinition.fromJson).toList();
  }

  Future<ReportActionResult<ReportFieldDefinition>> addField(String label) async {
    try {
      final response = await _dio.post('/api/adlg/report-fields', data: {'label': label});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = response.data['data'] as Map<String, dynamic>;
        return ReportActionResult.success(ReportFieldDefinition.fromJson(json));
      }
      return ReportActionResult.failure('Could not add field.');
    } on DioException catch (e) {
      return ReportActionResult.failure(_errorFrom(e, 'Could not add field. Check your connection.'));
    }
  }

  Future<bool> toggleFieldActive(int fieldId) async {
    try {
      final response = await _dio.patch('/api/adlg/report-fields/$fieldId/toggle-active');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the styled reports Excel export and saves it to the app's
  /// temp directory, ready to hand to the share sheet.
  Future<File> exportReports() async {
    final response = await _dio.get<List<int>>(
      '/api/adlg/reports/export',
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw DioException(requestOptions: response.requestOptions, response: response);
    }

    final filename = _filenameFromContentDisposition(response.headers.value('content-disposition')) ?? 'Daily_Reports_Export.xlsx';
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
