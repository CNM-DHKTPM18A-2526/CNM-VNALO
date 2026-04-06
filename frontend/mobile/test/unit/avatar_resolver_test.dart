import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';

void main() {
  setUpAll(() {
    // Initialize AppConfig for URL resolution tests.
    AppConfig.initialize(
      Environment.dev,
      coreServiceUrl: 'http://10.0.2.2:8081/api/v1',
      mediaServiceUrl: 'http://10.0.2.2:8083/api/v1',
    );
  });

  group('AvatarResolver.resolveUrl', () {
    test('null input returns null', () {
      expect(AvatarResolver.resolveUrl(null), isNull);
    });

    test('empty string returns null', () {
      expect(AvatarResolver.resolveUrl(''), isNull);
    });

    test('whitespace-only returns null', () {
      expect(AvatarResolver.resolveUrl('   '), isNull);
    });

    test('absolute http URL passthrough', () {
      const url = 'http://example.com/avatar.jpg';
      expect(AvatarResolver.resolveUrl(url), equals(url));
    });

    test('absolute https URL passthrough', () {
      const url = 'https://cdn.vnalo.com/media/abc.jpg';
      expect(AvatarResolver.resolveUrl(url), equals(url));
    });

    test('DiceBear URL (has scheme) passthrough', () {
      const url =
          'https://api.dicebear.com/9.x/initials/svg?seed=abc&radius=50';
      expect(AvatarResolver.resolveUrl(url), equals(url));
    });

    test('relative path gets media host prepended', () {
      final resolved = AvatarResolver.resolveUrl('/media/avatar/abc.jpg');
      expect(resolved, isNotNull);
      expect(resolved, contains('10.0.2.2'));
      expect(resolved, contains('/media/avatar/abc.jpg'));
    });

    test('relative path without leading slash gets slash prepended', () {
      final resolved = AvatarResolver.resolveUrl('media/avatar/abc.jpg');
      expect(resolved, isNotNull);
      expect(resolved, contains('/media/avatar/abc.jpg'));
    });

    test('preserves existing scheme', () {
      const url = 'https://s3.amazonaws.com/bucket/key.png';
      expect(AvatarResolver.resolveUrl(url), equals(url));
    });
  });
}
