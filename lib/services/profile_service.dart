import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

class ProfileActionResult {
  ProfileActionResult.success(this.user) : errorMessage = null;
  ProfileActionResult.failure(this.errorMessage) : user = null;

  final Map<String, dynamic>? user;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  Dio get _dio => ApiClient.instance.dio;

  /// Mirrors the web app's mandatory first-login password step — same
  /// endpoint, same {password, password_confirmation} contract, min:6 chars
  /// and nothing else (no complexity rules), matching web exactly. Sets
  /// first_login=false server-side on success, so completing it here also
  /// clears the gate on the web app.
  Future<ProfileActionResult> completeFirstLogin({
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _dio.post('/api/profile/complete-first-login', data: {
        'password': password,
        'password_confirmation': passwordConfirmation,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final userJson = data is Map<String, dynamic> && data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        return ProfileActionResult.success(userJson);
      }

      if (response.statusCode == 422) {
        final errors = response.data?['errors'] as Map<String, dynamic>?;
        final message = errors?['password']?[0] ?? response.data?['message'] ?? 'Could not set your password.';
        return ProfileActionResult.failure(message.toString());
      }

      return ProfileActionResult.failure(response.data?['message']?.toString() ?? 'Something went wrong. Please try again.');
    } on DioException catch (_) {
      return ProfileActionResult.failure('Could not reach the server. Check your connection and try again.');
    }
  }

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

  /// Self-service password change from the Settings screen — distinct from
  /// [completeFirstLogin] above, which is the one-time mandatory reset and
  /// requires no current-password check.
  Future<ProfileActionResult> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/profile/change-password', data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': password,
      });
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ProfileActionResult.success(null);
      }
      return ProfileActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not change password.'));
    } on DioException catch (e) {
      return ProfileActionResult.failure(_errorFrom(e, 'Could not change password. Check your connection.'));
    }
  }

  Future<ProfileActionResult> uploadAvatar(File file) async {
    try {
      final response = await _dio.post(
        '/api/profile/avatar',
        data: FormData.fromMap({'avatar': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last)}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final json = data is Map && data.containsKey('data') ? data['data'] as Map<String, dynamic> : data as Map<String, dynamic>;
        return ProfileActionResult.success(json);
      }
      return ProfileActionResult.failure(_errorFrom(DioException(requestOptions: response.requestOptions, response: response), 'Could not upload photo.'));
    } on DioException catch (e) {
      return ProfileActionResult.failure(_errorFrom(e, 'Could not upload photo. Check your connection.'));
    }
  }
}
