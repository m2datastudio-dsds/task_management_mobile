import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  static const _requestTimeout = Duration(seconds: 15);

  String baseUrl = AppConfig.apiBaseUrl;

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'The server took too long to respond. Check that the backend is running and that this device can reach $baseUrl.',
        0,
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot connect to the server at $baseUrl. Check that the backend is running and that the phone and computer are on the same Wi-Fi.',
        0,
      );
    }
  }

  Future<Map<String, String>> _headers({bool jsonBody = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String endpoint, [Map<String, dynamic>? params]) {
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanEndpoint = endpoint.replaceAll(RegExp(r'^/+'), '');
    final uri = Uri.parse('$cleanBase/$cleanEndpoint');
    if (params == null || params.isEmpty) return uri;
    return uri.replace(
      queryParameters: params.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<dynamic> get(String endpoint, {Map<String, dynamic>? params}) async {
    final res = await _guard(
      () async => http.get(
        _uri(endpoint, params),
        headers: await _headers(jsonBody: false),
      ),
    );
    return _decode(res);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final res = await _guard(
      () async => http.post(
        _uri(endpoint),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final res = await _guard(
      () async => http.put(
        _uri(endpoint),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  Future<dynamic> uploadFile(
    String method,
    String endpoint, {
    required String fieldName,
    String? filePath,
    Uint8List? bytes,
    String? filename,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest(method, _uri(endpoint));
    request.headers.addAll(await _headers(jsonBody: false));
    if (fields != null) request.fields.addAll(fields);

    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename ?? 'upload.jpg',
        ),
      );
    } else if (filePath != null && filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    } else if (fields == null || fields.isEmpty) {
      throw ApiException('Image file is required', 400);
    }

    final streamed = await _guard(request.send);
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final res = await _guard(
      () async => http.delete(
        _uri(endpoint),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final text = res.body;
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } on FormatException {
        final contentType = res.headers['content-type'] ?? '';
        throw ApiException(
          contentType.contains('text/html') || text.trimLeft().startsWith('<')
              ? 'The server does not support this request yet. Please update the server and try again.'
              : 'The server returned an invalid response. Please try again.',
          res.statusCode,
        );
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final message = data is Map<String, dynamic>
        ? (data['message'] ?? data['error'] ?? 'Request failed').toString()
        : 'Request failed';
    throw ApiException(message, res.statusCode);
  }
}
