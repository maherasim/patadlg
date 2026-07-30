import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/performa.dart';
import 'api_client.dart';
import 'case_service.dart' show CaseActionResult;

class PerformaListResult {
  PerformaListResult({required this.items, required this.totalSecretaries});

  final List<Performa> items;
  final int totalSecretaries;
}

/// The "ADLG Performas" module — a second reporting channel alongside the
/// Daily Report, where the ADLG broadcasts either a dynamic in-app form or an
/// Excel template to every secretary in the tehsil. Mirrors CaseService's
/// error-unwrapping and download-to-temp-file conventions.
class PerformaService {
  PerformaService._();

  static final PerformaService instance = PerformaService._();

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

  // ------------------------------------------------------------------ ADLG

  Future<PerformaListResult> indexForAdlg() async {
    final response = await _dio.get('/api/adlg/performas');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    final meta = response.data['meta'] as Map<String, dynamic>? ?? {};
    return PerformaListResult(
      items: list.map(Performa.fromJson).toList(),
      totalSecretaries: (meta['total_secretaries'] as num?)?.toInt() ?? 0,
    );
  }

  /// [fields] is only sent for form mode; [excelTemplate] only for excel mode.
  Future<CaseActionResult<Performa>> createPerforma({
    required String title,
    String? description,
    required String mode,
    required String reportType,
    String? deadline,
    File? excelTemplate,
    List<(String label, String type)> fields = const [],
  }) async {
    try {
      final map = <String, dynamic>{
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'mode': mode,
        'report_type': reportType,
        if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
      };

      if (mode == 'excel' && excelTemplate != null) {
        map['excel_template'] = await MultipartFile.fromFile(excelTemplate.path, filename: excelTemplate.path.split('/').last);
      }
      if (mode == 'form') {
        for (var i = 0; i < fields.length; i++) {
          map['fields[$i][label]'] = fields[i].$1;
          map['fields[$i][type]'] = fields[i].$2;
        }
      }

      final response = await _dio.post('/api/adlg/performas', data: FormData.fromMap(map));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(Performa.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not publish performa.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not publish performa. Check your connection.'));
    }
  }

  Future<List<PerformaResponse>> responses(int performaId) async {
    final response = await _dio.get('/api/adlg/performas/$performaId/responses');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(PerformaResponse.fromJson).toList();
  }

  Future<File> exportResponses(int performaId) {
    return _downloadFile('/api/adlg/performas/$performaId/responses/export', 'Performa_Responses_Export.xlsx');
  }

  Future<File> downloadTemplateForAdlg(int performaId) {
    return _downloadFile('/api/adlg/performas/$performaId/template', 'Performa_Template.xlsx');
  }

  // ------------------------------------------------------------ Secretary

  Future<List<Performa>> indexForSecretary() async {
    final response = await _dio.get('/api/sec/performas');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(Performa.fromJson).toList();
  }

  Future<CaseActionResult<PerformaResponse>> respondForm({required int performaId, required Map<int, String> values}) async {
    try {
      final response = await _dio.post('/api/sec/performas/$performaId/respond-form', data: {
        'values': {for (final entry in values.entries) entry.key.toString(): entry.value},
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(PerformaResponse.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not submit performa.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not submit performa. Check your connection.'));
    }
  }

  Future<CaseActionResult<PerformaResponse>> respondExcel({required int performaId, required File file}) async {
    try {
      final response = await _dio.post(
        '/api/sec/performas/$performaId/respond-excel',
        data: FormData.fromMap({'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last)}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(PerformaResponse.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not upload file.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not upload file. Check your connection.'));
    }
  }

  Future<File> downloadTemplateForSecretary(int performaId) {
    return _downloadFile('/api/sec/performas/$performaId/template', 'Performa_Template.xlsx');
  }

  // --------------------------------------------------------------- Shared

  Future<File> _downloadFile(String path, String fallbackFilename) async {
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

  String? _filenameFromContentDisposition(String? header) {
    if (header == null) return null;
    final match = RegExp('filename="?([^";]+)"?').firstMatch(header);
    return match?.group(1);
  }
}
