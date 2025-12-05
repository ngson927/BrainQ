import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiHelper {
  static const String _authTokenKey = 'token';
  static const String _userIdKey = 'userId';

  /// Returns the proper base URL depending on platform
  static String get baseUrl {
    if (kIsWeb) return ApiConfig.webBaseUrl;
    if (Platform.isAndroid) return ApiConfig.androidEmulatorBaseUrl;
    return ApiConfig.localBaseUrl; // iOS simulator or desktop
  }

  static Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final fullUrl = baseUrl.endsWith('/')
        ? '$baseUrl$normalizedPath'
        : '$baseUrl/$normalizedPath';
    return Uri.parse(fullUrl);
  }

  /// Generic request handler with error handling
  static Future<http.Response> _handleRequest(
    Future<http.Response> Function() request,
    String path, {
    String method = 'GET',
  }) async {
    try {
      final response = await request();

      if (kDebugMode) {
        debugPrint('[$method] ${_buildUri(path)} → ${response.statusCode}');
        debugPrint('Response: ${response.body}');
      }

      return response;
    } on SocketException {
      throw Exception('No Internet connection');
    } on HttpException {
      throw Exception('Failed to connect to server');
    } on FormatException {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // ------------------------
  // HTTP Methods
  // ------------------------
  static Future<http.Response> get(String path, {Map<String, String>? headers}) =>
      _handleRequest(() => http.get(_buildUri(path), headers: headers), path, method: 'GET');

  static Future<http.Response> post(String path, {Map<String, String>? headers, Object? body}) =>
      _handleRequest(() => http.post(_buildUri(path), headers: headers, body: body), path, method: 'POST');

  static Future<http.Response> put(String path, {Map<String, String>? headers, Object? body}) =>
      _handleRequest(() => http.put(_buildUri(path), headers: headers, body: body), path, method: 'PUT');

  static Future<http.Response> patch(String path, {Map<String, String>? headers, Object? body}) =>
      _handleRequest(() => http.patch(_buildUri(path), headers: headers, body: body), path, method: 'PATCH');

  static Future<http.Response> delete(String path, {Map<String, String>? headers}) =>
      _handleRequest(() => http.delete(_buildUri(path), headers: headers), path, method: 'DELETE');

  // ------------------------
  // Auth Token / User ID Helpers
  // ------------------------
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
  }

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }
}
