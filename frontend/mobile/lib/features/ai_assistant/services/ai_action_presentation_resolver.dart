import 'package:flutter/material.dart';

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
    final destructive = command == 'BLOCK_USER';
    return AiContactActionPresentation(
      icon: destructive ? Icons.block_rounded : Icons.person_add_alt_1_rounded,
      title: switch (command) {
        'SEND_FRIEND_REQUEST' => 'Xác nh?n g?i k?t b?n',
        'BLOCK_USER' => 'Xác nh?n ch?n ngu?i dùng',
        'UNBLOCK_USER' => 'Xác nh?n b? ch?n ngu?i dùng',
        _ => 'Xác nh?n thao tác',
      },
      description: switch (command) {
        'SEND_FRIEND_REQUEST' =>
          'Tr? lý s? g?i l?i m?i k?t b?n d?n ngu?i này.',
        'BLOCK_USER' =>
          'B?n s? không nh?n tin nh?n/cu?c g?i t? ngu?i này.',
        'UNBLOCK_USER' =>
          'B?n s? cho phép liên h? l?i v?i ngu?i này.',
        _ => 'Tr? lý s? th?c hi?n thao tác dã ch?n.',
      },
      confirmLabel: switch (command) {
        'SEND_FRIEND_REQUEST' => 'G?i k?t b?n',
        'BLOCK_USER' => 'Ch?n',
        'UNBLOCK_USER' => 'B? ch?n',
        _ => 'Xác nh?n',
      },
      destructive: destructive,
    );
  }

  static AiGroupActionPresentation group(String command) {
    final destructive =
        command == 'REMOVE_GROUP_MEMBER' ||
        command == 'LEAVE_GROUP' ||
        command == 'DISBAND_GROUP';

    return AiGroupActionPresentation(
      icon:
          destructive
              ? Icons.warning_amber_rounded
              : Icons.admin_panel_settings_rounded,
      title: switch (command) {
        'CHANGE_GROUP_NAME' => 'Xác nh?n d?i tên nhóm',
        'ADD_GROUP_MEMBER' => 'Xác nh?n thêm thành viên',
        'REMOVE_GROUP_MEMBER' => 'Xác nh?n xóa thành viên',
        'TRANSFER_GROUP_OWNER' => 'Xác nh?n chuy?n quy?n nhóm',
        'LEAVE_GROUP' => 'Xác nh?n r?i nhóm',
        'DISBAND_GROUP' => 'Xác nh?n gi?i tán nhóm',
        _ => 'Xác nh?n thao tác nhóm',
      },
      description: switch (command) {
        'CHANGE_GROUP_NAME' =>
          'Tr? lý s? c?p nh?t tên nhóm sau khi b?n xác nh?n.',
        'ADD_GROUP_MEMBER' => 'Tr? lý s? thêm thành viên vào nhóm này.',
        'REMOVE_GROUP_MEMBER' =>
          'Thành viên du?c ch?n s? b? m?i kh?i nhóm.',
        'TRANSFER_GROUP_OWNER' =>
          'Quy?n tru?ng nhóm s? du?c chuy?n cho thành viên này.',
        'LEAVE_GROUP' => 'B?n s? r?i kh?i nhóm này.',
        'DISBAND_GROUP' => 'Nhóm s? b? gi?i tán cho t?t c? thành viên.',
        _ => 'Tr? lý s? th?c hi?n thao tác nhóm dã ch?n.',
      },
      confirmLabel: switch (command) {
        'CHANGE_GROUP_NAME' => 'Ð?i tên',
        'ADD_GROUP_MEMBER' => 'Thêm',
        'REMOVE_GROUP_MEMBER' => 'Xóa kh?i nhóm',
        'TRANSFER_GROUP_OWNER' => 'Chuy?n quy?n',
        'LEAVE_GROUP' => 'R?i nhóm',
        'DISBAND_GROUP' => 'Gi?i tán',
        _ => 'Xác nh?n',
      },
      destructive: destructive,
    );
  }
}