class AiActionPolicy {
  const AiActionPolicy._();

  static const Set<String> _destructiveCommands = {
    'RECALL_MESSAGE',
    'BLOCK_USER',
    'REMOVE_GROUP_MEMBER',
    'TRANSFER_GROUP_OWNER',
    'LEAVE_GROUP',
    'DISBAND_GROUP',
  };

  static const Set<String> _confirmationRequiredCommands = {
    'COMPOSE_MESSAGE',
    'START_CALL',
    'RECALL_MESSAGE',
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

  static bool isDestructive(String command) {
    return _destructiveCommands.contains(command.trim().toUpperCase());
  }

  static bool requiresConfirmation(String command) {
    return _confirmationRequiredCommands.contains(
      command.trim().toUpperCase(),
    );
  }
}
