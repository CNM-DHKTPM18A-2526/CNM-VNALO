import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/auth_service.dart';

void main() {
  setUpAll(() {
    AppConfig.initialize(
      Environment.dev,
      coreServiceUrl: 'http://10.0.2.2:8081/api/v1',
      mediaServiceUrl: 'http://10.0.2.2:8083/api/v1',
    );
  });

  group('User.copyWith', () {
    test('copies avatarUrl while preserving other fields', () {
      final original = User(
        id: 'u1',
        phone: '+84123456789',
        displayName: 'Test User',
        avatarUrl: 'https://old.png',
        bio: 'hello',
        isVerified: true,
      );

      final updated = original.copyWith(avatarUrl: 'https://new.png');

      expect(updated.id, equals('u1'));
      expect(updated.phone, equals('+84123456789'));
      expect(updated.displayName, equals('Test User'));
      expect(updated.avatarUrl, equals('https://new.png'));
      expect(updated.bio, equals('hello'));
      expect(updated.isVerified, isTrue);
    });

    test('copyWith with no arguments returns identical values', () {
      final original = User(
        id: 'u2',
        displayName: 'Same',
        avatarUrl: 'https://avatar.png',
      );

      final copy = original.copyWith();

      expect(copy.id, equals(original.id));
      expect(copy.displayName, equals(original.displayName));
      expect(copy.avatarUrl, equals(original.avatarUrl));
    });
  });

  group('AuthService.parseUploadedMediaUrl', () {
    test('extracts url from wrapped data', () {
      final url = AuthService.parseUploadedMediaUrl({
        'data': {'url': 'https://cdn.example.com/avatar.jpg'},
      });
      expect(url, equals('https://cdn.example.com/avatar.jpg'));
    });

    test('returns null when data wrapper is missing', () {
      final url = AuthService.parseUploadedMediaUrl({'url': 'x'});
      expect(url, isNull);
    });

    test('falls back to fileUrl key', () {
      final url = AuthService.parseUploadedMediaUrl({
        'data': {'fileUrl': 'https://cdn.example.com/f.png'},
      });
      expect(url, equals('https://cdn.example.com/f.png'));
    });
  });
}
