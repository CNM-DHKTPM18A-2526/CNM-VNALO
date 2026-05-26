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
      body: body.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}').join('&'),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final uri = Uri.parse('$_base$endpoint');
    final response = await http.get(uri);
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
    if (raw.trim().isEmpty) return {};
    return (raw.startsWith('{') || raw.startsWith('['))
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : {'data': raw};
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
      final uri = Uri.parse('$_base/face/status');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      final data = Map<String, dynamic>.from(_tryParse(response.body));
      final d = data['data'] as Map<String, dynamic>? ?? data;
      return d['enrolled'] == true;
    } catch (_) {
      return false;
    }
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

  /// Verify a face image against a known userId.
  Future<FaceVerifyResult> verifyFace(File image, String userId, {double? livenessScore}) async {
    final fields = <String, String>{'userId': userId};
    if (livenessScore != null) {
      fields['livenessScore'] = livenessScore.toString();
    }
    final data = await _postMultipart('/face/verify', file: image, fields: fields);
    final d = data['data'] as Map<String, dynamic>? ?? data;
    return FaceVerifyResult(
      verified: d['verified'] == true,
      confidence: (d['confidence'] as num?)?.toDouble(),
      threshold: (d['threshold'] as num?)?.toDouble(),
      decision: d['decision']?.toString(),
    );
  }

  /// Create a session after face verification succeeded.
  Future<FaceLoginResult> faceLogin({
    required String userId,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final data = await _postJson('/auth/face-login', {
      'userId': userId,
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
  FaceVerifyResult({
    required this.verified,
    this.confidence,
    this.threshold,
    this.decision,
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
  ApiException({required this.statusCode, required this.message});
  @override
  String toString() => 'ApiException($statusCode): $message';
}
