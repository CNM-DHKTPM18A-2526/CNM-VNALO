class AiMobileCapabilityCatalog {
  const AiMobileCapabilityCatalog._();

  static const Set<String> supportedCommands = {
    'NAVIGATE_TO',
    'NAVIGATE_TO_SETTINGS',
    'NAVIGATE_TO_CHAT',
    'NAVIGATE_TO_CONTACTS',
    'NAVIGATE_TO_SCANNER',
    'NAVIGATE_TO_TIMELINE',
    'OPEN_CHAT',
    'COMPOSE_MESSAGE',
    'START_CALL',
    'RECALL_MESSAGE',
    'CREATE_GROUP',
    'MUTE_CONVERSATION',
    'UNMUTE_CONVERSATION',
    'PIN_MESSAGE',
    'UNPIN_MESSAGE',
    'OPEN_PROFILE',
    'OPEN_GROUP_SETTINGS',
    'SEND_FRIEND_REQUEST',
    'BLOCK_USER',
    'UNBLOCK_USER',
    'CHANGE_GROUP_NAME',
    'ADD_GROUP_MEMBER',
    'REMOVE_GROUP_MEMBER',
    'TRANSFER_GROUP_OWNER',
    'LEAVE_GROUP',
    'DISBAND_GROUP',
  };

  static bool isSupported(String command) {
    final normalized = command.trim().toUpperCase();
    return supportedCommands.contains(normalized);
  }

  static String buildUnsupportedFeedback(String command) {
    final normalized = command.trim().toUpperCase();

    if (normalized.contains('VIDEO')) {
      return 'Trợ lý mobile chưa hỗ trợ gọi video tự động. Bạn có thể yêu cầu mở chat rồi bấm gọi video thủ công.';
    }
    if (normalized.contains('DELETE') || normalized.contains('REMOVE_ACCOUNT')) {
      return 'Lệnh này chưa được trợ lý mobile hỗ trợ để đảm bảo an toàn. Bạn vui lòng thực hiện thủ công trong phần cài đặt liên quan.';
    }

    return 'Trợ lý chưa hỗ trợ thao tác "$normalized" trên mobile. Bạn có thể yêu cầu mở chat, soạn tin nhắn, gọi, tạo nhóm hoặc quản lý nhóm.';
  }
}
