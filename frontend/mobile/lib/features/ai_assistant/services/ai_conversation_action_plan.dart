import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';
import 'package:vnalo_mobile/models/user_model.dart';

class AiCreateGroupActionPlan {
  final String groupName;
  final List<String> memberNames;

  const AiCreateGroupActionPlan({
    required this.groupName,
    required this.memberNames,
  });

  factory AiCreateGroupActionPlan.fromParams(Map<String, dynamic>? params) {
    return AiCreateGroupActionPlan(
      groupName: AiCommandRouting.extractGroupName(params),
      memberNames: AiCommandRouting.extractMemberNames(params),
    );
  }

  List<String> get uniqueMemberNames {
    final seen = <String>{};
    final result = <String>[];
    for (final name in memberNames) {
      final normalized = _normalizeName(name);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      result.add(name.trim());
    }
    return result;
  }

  bool get isValid => groupName.isNotEmpty && uniqueMemberNames.length >= 2;

  static String _normalizeName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String get invalidMessage =>
      'Tro ly can ten nhom va it nhat 2 thanh vien khac ngoai ban.';

  String duplicateMemberMessage(String name) =>
      'Co nhieu nguoi ten "$name". Hay noi ro ho ten.';

  String missingMemberMessage(String name) =>
      'Khong tim thay "$name" trong danh ba.';

  String selectedMemberDetail(Iterable<User> users) {
    return users.map((user) => user.displayName).join(', ');
  }

  String get cancelMessage => 'Da huy thao tac tao nhom.';

  String get successMessage => 'Da tao nhom "$groupName".';
}

class AiMuteConversationActionPlan {
  final bool muted;

  const AiMuteConversationActionPlan({required this.muted});

  IconData get icon =>
      muted ? Icons.notifications_off_rounded : Icons.notifications_rounded;

  String get title => muted ? 'Tắt thông báo' : 'Bật thông báo';

  String get description =>
      muted
          ? 'Trợ lý sẽ tắt thông báo cho cuộc trò chuyện này.'
          : 'Trợ lý sẽ bật lại thông báo cho cuộc trò chuyện này.';

  String get confirmLabel => muted ? 'Tắt thông báo' : 'Bật thông báo';

  String get cancelMessage =>
      muted
          ? 'Đã hủy thao tác tắt thông báo.'
          : 'Đã hủy thao tác bật thông báo.';

  String get successMessage =>
      muted ? 'Đã tắt thông báo.' : 'Đã bật thông báo.';
}

class AiPinMessageActionPlan {
  final bool pin;

  const AiPinMessageActionPlan({required this.pin});

  IconData get icon => pin ? Icons.push_pin_rounded : Icons.push_pin_outlined;

  String get title =>
      pin ? 'Xác nhận ghim tin nhắn' : 'Xác nhận bỏ ghim tin nhắn';

  String get description =>
      pin
          ? 'Trợ lý sẽ ghim tin nhắn trong cuộc trò chuyện hiện tại.'
          : 'Trợ lý sẽ bỏ ghim tin nhắn trong cuộc trò chuyện hiện tại.';

  String get confirmLabel => pin ? 'Ghim' : 'Bỏ ghim';

  String get cancelMessage =>
      pin
          ? 'Đã hủy thao tác ghim tin nhắn.'
          : 'Đã hủy thao tác bỏ ghim tin nhắn.';

  String get missingMessage =>
      'Không tìm thấy tin nhắn phù hợp để ghim/bỏ ghim.';
}
