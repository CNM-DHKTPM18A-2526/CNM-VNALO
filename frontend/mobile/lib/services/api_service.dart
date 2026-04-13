import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/services/auth_events.dart';
import 'package:vnalo_mobile/services/storage_service.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  final StorageService _storageService;
  static const _timeout = Duration(seconds: 30);

  /// Uploads (S3 via media-service) often need more than JSON calls on cellular/Wi‑Fi.
  static const _multipartTimeout = Duration(seconds: 90);

  /// Coalesces concurrent 401 recoveries so refresh-token rotation does not
  /// revoke the session for parallel callers (classic multi-tab / burst API).
  Future<bool>? _refreshInFlight;

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
    bool allowRefresh = true,
  }) async {
    return _postMultipartOnce(
      baseUrl,
      endpoint,
      file: file,
      fileField: fileField,
      fields: fields,
      allowRefresh: allowRefresh,
    );
  }

  Future<Map<String, dynamic>> _postMultipartOnce(
    String baseUrl,
    String endpoint, {
    required File file,
    String fileField = 'file',
    Map<String, String>? fields,
    required bool allowRefresh,
  }) async {
    final url = Uri.parse(_normalizeUrl(baseUrl, endpoint));
    final token = await _storageService.getAccessToken();

    final request = http.MultipartRequest('POST', url)
      ..fields.addAll(fields ?? <String, String>{})
      ..files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path,
          contentType: _detectMediaType(file.path),
        ),
      );

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      response = await _sendMultipartWithDeadline(request);
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Request timed out');
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'No Internet connection');
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Unexpected error: $e');
    }

    if (response.statusCode == 401 &&
        allowRefresh &&
        endpoint != '/auth/refresh') {
      final refreshed = await _tryRefreshToken(baseUrl);
      if (refreshed) {
        return _postMultipartOnce(
          baseUrl,
          endpoint,
          file: file,
          fileField: fileField,
          fields: fields,
          allowRefresh: false,
        );
      }
    }
    return _handleResponse(response);
  }

  /// One wall-clock budget for TLS + upload + response headers/body (S3 proxy).
  Future<http.Response> _sendMultipartWithDeadline(
    http.MultipartRequest request,
  ) async {
    return () async {
          final streamed = await request.send();
          return http.Response.fromStream(streamed);
        }()
        .timeout(_multipartTimeout);
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

  Future<bool> _tryRefreshToken(String ignoredBaseUrl) {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    final future = _performRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<bool> _performRefresh() async {
    // Always refresh against core-service (never the host that returned 401).
    final coreBase = AppConfig.instance.coreServiceUrl;
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final url = Uri.parse(_normalizeUrl(coreBase, '/auth/refresh'));
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
        await _maybeClearSessionOnAuthFailure(response);
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

  /// If the refresh endpoint rejects the token, clear local credentials so
  /// the app does not keep retrying with a permanently revoked refresh token.
  Future<void> _maybeClearSessionOnAuthFailure(http.Response response) async {
    final code = _parseResponseBody(response.body)['code']?.toString();
    final fatal = response.statusCode == 401 ||
        response.statusCode == 403 ||
        code == 'AUTH_006' ||
        code == 'AUTH_007';
    if (fatal) {
      await _storageService.clearAll();
      await AuthEvents.onSessionInvalidated?.call();
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

    // Extract error message from multiple possible response formats
    final message = body['message']
        ?? body['error']
        ?? body['detail']
        ?? body['error_description']
        ?? 'Lỗi máy chủ (${response.statusCode})';

    throw ApiException(
      statusCode: response.statusCode,
      message: message.toString(),
      code: body['code']?.toString(),
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
  /// Detect MIME type from file extension to ensure backend accepts the upload.
  static MediaType _detectMediaType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'webm':
        return MediaType('video', 'webm');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'mp3':
        return MediaType('audio', 'mpeg');
      case 'ogg':
        return MediaType('audio', 'ogg');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        // Default to image/jpeg for image-picker temp files with no extension
        return MediaType('image', 'jpeg');
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
