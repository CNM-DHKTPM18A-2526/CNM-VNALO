import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:http_parser/http_parser.dart';

class FaceAuthService {
  final String _base;

  FaceAuthService() : _base = AppConfig.instance.coreServiceUrl;

  Future<Map<String, dynamic>> _postMultipart(
    String endpoint, {
    required File file,
    required Map<String, String> fields,
  }) async {
    final uri = Uri.parse('$_base$endpoint');
    final request = http.MultipartRequest('POST', uri);

    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      file.path,
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_base$endpoint');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final uri = Uri.parse('$_base$endpoint');
    final response = await http.get(uri);
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _getWithAuth(String endpoint, String accessToken) async {
    final uri = Uri.parse('$_base$endpoint');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _postMultipartWithAuth(
    String endpoint, {
    required File file,
    required Map<String, String> fields,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_base$endpoint');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      file.path,
      contentType: MediaType('image', 'jpeg'),
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Lỗi máy chủ (${response.statusCode})';
      try {
        final body = Map<String, dynamic>.from(
          response.body.isNotEmpty ? _tryParse(response.body) : {},
        );
        message = body['message'] ?? body['error'] ?? message;
      } catch (_) {}
      throw ApiException(statusCode: response.statusCode, message: message);
    }
    try {
      return Map<String, dynamic>.from(_tryParse(response.body));
    } catch (_) {
      return {};
    }
  }

  dynamic _tryParse(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return <String, dynamic>{'errors': decoded};
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{'data': raw};
    }
  }

  /// Check if face auth service is healthy.
  Future<bool> isServiceAvailable() async {
    try {
      final data = await _get('/face/health');
      final d = data['data'] as Map<String, dynamic>? ?? data;
      return d['enabled'] == true && d['modelReady'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Check if user has enrolled a face (requires auth token).
  Future<bool> isEnrolled(String accessToken) async {
    try {
      final data = await _getWithAuth('/face/status', accessToken);
      final d = data['data'] as Map<String, dynamic>? ?? data;
      return d['enrolled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Get full enrollment status (requires auth token).
  Future<Map<String, dynamic>> getEnrollmentStatus(String accessToken) async {
    final data = await _getWithAuth('/face/status', accessToken);
    return data['data'] as Map<String, dynamic>? ?? data;
  }

  /// Enroll face for an authenticated user.
  Future<FaceEnrollResult> enrollFace(File image, String accessToken, {String? deviceInfo}) async {
    final fields = <String, String>{};
    if (deviceInfo != null) fields['deviceInfo'] = deviceInfo;
    final data = await _postMultipartWithAuth(
      '/face/enroll',
      file: image,
      fields: fields,
      accessToken: accessToken,
    );
    final d = data['data'] as Map<String, dynamic>? ?? data;
    final success = d['success'] == true;
    if (!success) {
      // Note: Backend currently returns 400 on failure, so ApiException is thrown early in _parseResponse.
      // This block acts as a fallback just in case backend returns 200 OK with success=false.
      final msg = data['message']?.toString() ?? 'Đăng ký thất bại.';
      throw ApiException(statusCode: 400, message: msg);
    }
    return FaceEnrollResult(
      enrolledAt: d['enrolledAt']?.toString(),
      version: (d['version'] as num?)?.toInt() ?? 1,
    );
  }

  /// Delete face enrollment (requires auth token).
  Future<void> deleteEnrollment(String accessToken) async {
    final uri = Uri.parse('$_base/face/enrollment');
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    _parseResponse(response);
  }

  /// Perform liveness check on a captured image.
  Future<FaceLivenessResult> checkLiveness(File image) async {
    final data = await _postMultipart(
      '/face/liveness-check',
      file: image,
      fields: {},
    );
    final d = data['data'] as Map<String, dynamic>? ?? data;
    return FaceLivenessResult(
      isLive: d['isLive'] == true || d['pass'] == true,
      score: (d['score'] as num?)?.toDouble() ?? 0.0,
      threshold: (d['threshold'] as num?)?.toDouble() ?? 0.5,
      pass: d['pass'] == true || d['isLive'] == true,
    );
  }

  /// Lookup userId by phone or email.
  Future<String> lookupUserId(String identifier) async {
    final data = await _get('/auth/lookup?identifier=${Uri.encodeComponent(identifier)}');
    final d = data['data'] as Map<String, dynamic>? ?? data;
    final userId = d['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw ApiException(statusCode: 404, message: 'Không tìm thấy tài khoản.');
    }
    return userId;
  }

  /// Verify a face image against a known userId.
  Future<FaceVerifyResult> verifyFace(File image, String userId) async {
    final fields = <String, String>{'userId': userId};
    final data = await _postMultipart('/face/verify', file: image, fields: fields);
    final d = data['data'] as Map<String, dynamic>? ?? data;
    return FaceVerifyResult(
      verified: d['verified'] == true,
      confidence: (d['confidence'] as num?)?.toDouble(),
      threshold: (d['threshold'] as num?)?.toDouble(),
      decision: d['decision']?.toString(),
      verificationToken: d['verificationToken']?.toString(),
    );
  }

  /// Create a session after face verification succeeded.
  Future<FaceLoginResult> faceLogin({
    required String verificationToken,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final data = await _postJson('/auth/face-login', {
      'verificationToken': verificationToken,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
    });
    final d = data['data'] as Map<String, dynamic>? ?? data;
    final accessToken = d['accessToken']?.toString();
    final refreshToken = d['refreshToken']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw ApiException(statusCode: 500, message: 'Máy chủ không trả về token đăng nhập.');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw ApiException(statusCode: 500, message: 'Máy chủ không trả về refresh token.');
    }
    return FaceLoginResult(accessToken: accessToken, refreshToken: refreshToken);
  }
}

class FaceLivenessResult {
  final bool isLive;
  final double score;
  final double threshold;
  final bool pass;
  FaceLivenessResult({
    required this.isLive,
    required this.score,
    required this.threshold,
    required this.pass,
  });
}

class FaceVerifyResult {
  final bool verified;
  final double? confidence;
  final double? threshold;
  final String? decision;
  final String? verificationToken;
  FaceVerifyResult({
    required this.verified,
    this.confidence,
    this.threshold,
    this.decision,
    this.verificationToken,
  });
}

class FaceLoginResult {
  final String accessToken;
  final String refreshToken;
  FaceLoginResult({required this.accessToken, required this.refreshToken});
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  ApiException({required this.statusCode, required this.message, this.code});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class FaceEnrollResult {
  final String? enrolledAt;
  final int version;
  FaceEnrollResult({this.enrolledAt, required this.version});
}
