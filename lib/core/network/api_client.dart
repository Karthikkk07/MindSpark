import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  /// Override with: flutter run --dart-define=API_BASE_URL=https://...
  /// 10.0.2.2 is how the Android emulator reaches the PC running the API.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );
}

class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.status});

  final String code;
  final String message;
  final int? status;

  bool get isUnauthorized => status == 401;
  bool get isNetworkError => code == 'network';

  @override
  String toString() => 'ApiException($code, $status): $message';
}

/// Small JSON-over-HTTP client for the MindSpark API.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> get(String path, {String? token}) =>
      _send('GET', path, token: token);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration? timeout,
  }) =>
      _send('POST', path, body: body, token: token, timeout: timeout);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      _send('PATCH', path, body: body, token: token);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      _send('PUT', path, body: body, token: token);
  Future<Map<String, dynamic>> delete(String path, {String? token}) =>
      _send('DELETE', path, token: token);
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration? timeout,
  }) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout ?? _timeout);
      response = await http.Response.fromStream(streamed);
    } on Exception {
      throw const ApiException(
        code: 'network',
        message: 'Cannot reach the server. Check your connection and try again.',
      );
    }

    Map<String, dynamic> json = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        // Not JSON (for example an error page from a proxy).
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return json;

    final error = json['error'];
    throw ApiException(
      status: response.statusCode,
      code: error is Map<String, dynamic> ? (error['code'] as String? ?? 'error') : 'error',
      message: error is Map<String, dynamic>
          ? (error['message'] as String? ?? 'Request failed')
          : 'Request failed',
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
