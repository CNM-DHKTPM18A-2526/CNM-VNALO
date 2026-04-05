import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:vnalo_mobile/services/storage_service.dart';

class ApiService {
  final StorageService _storageService;
  static const _timeout = Duration(seconds: 20);

  ApiService(this._storageService);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(
    String baseUrl,
    String endpoint, {
    Map<String, String>? queryParams,
  }) {
    return _request('GET', baseUrl, endpoint, queryParams: queryParams);
  }

  Future<Map<String, dynamic>> post(
    String baseUrl,
    String endpoint, {
    Map<String, dynamic>? body,
  }) {
    return _request('POST', baseUrl, endpoint, body: body);
  }

  Future<Map<String, dynamic>> patch(
    String baseUrl,
    String endpoint, {
    Map<String, dynamic>? body,
  }) {
    return _request('PATCH', baseUrl, endpoint, body: body);
  }

  Future<Map<String, dynamic>> postMultipart(
    String baseUrl,
    String endpoint, {
    required File file,
    String fileField = 'file',
    Map<String, String>? fields,
  }) async {
    final url = Uri.parse(_normalizeUrl(baseUrl, endpoint));
    final token = await _storageService.getAccessToken();

    final request = http.MultipartRequest('POST', url)
      ..fields.addAll(fields ?? <String, String>{})
      ..files.add(await http.MultipartFile.fromPath(fileField, file.path));

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Request timed out');
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No Internet connection');
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Unexpected error: $e');
    }

    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String baseUrl, String endpoint) {
    return _request('DELETE', baseUrl, endpoint);
  }

  // Internal method to handle all HTTP requests with error handling and response parsing
  Future<Map<String, dynamic>> _request(
    String method,
    String baseUrl,
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    bool allowRefresh = true,
  }) async {
    // Normalize URL and prepare headers and body for the request
    final url = Uri.parse(
      _normalizeUrl(baseUrl, endpoint),
    ).replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    final encodedBody = body == null ? null : jsonEncode(body);
    http.Response response;

    // Execute the HTTP request with appropriate method
    //and handle exceptions for network issues, timeouts, and unexpected errors
    try {
      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response = await http
              .post(url, headers: headers, body: encodedBody)
              .timeout(_timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(url, headers: headers, body: encodedBody)
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers).timeout(_timeout);
          break;
        default:
          throw ApiException(
            statusCode: 0,
            message: 'Unsupported HTTP method: $method',
          );
      }
    } on SocketException {
      // Handle no internet connection
      throw ApiException(statusCode: 0, message: 'No Internet connection');
    } on http.ClientException catch (e) {
      throw ApiException(statusCode: 0, message: 'Client error: ${e.message}');
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Request timed out');
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Unexpected error: $e');
    }
    if (response.statusCode == 401 && allowRefresh && endpoint != '/auth/refresh') {
      final refreshed = await _tryRefreshToken(baseUrl);
      if (refreshed) {
        return _request(
          method,
          baseUrl,
          endpoint,
          queryParams: queryParams,
          body: body,
          allowRefresh: false,
        );
      }
    }

    return _handleResponse(response);
  }

  Future<bool> _tryRefreshToken(String baseUrl) async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final url = Uri.parse(_normalizeUrl(baseUrl, '/auth/refresh'));
    final payload = jsonEncode({'refreshToken': refreshToken});

    try {
      final response = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final parsed = _parseResponseBody(response.body);
      final data = (parsed['data'] ?? parsed) as Map<String, dynamic>;
      final access = data['accessToken'] ?? data['access_token'];
      final refresh = data['refreshToken'] ?? data['refresh_token'];

      if (access is! String || refresh is! String) {
        return false;
      }

      await _storageService.saveTokens(
        accessToken: access,
        refreshToken: refresh,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // Normalize URL by ensuring there is exactly one slash between baseUrl and endpoint
  String _normalizeUrl(String baseUrl, String endpoint) {
    if (baseUrl.endsWith('/') && endpoint.startsWith('/')) {
      return baseUrl + endpoint.substring(1);
    } else if (!baseUrl.endsWith('/') && !endpoint.startsWith('/')) {
      return '$baseUrl/$endpoint';
    }
    return baseUrl + endpoint;
  }

  // Handle HTTP response, throwing exceptions for error status codes and parsing JSON body
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = _parseResponseBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    if (response.statusCode == 401) {
      throw UnauthorizedException(body['message'] ?? 'Unauthorized');
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['message'] ?? 'Unknown error',
      code: body['code'],
    );
  }

  // Parse response body, handling empty responses and non-JSON content gracefully
  Map<String, dynamic> _parseResponseBody(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      // Keep method return type stable for list/primitive payloads.
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{'raw': rawBody};
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  ApiException({required this.statusCode, required this.message, this.code});

  @override
  String toString() => 'ApiException($statusCode): $message (code: $code)';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message)
    : super(statusCode: 401, message: message);
}
