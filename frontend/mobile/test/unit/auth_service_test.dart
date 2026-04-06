import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/auth_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';

// ---------------------------------------------------------------------------
// Minimal stub — captures calls and returns pre-configured payloads.
// ---------------------------------------------------------------------------
class _StubApi extends ApiService {
  _StubApi({
    Map<String, Map<String, dynamic>> getPayloads = const {},
    Map<String, Map<String, dynamic>> postPayloads = const {},
  })  : _getPayloads = getPayloads,
        _postPayloads = postPayloads,
        super(StorageService());

  final Map<String, Map<String, dynamic>> _getPayloads;
  final Map<String, Map<String, dynamic>> _postPayloads;

  String? lastGetEndpoint;
  String? lastPostEndpoint;
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Map<String, dynamic>> get(
    String baseUrl,
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    lastGetEndpoint = endpoint;
    return _getPayloads[endpoint] ?? {};
  }

  @override
  Future<Map<String, dynamic>> post(
    String baseUrl,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    lastPostEndpoint = endpoint;
    lastPostBody = body;
    if (_postPayloads.containsKey(endpoint)) return _postPayloads[endpoint]!;
    throw ApiException(statusCode: 500, message: 'Unexpected call to $endpoint');
  }
}

void main() {
  setUpAll(() {
    AppConfig.initialize(Environment.dev);
  });

  // ── getOtpStatus ─────────────────────────────────────────────────────────

  group('AuthService.getOtpStatus()', () {
    test('parses wrapped {data:{enabled:true}} correctly', () async {
      final api = _StubApi(getPayloads: {
        '/auth/otp/status': {'data': {'enabled': true}},
      });
      final result = await AuthService(api).getOtpStatus();
      expect(result['enabled'], isTrue);
    });

    test('[C2] handles flat {enabled:false} response without data wrapper',
        () async {
      final api = _StubApi(getPayloads: {
        '/auth/otp/status': {'enabled': false},
      });
      final result = await AuthService(api).getOtpStatus();
      // Before fix this returned null causing NPE at caller site.
      expect(result, isNotNull);
      expect(result['enabled'], isFalse);
    });

    test('[C2] flat response preserves extra fields', () async {
      final api = _StubApi(getPayloads: {
        '/auth/otp/status': {'enabled': true, 'provider': 'twilio'},
      });
      final result = await AuthService(api).getOtpStatus();
      expect(result['provider'], 'twilio');
    });
  });

  // ── _normalizePhone (via sendOtp — captured from postBody) ───────────────

  group('AuthService._normalizePhone() via sendOtp()', () {
    _StubApi buildApi() => _StubApi(postPayloads: {
          '/auth/register/send-otp': {'success': true},
        });

    test('[M3] already-qualified +84 number is not re-prefixed', () async {
      final api = buildApi();
      await AuthService(api).sendOtp('+84987654321');
      expect(api.lastPostBody!['phone'], '+84987654321');
    });

    test('[M3] 0xxx number is normalised to +84xxx', () async {
      final api = buildApi();
      await AuthService(api).sendOtp('0987654321');
      expect(api.lastPostBody!['phone'], '+84987654321');
    });

    test('[M3] +1 US number is passed through unchanged', () async {
      final api = buildApi();
      await AuthService(api).sendOtp('+12025551234');
      expect(api.lastPostBody!['phone'], '+12025551234');
    });
  });

  group('AuthService.parseUploadedMediaUrl()', () {
    test('reads url from standard media-service payload', () {
      final u = AuthService.parseUploadedMediaUrl({
        'data': {
          'url': 'https://cdn.example.com/a.jpg',
          'mediaId': 'x',
        },
      });
      expect(u, 'https://cdn.example.com/a.jpg');
    });

    test('falls back to alternate keys used by some gateways', () {
      expect(
        AuthService.parseUploadedMediaUrl({
          'data': {'fileUrl': 'https://x/f.png'},
        }),
        'https://x/f.png',
      );
    });

    test('returns null when data wrapper missing', () {
      expect(AuthService.parseUploadedMediaUrl({'url': 'x'}), isNull);
    });
  });

  // ── login body ───────────────────────────────────────────────────────────

  group('AuthService.login()', () {
    test('[M4] sends only identifier, drops redundant phone field', () async {
      final api = _StubApi(postPayloads: {
        '/auth/login': {'accessToken': 'at', 'refreshToken': 'rt'},
      });
      await AuthService(api).login(phone: '+84987654321', password: 'secret');
      final body = api.lastPostBody!;
      expect(body['identifier'], isNotNull);
      expect(body.containsKey('phone'), isFalse,
          reason: 'Redundant phone key must be absent after M4 fix');
    });
  });
}
