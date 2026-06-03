import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';

void main() {
  group('AppConfig dev URL derivation', () {
    test('routes dev services through CORE_SERVICE_URL gateway by default', () {
      AppConfig.initialize(
        Environment.dev,
        coreServiceUrl: 'http://192.168.1.88:8081/api/v1',
      );

      expect(
        AppConfig.instance.coreServiceUrl,
        'http://192.168.1.88:8081/api/v1',
      );
      expect(
        AppConfig.instance.mediaServiceUrl,
        'http://192.168.1.88:8081/api/v1',
      );
      expect(
        AppConfig.instance.messageServiceUrl,
        'http://192.168.1.88:8081/api/v1',
      );
      expect(AppConfig.instance.socketUrl, 'http://192.168.1.88:8081');
      expect(
        AppConfig.instance.aiServiceUrl,
        'http://192.168.1.88:8094/api/v1',
      );
    });

    test('respects explicit overrides when provided', () {
      AppConfig.initialize(
        Environment.dev,
        coreServiceUrl: 'http://192.168.1.88:8081/api/v1',
        mediaServiceUrl: 'http://custom-media:9000/api/v1',
        messageServiceUrl: 'http://custom-msg:9001/api/v1',
        socketUrl: 'http://custom-msg:9001',
        aiServiceUrl: 'http://custom-ai:9002/api/v1',
      );

      expect(
        AppConfig.instance.mediaServiceUrl,
        'http://custom-media:9000/api/v1',
      );
      expect(
        AppConfig.instance.messageServiceUrl,
        'http://custom-msg:9001/api/v1',
      );
      expect(AppConfig.instance.socketUrl, 'http://custom-msg:9001');
      expect(AppConfig.instance.aiServiceUrl, 'http://custom-ai:9002/api/v1');
    });

    test('flags emulator and loopback hosts as local-only', () {
      expect(
        AppConfig.isLikelyLocalOnlyHost('http://10.0.2.2:8081/api/v1'),
        isTrue,
      );
      expect(
        AppConfig.isLikelyLocalOnlyHost('http://localhost:8081/api/v1'),
        isTrue,
      );
      expect(
        AppConfig.isLikelyLocalOnlyHost('http://127.0.0.1:8081/api/v1'),
        isTrue,
      );
      expect(
        AppConfig.isLikelyLocalOnlyHost('http://192.168.1.88:8081/api/v1'),
        isFalse,
      );
    });
  });
}
