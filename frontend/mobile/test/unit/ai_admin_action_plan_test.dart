import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_admin_action_plan.dart';
import 'package:vnalo_mobile/models/user_model.dart';

void main() {
  group('AiContactActionPlan', () {
    final user = User(id: 'u1', displayName: 'Lý Tinh Vân');

    test('builds friend request feedback', () {
      final plan = AiContactActionPlan.forCommand(
        'SEND_FRIEND_REQUEST',
        user,
      );

      expect(plan.cancelMessage, 'Đã hủy thao tác liên hệ.');
      expect(plan.successMessage, 'Đã gửi lời mời kết bạn.');
    });

    test('includes target name for block feedback', () {
      final plan = AiContactActionPlan.forCommand('BLOCK_USER', user);

      expect(plan.successMessage, 'Đã chặn Lý Tinh Vân.');
    });
  });

  group('AiGroupAdminActionPlan', () {
    test('uses new title as secondary detail for rename', () {
      final plan = AiGroupAdminActionPlan.fromParams({
        'newTitle': 'Nhóm dự án',
      });

      expect(plan.newTitle, 'Nhóm dự án');
      expect(plan.secondaryDetail, 'Nhóm dự án');
      expect(plan.secondaryDetailLabel, 'Tên mới');
    });

    test('uses member list as secondary detail for member actions', () {
      final plan = AiGroupAdminActionPlan.fromParams({
        'members': ['An', 'Bình'],
      });

      expect(plan.memberNames, ['An', 'Bình']);
      expect(plan.secondaryDetail, 'An, Bình');
      expect(plan.secondaryDetailLabel, 'Thành viên');
    });

    test('rejects missing rename title before executing', () {
      final plan = AiGroupAdminActionPlan.fromParams(null);

      expect(
        () => plan.validateBeforeExecute('CHANGE_GROUP_NAME'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects missing member list before member actions', () {
      final plan = AiGroupAdminActionPlan.fromParams(null);

      expect(
        () => plan.validateBeforeExecute('ADD_GROUP_MEMBER'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => plan.validateBeforeExecute('REMOVE_GROUP_MEMBER'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => plan.validateBeforeExecute('TRANSFER_GROUP_OWNER'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
