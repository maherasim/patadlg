import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/directory_user.dart';
import '../models/union_council.dart';
import 'api_client.dart';
import 'case_service.dart' show CaseActionResult;

/// Union Councils / Secretaries / Tehsils / ADLGs directory & management —
/// ADLG gets create/edit (UCs) and full management (Secretaries); DDLG's
/// four "District Oversight" screens are all read-only district-wide views,
/// matching the web app exactly (see PART research: DDLG cannot create/edit
/// anything on these pages).
class DirectoryService {
  DirectoryService._();

  static final DirectoryService instance = DirectoryService._();

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

  Future<File> _downloadExport(String path) async {
    final response = await _dio.get<List<int>>(path, options: Options(responseType: ResponseType.bytes));
    if (response.statusCode != 200 || response.data == null) {
      throw DioException(requestOptions: response.requestOptions, response: response);
    }
    final filename = _filenameFromContentDisposition(response.headers.value('content-disposition')) ?? 'Export.xlsx';
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

  // ------------------------------------------------------------ Union Councils

  Future<List<UnionCouncil>> unionCouncilsForAdlg() async {
    final response = await _dio.get('/api/adlg/union-councils');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(UnionCouncil.fromJson).toList();
  }

  Future<List<UnionCouncil>> unionCouncilsForDdlg() async {
    final response = await _dio.get('/api/ddlg/union-councils');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(UnionCouncil.fromJson).toList();
  }

  Future<CaseActionResult<UnionCouncil>> createUnionCouncil({
    required String name,
    int? ucNo,
    String? code,
    String? address,
    double? lat,
    double? lng,
    int? geofenceRadius,
  }) async {
    try {
      final response = await _dio.post('/api/adlg/union-councils', data: {
        'name': name,
        if (ucNo != null) 'uc_no': ucNo,
        if (code != null && code.isNotEmpty) 'code': code,
        if (address != null && address.isNotEmpty) 'address': address,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (geofenceRadius != null) 'geofence_radius': geofenceRadius,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(UnionCouncil.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not create union council.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not create union council. Check your connection.'));
    }
  }

  Future<CaseActionResult<UnionCouncil>> updateUnionCouncil({
    required int id,
    required String name,
    int? ucNo,
    String? code,
    String? address,
    double? lat,
    double? lng,
    int? geofenceRadius,
  }) async {
    try {
      final response = await _dio.put('/api/adlg/union-councils/$id', data: {
        'name': name,
        if (ucNo != null) 'uc_no': ucNo,
        if (code != null && code.isNotEmpty) 'code': code,
        if (address != null && address.isNotEmpty) 'address': address,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (geofenceRadius != null) 'geofence_radius': geofenceRadius,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(UnionCouncil.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not update union council.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not update union council. Check your connection.'));
    }
  }

  Future<File> exportUnionCouncils({required String role}) {
    return _downloadExport(role == 'ddlg' ? '/api/ddlg/union-councils-export' : '/api/adlg/union-councils-export');
  }

  // -------------------------------------------------------------- Secretaries

  Future<List<DirectoryUser>> secretariesForAdlg() async {
    final response = await _dio.get('/api/adlg/secretaries');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DirectoryUser.fromJson).toList();
  }

  Future<List<DirectoryUser>> secretariesForDdlg() async {
    final response = await _dio.get('/api/ddlg/secretaries');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DirectoryUser.fromJson).toList();
  }

  Future<CaseActionResult<DirectoryUser>> createSecretary({
    required int unionCouncilId,
    required String name,
    String? fatherName,
    required String username,
    String? email,
    required String password,
    String? cnic,
    String? phone,
  }) async {
    try {
      final response = await _dio.post('/api/adlg/secretaries', data: {
        'union_council_id': unionCouncilId,
        'name': name,
        if (fatherName != null && fatherName.isNotEmpty) 'father_name': fatherName,
        'username': username,
        if (email != null && email.isNotEmpty) 'email': email,
        'password': password,
        'password_confirmation': password,
        if (cnic != null && cnic.isNotEmpty) 'cnic': cnic,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DirectoryUser.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not create secretary.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not create secretary. Check your connection.'));
    }
  }

  Future<CaseActionResult<DirectoryUser>> updateSecretary({
    required int id,
    required int unionCouncilId,
    required String name,
    String? fatherName,
    required String username,
    String? email,
    String? cnic,
    String? phone,
  }) async {
    try {
      final response = await _dio.put('/api/adlg/secretaries/$id', data: {
        'union_council_id': unionCouncilId,
        'name': name,
        if (fatherName != null && fatherName.isNotEmpty) 'father_name': fatherName,
        'username': username,
        if (email != null && email.isNotEmpty) 'email': email,
        if (cnic != null && cnic.isNotEmpty) 'cnic': cnic,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DirectoryUser.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not update secretary.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not update secretary. Check your connection.'));
    }
  }

  Future<bool> toggleSecretaryActive(int id) async {
    try {
      final response = await _dio.patch('/api/adlg/secretaries/$id/toggle-active');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<CaseActionResult<void>> resetSecretaryPassword({required int id, required String password}) async {
    try {
      final response = await _dio.post('/api/adlg/secretaries/$id/reset-password', data: {
        'password': password,
        'password_confirmation': password,
      });
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        return CaseActionResult.success(null);
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not reset password.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not reset password. Check your connection.'));
    }
  }

  Future<CaseActionResult<DirectoryUser>> assignCharge({required int secretaryId, required int unionCouncilId}) async {
    try {
      final response = await _dio.post('/api/adlg/secretaries/$secretaryId/charges', data: {'union_council_id': unionCouncilId});
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CaseActionResult.success(DirectoryUser.fromJson(response.data['data'] as Map<String, dynamic>));
      }
      return CaseActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not assign charge.'));
    } on DioException catch (e) {
      return CaseActionResult.failure(_errorFrom(e, 'Could not assign charge. Check your connection.'));
    }
  }

  Future<bool> removeCharge({required int secretaryId, required int unionCouncilId}) async {
    try {
      final response = await _dio.delete('/api/adlg/secretaries/$secretaryId/charges/$unionCouncilId');
      return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<File> exportSecretaries({required String role}) {
    return _downloadExport(role == 'ddlg' ? '/api/ddlg/secretaries-export' : '/api/adlg/secretaries-export');
  }

  // -------------------------------------------------------------------- DDLG

  Future<List<Tehsil>> tehsilsForDdlg() async {
    final response = await _dio.get('/api/ddlg/tehsils');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(Tehsil.fromJson).toList();
  }

  Future<File> exportTehsils() => _downloadExport('/api/ddlg/tehsils-export');

  Future<List<DirectoryUser>> adlgsForDdlg() async {
    final response = await _dio.get('/api/ddlg/adlgs');
    final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DirectoryUser.fromJson).toList();
  }

  Future<File> exportAdlgs() => _downloadExport('/api/ddlg/adlgs-export');
}
