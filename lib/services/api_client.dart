import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Live production backend — the whole platform (web dashboard + this app)
/// talks to the same Laravel API, mounted at the domain root.
const String kApiBaseUrl = 'https://pa-to-adlg.com';

/// The backend uses Laravel Sanctum's SPA (session-cookie) auth, not bearer
/// tokens — the same mechanism the React web dashboard uses. So this client
/// replicates that flow: fetch a CSRF cookie once, then send it back as the
/// X-XSRF-TOKEN header on every mutating request, with cookies persisted to
/// disk so a login survives the app being closed and reopened.
class ApiClient {
  ApiClient._internal();

  static final ApiClient instance = ApiClient._internal();

  late final Dio dio;
  PersistCookieJar? _cookieJar;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;

    final dir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage('${dir.path}/.cookies/'),
    );

    dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          // Sanctum's EnsureFrontendRequestsAreStateful only treats a request
          // as session/cookie-based if it carries an Origin or Referer header
          // matching a configured stateful domain — browsers send this
          // automatically, a native HTTP client doesn't, so without it every
          // request silently falls back to (unused) token auth and 401s.
          'Referer': kApiBaseUrl,
          'Origin': kApiBaseUrl,
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    dio.interceptors.add(CookieManager(_cookieJar!));
    dio.interceptors.add(_XsrfHeaderInterceptor(_cookieJar!));

    // Prints every request/response (method, url, headers, body) to the
    // `flutter run` console — debug builds only, never shipped in release.
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    _ready = true;
  }

  /// Primes the session with a CSRF cookie — must be called before login,
  /// same as the web app's initial Sanctum handshake.
  Future<void> primeCsrf() async {
    await dio.get('/sanctum/csrf-cookie');
  }

  Future<bool> hasSessionCookie() async {
    final uri = Uri.parse(kApiBaseUrl);
    final cookies = await _cookieJar?.loadForRequest(uri) ?? [];
    return cookies.any((c) => c.name.contains('session'));
  }

  Future<void> clearSession() async {
    await _cookieJar?.deleteAll();
  }
}

/// Sanctum expects the CSRF token from the XSRF-TOKEN cookie to be echoed
/// back as a request header on every state-changing call.
class _XsrfHeaderInterceptor extends Interceptor {
  _XsrfHeaderInterceptor(this._cookieJar);

  final PersistCookieJar _cookieJar;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final cookies = await _cookieJar.loadForRequest(Uri.parse(kApiBaseUrl));
    for (final cookie in cookies) {
      if (cookie.name == 'XSRF-TOKEN') {
        options.headers['X-XSRF-TOKEN'] = Uri.decodeComponent(cookie.value);
        break;
      }
    }
    handler.next(options);
  }
}
