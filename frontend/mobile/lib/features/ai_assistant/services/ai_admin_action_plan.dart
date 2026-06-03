import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';
import 'package:vnalo_mobile/models/user_model.dart';

class AiContactActionPlan {
  final String successMessage;
  final String cancelMessage;

  const AiContactActionPlan({
    required this.successMessage,
    this.cancelMessage = 'Đã hủy thao tác liên hệ.',
  });

  static AiContactActionPlan forCommand(String command, User user) {
    return switch (command) {
      'SEND_FRIEND_REQUEST' => const AiContactActionPlan(
        successMessage: 'Đã gửi lời mời kết bạn.',
      ),
      'BLOCK_USER' => AiContactActionPlan(
        successMessage: 'Đã chặn ${user.displayName}.',
      ),
      'UNBLOCK_USER' => AiContactActionPlan(
        successMessage: 'Đã bỏ chặn ${user.displayName}.',
      ),
      _ => const AiContactActionPlan(
        successMessage: 'Trợ lý đã thực hiện thao tác liên hệ.',
      ),
    };
  }
}

class AiGroupAdminActionPlan {
  final List<String> memberNames;
  final String? newTitle;
  final String? secondaryDetail;
  final String secondaryDetailLabel;
  final String cancelMessage;
  final String successMessage;

  const AiGroupAdminActionPlan({
    required this.memberNames,
    required this.newTitle,
    required this.secondaryDetail,
    required this.secondaryDetailLabel,
    this.cancelMessage = 'Đã hủy thao tác nhóm.',
    this.successMessage = 'Trợ lý đã thực hiện thao tác nhóm.',
  });

  factory AiGroupAdminActionPlan.fromParams(Map<String, dynamic>? params) {
    final memberNames = AiCommandRouting.extractMemberNames(params);
    final newTitle = AiCommandRouting.extractNewTitle(params);
    return AiGroupAdminActionPlan(
      memberNames: memberNames,
      newTitle: newTitle,
      secondaryDetail:
          newTitle ?? (memberNames.isEmpty ? null : memberNames.join(', ')),
      secondaryDetailLabel: newTitle != null ? 'Tên mới' : 'Thành viên',
    );
  }

  void validateBeforeExecute(String command) {
    switch (command) {
      case 'CHANGE_GROUP_NAME':
        if (newTitle == null) {
          throw StateError('Trợ lý chưa có tên nhóm mới.');
        }
        break;
      case 'ADD_GROUP_MEMBER':
        if (memberNames.isEmpty) {
          throw StateError('Trợ lý chưa xác định thành viên cần thêm.');
        }
        break;
      case 'REMOVE_GROUP_MEMBER':
        if (memberNames.isEmpty) {
          throw StateError('Trợ lý chưa xác định thành viên cần xóa.');
        }
        break;
      case 'TRANSFER_GROUP_OWNER':
        if (memberNames.isEmpty) {
          throw StateError('Cần chọn đúng một thành viên để chuyển quyền.');
        }
        break;
    }
  }
}
