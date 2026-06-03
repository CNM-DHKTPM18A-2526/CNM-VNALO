class BlockedUser {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool blockMessages;
  final bool blockCalls;
  final DateTime? blockedAt;

  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.blockMessages,
    required this.blockCalls,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: (json['userId'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Unknown').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      blockMessages: json['blockMessages'] == true,
      blockCalls: json['blockCalls'] == true,
      blockedAt: json['blockedAt'] != null ? DateTime.tryParse(json['blockedAt'].toString()) : null,
    );
  }

  BlockedUser copyWith({
    bool? blockMessages,
    bool? blockCalls,
  }) {
    return BlockedUser(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      blockMessages: blockMessages ?? this.blockMessages,
      blockCalls: blockCalls ?? this.blockCalls,
      blockedAt: blockedAt,
    );
  }
}
