// lib/core/services/api_service.dart
// Central HTTP client for all remote API calls.
// Reads the JWT token from secure storage and attaches it automatically.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

/// Base URL for the Django/FastAPI backend.
/// To change this, run: flutter run --dart-define=API_BASE_URL=http://your-ip:8000
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.137.118:8000',
);

const _storage = FlutterSecureStorage();

class ApiService {
  // ── Token helpers ──────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_access', value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: 'jwt_access');
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_access');
  }

  // ── Auth header ────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = await getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Generic request helpers ────────────────────────────────────────────────

  static Future<http.Response> get(String path) async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$kBaseUrl$path'), headers: headers);
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body,
      {bool authenticated = true}) async {
    final headers = authenticated
        ? await _authHeaders()
        : {'Content-Type': 'application/json'};
    return http.post(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> patch(
      String path, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    return http.patch(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  /// Multipart POST — used for complaint image submission.
  static Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String filePath,
    String fileField = 'images',
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$kBaseUrl$path'));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    final contentType = await _contentTypeForFile(filePath);
    request.files.add(
      await http.MultipartFile.fromPath(
        fileField,
        filePath,
        contentType: contentType,
      ),
    );
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  static Future<MediaType> _contentTypeForFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.openRead(0, 16).fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    var mimeType = lookupMimeType(filePath, headerBytes: bytes);
    final extension = filePath.toLowerCase();
    mimeType ??= switch (extension) {
      String path when path.endsWith('.png') => 'image/png',
      String path when path.endsWith('.jpg') || path.endsWith('.jpeg') =>
        'image/jpeg',
      String path when path.endsWith('.webp') => 'image/webp',
      String path when path.endsWith('.mp4') => 'video/mp4',
      String path when path.endsWith('.mov') => 'video/quicktime',
      _ => 'application/octet-stream',
    };
    return MediaType.parse(mimeType);
  }

  // ── Response decoder ───────────────────────────────────────────────────────

  static dynamic decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static bool isSuccess(http.Response r) =>
      r.statusCode >= 200 && r.statusCode < 300;
}
