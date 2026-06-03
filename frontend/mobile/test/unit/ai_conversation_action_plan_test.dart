import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_conversation_action_plan.dart';
import 'package:vnalo_mobile/models/user_model.dart';

void main() {
  group('AiCreateGroupActionPlan', () {
    test('extracts group name and members from params', () {
      final plan = AiCreateGroupActionPlan.fromParams({
        'groupName': 'Nhóm dự án',
        'members': ['An', 'Bình'],
      });

      expect(plan.groupName, 'Nhóm dự án');
      expect(plan.memberNames, ['An', 'Bình']);
      expect(plan.isValid, isTrue);
    });

    test('marks missing group payload as invalid', () {
      final plan = AiCreateGroupActionPlan.fromParams(null);

      expect(plan.isValid, isFalse);
      expect(plan.invalidMessage, contains('ít nhất một thành viên'));
    });

    test('builds selected member detail from users', () {
      final plan = AiCreateGroupActionPlan.fromParams({
        'groupName': 'Nhóm đi ăn',
        'members': ['An'],
      });

      final detail = plan.selectedMemberDetail([
        User(id: '1', displayName: 'An'),
        User(id: '2', displayName: 'Bình'),
      ]);

      expect(detail, 'An, Bình');
      expect(plan.successMessage, 'Đã tạo nhóm "Nhóm đi ăn".');
    });
  });

  group('AiMuteConversationActionPlan', () {
    test('builds mute copy', () {
      final plan = AiMuteConversationActionPlan(muted: true);

      expect(plan.icon, Icons.notifications_off_rounded);
      expect(plan.confirmLabel, 'Tắt thông báo');
      expect(plan.cancelMessage, 'Đã hủy thao tác tắt thông báo.');
    });

    test('builds unmute copy', () {
      final plan = AiMuteConversationActionPlan(muted: false);

      expect(plan.icon, Icons.notifications_rounded);
      expect(plan.successMessage, 'Đã bật thông báo.');
    });
  });

  group('AiPinMessageActionPlan', () {
    test('builds pin copy', () {
      final plan = AiPinMessageActionPlan(pin: true);

      expect(plan.icon, Icons.push_pin_rounded);
      expect(plan.confirmLabel, 'Ghim');
      expect(plan.cancelMessage, 'Đã hủy thao tác ghim tin nhắn.');
    });

    test('builds unpin copy', () {
      final plan = AiPinMessageActionPlan(pin: false);

      expect(plan.icon, Icons.push_pin_outlined);
      expect(plan.confirmLabel, 'Bỏ ghim');
      expect(plan.missingMessage, contains('tin nhắn phù hợp'));
    });
  });
}
