import 'package:dio/dio.dart';

/// Default backend = the Firebase `api` function behind Hosting (same /api/mobile/* contract as before).
/// Override per build: flutter build appbundle --dart-define=API_BASE_URL=http://10.0.2.2:8787 (local run).
const kDefaultBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://go4foodies.web.app');

/// Public website origin — the payment page is loaded under it (gateways check the domain).
/// Set it per build with --dart-define=SITE_ORIGIN=https://example.com
const kSiteOrigin = String.fromEnvironment('SITE_ORIGIN', defaultValue: 'https://themerchant.disolutions.net');

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  bool get unauthorized => status == 401;
  @override
  String toString() => message;
}

/// Thin JSON client over Dio. Every call returns the decoded body (a Map) or
/// throws [ApiException] with the server's `{error}` message.
class Api {
  Api(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
          contentType: 'application/json',
          validateStatus: (_) => true,
        ));

  final Dio _dio;
  String? token;
  void Function()? onUnauthorized;

  String get baseUrl => _dio.options.baseUrl;
  set baseUrl(String v) => _dio.options.baseUrl = v;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<Map<String, dynamic>> post(String path, [Object? body]) => _send('POST', path, body: body ?? const {});
  Future<Map<String, dynamic>> put(String path, [Object? body]) => _send('PUT', path, body: body ?? const {});
  Future<Map<String, dynamic>> patch(String path, [Object? body]) => _send('PATCH', path, body: body ?? const {});
  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> upload(String path, String filePath) async {
    final form = FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
    return _send('POST', path, body: form);
  }

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    final Response res;
    try {
      res = await _dio.request(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: {if (token != null) 'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw ApiException(_networkMessage(e));
    }
    final data = res.data;
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{'data': data};
    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) return map;
    if (status == 401 && token != null) onUnauthorized?.call();
    throw ApiException(
      (map['error'] as String?) ?? 'Request failed ($status)',
      status,
    );
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server is taking too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server at $baseUrl. Check your connection or server address.';
      default:
        return e.message ?? 'Network error';
    }
  }

  /// Menu/upload image URLs may point at the admin's own host (127.0.0.1 /
  /// localhost) — rewrite those onto the configured server so they load on device.
  String image(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('/')) return '$baseUrl$url';
    final u = Uri.tryParse(url);
    if (u != null && (u.host == '127.0.0.1' || u.host == 'localhost')) {
      final b = Uri.parse(baseUrl);
      return u.replace(scheme: b.scheme, host: b.host, port: b.port).toString();
    }
    return url;
  }
}
