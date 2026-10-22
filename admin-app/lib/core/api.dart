import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// JSON client for the `api` Cloud Function (/api/admin/*).
/// Same origin on Firebase Hosting; override with --dart-define=API_BASE=https://… for local dev.
class Api {
  static const base = String.fromEnvironment('API_BASE', defaultValue: '');

  static Uri uri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/api') ? path : '/api/admin$path';
    return Uri.parse('$base$p').replace(queryParameters: query);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  static Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  static Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  static Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);
  static Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Throws [ApiError] with the server's message: `error` || first validation error || "Request failed (status)".
  static Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final req = http.Request(method, uri(path, query))..headers.addAll(await _headers());
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await http.Client().send(req));
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      var msg = 'Request failed (${res.statusCode})';
      if (data is Map) {
        if (data['error'] is String) {
          msg = data['error'];
        } else if (data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
          final first = (data['errors'] as Map).values.first;
          msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
        } else if (data['message'] is String) {
          msg = data['message'];
        }
      }
      throw ApiError(res.statusCode, msg);
    }
    return data;
  }

  /// Multipart upload to POST /api/upload → returns the public image URL.
  static Future<String> upload(List<int> bytes, String filename, String mime) async {
    final req = http.MultipartRequest('POST', uri('/api/upload'));
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _mediaType(mime)));
    final res = await http.Response.fromStream(await req.send());
    final data = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, data is Map && data['error'] is String ? data['error'] : 'Upload failed');
    }
    return data['url'] as String;
  }

  static MediaType? _mediaType(String mime) {
    try {
      return MediaType.parse(mime);
    } catch (_) {
      return null;
    }
  }
}

class ApiError implements Exception {
  ApiError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}
