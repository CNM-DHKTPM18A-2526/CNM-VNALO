import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_action_target_matcher.dart';
import 'package:vnalo_mobile/models/user_model.dart';

User _user({
  required String id,
  required String displayName,
  String? phone,
  String? email,
}) {
  return User(
    id: id,
    displayName: displayName,
    phone: phone,
    email: email,
  );
}

void main() {
  group('AiActionTargetMatcher.findUsersByName', () {
    test('prefers exact matches over looser candidates', () {
      final users = [
        _user(id: '1', displayName: 'Lý Vân'),
        _user(id: '2', displayName: 'Lý Tinh Vân'),
        _user(id: '3', displayName: 'Nguyễn Lý Tinh Vân'),
      ];

      final matches = AiActionTargetMatcher.findUsersByName(users, 'ly van');

      expect(matches.map((user) => user.id).toList(), ['1']);
    });

    test('matches by phone or email when display name is not enough', () {
      final users = [
        _user(id: '1', displayName: 'An', phone: '0909123456'),
        _user(id: '2', displayName: 'Bình', email: 'lyvan@example.com'),
      ];

      final phoneMatches = AiActionTargetMatcher.findUsersByName(
        users,
        '0909123456',
      );
      final emailMatches = AiActionTargetMatcher.findUsersByName(
        users,
        'lyvan@example.com',
      );

      expect(phoneMatches.single.id, '1');
      expect(emailMatches.single.id, '2');
    });

    test('deduplicates repeated labels for the same user', () {
      final users = [
        _user(
          id: '1',
          displayName: 'Uyên Lý',
          email: 'uyen.ly@example.com',
        ),
      ];

      final matches = AiActionTargetMatcher.findUsersByName(
        users,
        'uyen ly',
      );

      expect(matches, hasLength(1));
      expect(matches.single.id, '1');
    });
  });
}
