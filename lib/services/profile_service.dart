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
}
