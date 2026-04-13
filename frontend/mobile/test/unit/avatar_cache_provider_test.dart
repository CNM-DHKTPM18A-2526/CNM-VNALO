import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/profile/providers/avatar_cache_provider.dart';

void main() {
  group('AvatarCacheProvider', () {
    test('keeps version until ttl expires', () {
      var now = DateTime(2026, 1, 1, 0, 0, 0);
      final provider = AvatarCacheProvider(
        ttl: const Duration(minutes: 5),
        nowProvider: () => now,
      );

      provider.bumpUserAvatarVersion('u1');
      expect(provider.versionForUser('u1'), 1);

      now = now.add(const Duration(minutes: 4));
      expect(provider.versionForUser('u1'), 1);

      now = now.add(const Duration(minutes: 2));
      expect(provider.versionForUser('u1'), 0);
    });

    test('increments and resets after expiration', () {
      var now = DateTime(2026, 1, 1, 0, 0, 0);
      final provider = AvatarCacheProvider(
        ttl: const Duration(minutes: 1),
        nowProvider: () => now,
      );

      provider.bumpUserAvatarVersion('u1');
      provider.bumpUserAvatarVersion('u1');
      expect(provider.versionForUser('u1'), 2);

      now = now.add(const Duration(minutes: 2));
      expect(provider.versionForUser('u1'), 0);

      provider.bumpUserAvatarVersion('u1');
      expect(provider.versionForUser('u1'), 1);
    });
  });
}
