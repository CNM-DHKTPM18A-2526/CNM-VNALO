import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';

void main() {
  group('AppConfig dev URL derivation', () {
    test('derives media/message/socket from CORE_SERVICE_URL host', () {
      AppConfig.initialize(
        Environment.dev,
        coreServiceUrl: 'http://192.168.1.88:8081/api/v1',
      );

      expect(AppConfig.instance.coreServiceUrl, 'http://192.168.1.88:8081/api/v1');
      expect(AppConfig.instance.mediaServiceUrl, 'http://192.168.1.88:8083/api/v1');
      expect(AppConfig.instance.messageServiceUrl, 'http://192.168.1.88:3000/api/v1');
      expect(AppConfig.instance.socketUrl, 'http://192.168.1.88:3000');
    });

    test('respects explicit overrides when provided', () {
      AppConfig.initialize(
        Environment.dev,
        coreServiceUrl: 'http://192.168.1.88:8081/api/v1',
        mediaServiceUrl: 'http://custom-media:9000/api/v1',
        messageServiceUrl: 'http://custom-msg:9001/api/v1',
        socketUrl: 'http://custom-msg:9001',
      );

      expect(AppConfig.instance.mediaServiceUrl, 'http://custom-media:9000/api/v1');
      expect(AppConfig.instance.messageServiceUrl, 'http://custom-msg:9001/api/v1');
      expect(AppConfig.instance.socketUrl, 'http://custom-msg:9001');
    });
  });
}
