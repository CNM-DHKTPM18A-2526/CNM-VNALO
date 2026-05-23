import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_action_policy.dart';

class AiContactActionPresentation {
  final IconData icon;
  final String title;
  final String description;
  final String confirmLabel;
  final bool destructive;

  const AiContactActionPresentation({
    required this.icon,
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.destructive,
  });
}

class AiGroupActionPresentation {
  final IconData icon;
  final String title;
  final String description;
  final String confirmLabel;
  final bool destructive;

  const AiGroupActionPresentation({
    required this.icon,
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.destructive,
  });
}

class AiActionPresentationResolver {
  const AiActionPresentationResolver._();

  static AiContactActionPresentation contact(String command) {
    final destructive = AiActionPolicy.isDestructive(command);
    return AiContactActionPresentation(
      icon: destructive ? Icons.block_rounded : Icons.person_add_alt_1_rounded,
      title: switch (command) {
        'SEND_FRIEND_REQUEST' => 'Xác nhận gửi kết bạn',
        'BLOCK_USER' => 'Xác nhận chặn người dùng',
        'UNBLOCK_USER' => 'Xác nhận bỏ chặn người dùng',
        _ => 'Xác nhận thao tác',
      },
      description: switch (command) {
        'SEND_FRIEND_REQUEST' =>
          'Trợ lý sẽ gửi lời mời kết bạn đến người này.',
        'BLOCK_USER' =>
          'Bạn sẽ không nhận tin nhắn/cuộc gọi từ người này.',
        'UNBLOCK_USER' =>
          'Bạn sẽ cho phép liên hệ lại với người này.',
        _ => 'Trợ lý sẽ thực hiện thao tác đã chọn.',
      },
      confirmLabel: switch (command) {
        'SEND_FRIEND_REQUEST' => 'Gửi kết bạn',
        'BLOCK_USER' => 'Chặn',
        'UNBLOCK_USER' => 'Bỏ chặn',
        _ => 'Xác nhận',
      },
      destructive: destructive,
    );
  }

  static AiGroupActionPresentation group(String command) {
    final destructive = AiActionPolicy.isDestructive(command);

    return AiGroupActionPresentation(
      icon:
          destructive
              ? Icons.warning_amber_rounded
              : Icons.admin_panel_settings_rounded,
      title: switch (command) {
        'CHANGE_GROUP_NAME' => 'Xác nhận đổi tên nhóm',
        'ADD_GROUP_MEMBER' => 'Xác nhận thêm thành viên',
        'REMOVE_GROUP_MEMBER' => 'Xác nhận xóa thành viên',
        'TRANSFER_GROUP_OWNER' => 'Xác nhận chuyển quyền nhóm',
        'LEAVE_GROUP' => 'Xác nhận rời nhóm',
        'DISBAND_GROUP' => 'Xác nhận giải tán nhóm',
        _ => 'Xác nhận thao tác nhóm',
      },
      description: switch (command) {
        'CHANGE_GROUP_NAME' =>
          'Trợ lý sẽ cập nhật tên nhóm sau khi bạn xác nhận.',
        'ADD_GROUP_MEMBER' => 'Trợ lý sẽ thêm thành viên vào nhóm này.',
        'REMOVE_GROUP_MEMBER' =>
          'Thành viên được chọn sẽ bị mời khỏi nhóm.',
        'TRANSFER_GROUP_OWNER' =>
          'Quyền trưởng nhóm sẽ được chuyển cho thành viên này.',
        'LEAVE_GROUP' => 'Bạn sẽ rời khỏi nhóm này.',
        'DISBAND_GROUP' => 'Nhóm sẽ bị giải tán cho tất cả thành viên.',
        _ => 'Trợ lý sẽ thực hiện thao tác nhóm đã chọn.',
      },
      confirmLabel: switch (command) {
        'CHANGE_GROUP_NAME' => 'Đổi tên',
        'ADD_GROUP_MEMBER' => 'Thêm',
        'REMOVE_GROUP_MEMBER' => 'Xóa khỏi nhóm',
        'TRANSFER_GROUP_OWNER' => 'Chuyển quyền',
        'LEAVE_GROUP' => 'Rời nhóm',
        'DISBAND_GROUP' => 'Giải tán',
        _ => 'Xác nhận',
      },
      destructive: destructive,
    );
  }
}
