import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AuthResult {
  AuthResult.success(this.user) : errorMessage = null;
  AuthResult.failure(this.errorMessage) : user = null;

  final Map<String, dynamic>? user;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

class AuthService {
  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  static const _kOnboardingDone = 'onboarding_done';
  static const _kTermsAccepted = 'terms_accepted';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingDone) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
  }

  Future<bool> hasAcceptedTerms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTermsAccepted) ?? false;
  }

  Future<void> markTermsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTermsAccepted, true);
  }

  /// Mirrors the web app's login contract exactly: POST /api/login with
  /// {login, password, remember}, field name "login" accepts username or email.
  Future<AuthResult> login({
    required String login,
    required String password,
    bool remember = true,
  }) async {
    final api = ApiClient.instance;

    try {
      await api.primeCsrf();

      final response = await api.dio.post(
        '/api/login',
        data: {
          'login': login,
          'password': password,
          'remember': remember,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final userJson = data is Map<String, dynamic> && data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        return AuthResult.success(userJson);
      }

      if (response.statusCode == 422) {
        final errors = response.data?['errors'] as Map<String, dynamic>?;
        final message = errors?['login']?[0] ??
            response.data?['message'] ??
            'Invalid username/email or password.';
        return AuthResult.failure(message.toString());
      }

      return AuthResult.failure(response.data?['message']?.toString() ?? 'Something went wrong. Please try again.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return AuthResult.failure('Could not reach the server. Check your internet connection.');
      }
      return AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  Future<Map<String, dynamic>?> currentUser() async {
    try {
      final response = await ApiClient.instance.dio.get('/api/me');
      if (response.statusCode == 200) {
        final data = response.data;
        return data is Map<String, dynamic> && data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
      }
    } catch (_) {
      // Falls through to null — treated as "not logged in".
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.dio.post('/api/logout');
    } catch (_) {
      // Best-effort — clear local session regardless of server response.
    }
    await ApiClient.instance.clearSession();
  }
}
