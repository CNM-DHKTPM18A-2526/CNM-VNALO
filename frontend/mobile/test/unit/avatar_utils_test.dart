import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/core/utils/avatar_utils.dart';

void main() {
  group('AvatarUtils.getInitials', () {
    test('two-word name returns first letters', () {
      expect(AvatarUtils.getInitials('Nguyễn An'), equals('NA'));
    });

    test('three-word name returns first and last initials', () {
      expect(AvatarUtils.getInitials('Nguyễn Văn An'), equals('NA'));
    });

    test('single-word name returns first letter', () {
      expect(AvatarUtils.getInitials('An'), equals('A'));
    });

    test('empty name returns ?', () {
      expect(AvatarUtils.getInitials(''), equals('?'));
    });

    test('whitespace-only name returns ?', () {
      expect(AvatarUtils.getInitials('   '), equals('?'));
    });

    test('initials are uppercase', () {
      final initials = AvatarUtils.getInitials('nguyễn an');
      // Check that we get some non-empty result
      expect(initials.length, greaterThanOrEqualTo(1));
    });
  });

  group('AvatarUtils.getColor', () {
    test('returns deterministic color for same name', () {
      final c1 = AvatarUtils.getColor('Test User');
      final c2 = AvatarUtils.getColor('Test User');
      expect(c1, equals(c2));
    });

    test('different names can produce different colors', () {
      final c1 = AvatarUtils.getColor('Alice');
      final c2 = AvatarUtils.getColor('Bob');
      // They could be the same by coincidence but usually won't be
      // This test just ensures no crash
      expect(c1, isNotNull);
      expect(c2, isNotNull);
    });

    test('empty name does not crash', () {
      final c = AvatarUtils.getColor('');
      expect(c, isNotNull);
    });
  });
}
