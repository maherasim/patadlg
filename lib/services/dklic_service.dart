import 'package:dio/dio.dart';

import '../models/dklic_document.dart';
import 'api_client.dart';

/// The DKLIC Knowledge Repository (Local Government Library) and its AI
/// Legal Intelligence Assistant (Local Government Chatbot) — same backend
/// endpoints, shared verbatim across sec/adlg/ddlg (only the audience filter
/// server-side differs by role).
class DklicService {
  DklicService._();

  static final DklicService instance = DklicService._();

  Dio get _dio => ApiClient.instance.dio;

  Future<List<DklicDocument>> index({
    required String role,
    String? search,
    String? category,
    String? filter,
  }) async {
    final response = await _dio.get('/api/$role/dklic-documents', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
      if (filter != null && filter != 'all') 'filter': filter,
    });
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DklicDocument.fromJson).toList();
  }

  Future<void> markViewed({required String role, required int documentId}) async {
    try {
      await _dio.post('/api/$role/dklic-documents/$documentId/view');
    } catch (_) {
      // Best-effort telemetry — don't block the reader on it.
    }
  }

  Future<void> markDownloaded({required String role, required int documentId}) async {
    try {
      await _dio.post('/api/$role/dklic-documents/$documentId/download');
    } catch (_) {
      // Best-effort telemetry.
    }
  }

  Future<bool> toggleBookmark({required String role, required int documentId}) async {
    final response = await _dio.post('/api/$role/dklic-documents/$documentId/bookmark');
    return response.data['bookmarked'] as bool? ?? false;
  }

  Future<DklicDocument> acknowledge({required String role, required int documentId}) async {
    final response = await _dio.post('/api/$role/dklic-documents/$documentId/acknowledge');
    final data = response.data['data'] as Map<String, dynamic>;
    return DklicDocument.fromJson(data);
  }

  Future<DklicAiAnswer> askAi({required String role, required String query}) async {
    final response = await _dio.post('/api/$role/dklic-ai/ask', data: {'query': query});
    return DklicAiAnswer.fromJson(response.data as Map<String, dynamic>);
  }
}
