import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_action_presentation_resolver.dart';

void main() {
  group('AiActionPresentationResolver.contact', () {
    test('builds safe friend request confirmation copy', () {
      final presentation = AiActionPresentationResolver.contact(
        'SEND_FRIEND_REQUEST',
      );

      expect(presentation.icon, Icons.person_add_alt_1_rounded);
      expect(presentation.title, 'Xác nh?n g?i k?t b?n');
      expect(presentation.confirmLabel, 'G?i k?t b?n');
      expect(presentation.destructive, isFalse);
    });

    test('marks block user action as destructive', () {
      final presentation = AiActionPresentationResolver.contact('BLOCK_USER');

      expect(presentation.icon, Icons.block_rounded);
      expect(presentation.confirmLabel, 'Ch?n');
      expect(presentation.destructive, isTrue);
    });
  });

  group('AiActionPresentationResolver.group', () {
    test('builds non-destructive group rename copy', () {
      final presentation = AiActionPresentationResolver.group(
        'CHANGE_GROUP_NAME',
      );

      expect(presentation.icon, Icons.admin_panel_settings_rounded);
      expect(presentation.title, 'Xác nh?n d?i tên nhóm');
      expect(presentation.confirmLabel, 'Ð?i tên');
      expect(presentation.destructive, isFalse);
    });

    test('marks risky group actions as destructive', () {
      final remove = AiActionPresentationResolver.group('REMOVE_GROUP_MEMBER');
      final leave = AiActionPresentationResolver.group('LEAVE_GROUP');
      final disband = AiActionPresentationResolver.group('DISBAND_GROUP');

      expect(remove.destructive, isTrue);
      expect(leave.destructive, isTrue);
      expect(disband.destructive, isTrue);
      expect(disband.icon, Icons.warning_amber_rounded);
    });
  });
}