import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_call_action_plan.dart';

void main() {
  group('AiCallActionPlan', () {
    test('defaults to voice call when call type is missing', () {
      final plan = AiCallActionPlan.fromParams(null);

      expect(plan.isVideo, isFalse);
      expect(plan.icon, Icons.call_rounded);
      expect(plan.title, 'Xác nhận gọi thoại');
      expect(plan.analyticsCallType, 'voice');
    });

    test('builds video call presentation', () {
      final plan = AiCallActionPlan.fromParams({'callType': 'video'});

      expect(plan.isVideo, isTrue);
      expect(plan.icon, Icons.videocam_rounded);
      expect(plan.title, 'Xác nhận gọi video');
      expect(plan.analyticsCallType, 'video');
    });

    test('exposes safe cancellation and unsupported copy', () {
      final plan = AiCallActionPlan.fromParams({'callType': 'voice'});

      expect(plan.cancelMessage, 'Đã hủy thao tác gọi.');
      expect(plan.unsupportedGroupMessage, contains('hội thoại 1-1'));
    });
  });
}
