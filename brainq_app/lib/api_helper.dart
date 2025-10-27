import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiHelper {
  /// Returns the proper base URL depending on platform
  static String get baseUrl {
    if (kIsWeb) return ApiConfig.webBaseUrl;
    if (Platform.isAndroid) return ApiConfig.androidEmulatorBaseUrl;
    return ApiConfig.localBaseUrl; // iOS simulator or desktop
  }

  /// Normalize URL to avoid double slashes
  static Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final fullUrl = baseUrl.endsWith('/')
        ? '$baseUrl$normalizedPath'
        : '$baseUrl/$normalizedPath';
    return Uri.parse(fullUrl);
  }

  /// A reusable HTTP request handler with optional logging
  static Future<http.Response> _handleRequest(
    Future<http.Response> Function() request,
    String path, {
    String method = 'GET',
  }) async {
    try {
      final response = await request();

      // Debug logging (only in dev mode)
      if (kDebugMode) {
        debugPrint(
          '[$method] ${_buildUri(path)} → ${response.statusCode}\n'
          'Response: ${response.body}',
        );
      }

      return response;
    } on SocketException catch (_) {
      throw Exception('No Internet connection');
    } on HttpException catch (_) {
      throw Exception('Failed to connect to server');
    } on FormatException catch (_) {
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// GET request wrapper
  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _handleRequest(
      () => http.get(_buildUri(path), headers: headers),
      path,
      method: 'GET',
    );
  }

  /// POST request wrapper
  static Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _handleRequest(
      () => http.post(_buildUri(path), headers: headers, body: body),
      path,
      method: 'POST',
    );
  }

  /// PUT request wrapper
  static Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _handleRequest(
      () => http.put(_buildUri(path), headers: headers, body: body),
      path,
      method: 'PUT',
    );
  }

  /// PATCH request wrapper
  static Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _handleRequest(
      () => http.patch(_buildUri(path), headers: headers, body: body),
      path,
      method: 'PATCH',
    );
  }

  /// DELETE request wrapper
  static Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _handleRequest(
      () => http.delete(_buildUri(path), headers: headers),
      path,
      method: 'DELETE',
    );
  }
}
