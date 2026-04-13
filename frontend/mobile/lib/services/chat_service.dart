import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class ChatService {
  final ApiService _apiService;

  ChatService(this._apiService);

  String get _base => AppConfig.instance.messageServiceUrl;
  String get _coreBase => AppConfig.instance.coreServiceUrl;

  Future<List<Conversation>> getInbox() async {
    final response = await _apiService.get(_base, '/inbox');
    final raw = response['data'];
    if (raw is! List) return const [];

    final conversations = <Conversation>[];
    final allMemberIds = <String>{};

    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;

      final inboxEntry = Map<String, dynamic>.from(item);
      final nestedConversation =
          inboxEntry['conversation'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                inboxEntry['conversation'] as Map<String, dynamic>,
              )
              : <String, dynamic>{};

      final conversationId =
          nestedConversation['id'] ??
          inboxEntry['conversationId'] ??
          inboxEntry['conversation_id'];

      if (conversationId == null) continue;

      final json = <String, dynamic>{
        ...nestedConversation,
        'id': conversationId,
        'unreadCount':
            inboxEntry['unreadCount'] ?? inboxEntry['unread_count'] ?? 0,
        'isPinned': inboxEntry['isPinned'] ?? inboxEntry['is_pinned'] ?? false,
        'isMuted': inboxEntry['isMuted'] ?? inboxEntry['is_muted'] ?? false,
        'isHidden': inboxEntry['isHidden'] ?? inboxEntry['is_hidden'] ?? false,
        'isFavorite': inboxEntry['isFavorite'] ?? inboxEntry['is_favorite'] ?? false,
        'autoDeleteSeconds': inboxEntry['autoDeleteSeconds'] ?? inboxEntry['auto_delete_seconds'] ?? 0,
        'notifyCall': inboxEntry['notifyCall'] ?? inboxEntry['notify_call'] ?? true,
        'personalWallpaperUrl': inboxEntry['personalWallpaperUrl'] ?? inboxEntry['personal_wallpaper_url'],
      };

      final preview =
          inboxEntry['lastMessagePreview'] ??
          inboxEntry['last_message_preview'];
      final messageAt =
          inboxEntry['lastMessageAt'] ?? inboxEntry['last_message_at'];

      if (preview != null || messageAt != null) {
        json['lastMessage'] = {
          'id': 'inbox-$conversationId',
          'conversationId': conversationId,
          'serverSeq':
              inboxEntry['lastMessageSeq'] ??
              inboxEntry['last_message_seq'],
          'senderId':
              inboxEntry['lastMessageSenderId'] ??
              inboxEntry['last_message_sender_id'] ??
              '',
          'messageType':
              inboxEntry['lastMessageType'] ??
              inboxEntry['last_message_type'] ??
              'TEXT',
          'content': preview,
          'createdAt': messageAt,
        };
      }

      // Collect member IDs for batch user fetch
      final membersList = nestedConversation['members'];
      if (membersList is List) {
        for (final m in membersList) {
          if (m is Map && m['userId'] != null) {
            allMemberIds.add(m['userId'].toString());
          }
        }
      }

      conversations.add(Conversation.fromJson(json));
    }

    // Batch fetch user profiles for all member IDs
    if (allMemberIds.isNotEmpty) {
      final userProfiles = <String, Map<String, dynamic>>{};
      await Future.wait(
        allMemberIds.map((uid) async {
          try {
            final res = await _apiService.get(_coreBase, '/users/$uid');
            final data = res['data'];
            if (data is Map<String, dynamic>) {
              userProfiles[uid] = data;
            } else if (res.containsKey('displayName')) {
              userProfiles[uid] = res;
            }
          } catch (_) {
            // User not found or error, skip
          }
        }),
      );

      // Enrich conversation members with user profile data
      for (int i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        if (conv.members.isEmpty) continue;
        final enrichedMembers =
            conv.members.map((member) {
              final profile = userProfiles[member.userId];
              if (profile != null && member.user == null) {
                return ConversationMember.fromJson({
                  'conversationId': member.conversationId,
                  'userId': member.userId,
                  'role': member.role.name,
                  'nickname': member.nickname,
                  'joinedAt': member.joinedAt.toIso8601String(),
                  'user': profile,
                });
              }
              return member;
            }).toList();

        // Rebuild conversation with enriched members
        conversations[i] = Conversation(
          id: conv.id,
          type: conv.type,
          title: conv.title,
          avatarUrl: conv.avatarUrl,
          description: conv.description,
          createdBy: conv.createdBy,
          status: conv.status,
          joinMode: conv.joinMode,
          memberLimit: conv.memberLimit,
          isEncrypted: conv.isEncrypted,
          allowMemberInvite: conv.allowMemberInvite,
          allowMemberPin: conv.allowMemberPin,
          allowMemberEditInfo: conv.allowMemberEditInfo,
          createdAt: conv.createdAt,
          updatedAt: conv.updatedAt,
          members: enrichedMembers,
          lastMessage: conv.lastMessage,
          unreadCount: conv.unreadCount,
          isPinned: conv.isPinned,
          isMuted: conv.isMuted,
          isHidden: conv.isHidden,
          isFavorite: conv.isFavorite,
          autoDeleteSeconds: conv.autoDeleteSeconds,
          notifyCall: conv.notifyCall,
          personalWallpaperUrl: conv.personalWallpaperUrl,
        );
      }
    }

    return conversations;
  }

  Future<Conversation?> getConversationById(String conversationId) async {
    try {
      final response = await _apiService.get(
        _base,
        '/conversations/$conversationId',
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return Conversation.fromJson(data);
      }
      if (response['conversation'] is Map<String, dynamic>) {
        return Conversation.fromJson(
          response['conversation'] as Map<String, dynamic>,
        );
      }
      if (response.containsKey('id')) {
        return Conversation.fromJson(response);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Get or create a direct conversation with another user
  Future<Conversation> getOrCreateDirect(String otherUserId) async {
    final response = await _apiService.post(
      _base,
      '/conversations/direct',
      body: {'targetUserId': otherUserId},
    );

    debugPrint('[CHAT] getOrCreateDirect response: $response');
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return Conversation.fromJson(data);
    }
    // If 'data' is null, the response itself might be the conversation
    if (response.containsKey('id')) {
      return Conversation.fromJson(response);
    }
    // Try 'conversation' key
    final conv = response['conversation'];
    if (conv is Map<String, dynamic>) {
      return Conversation.fromJson(conv);
    }
    throw Exception('Invalid response format from conversations/direct');
  }

  // Create a new group conversation with a name and a list of member IDs
  Future<Conversation> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final response = await _apiService.post(
      _base,
      '/conversations/group',
      body: {'title': title, 'memberIds': memberIds},
    );

    return Conversation.fromJson(response['data']);
  }

  // Get messages for a conversation, with optional pagination parameters
  Future<List<Message>> getMessages(
    String conversationId, {
    String? before,
    int limit = 30, // Default to 30 messages if not specified
  }) async {
    final response = await _apiService.get(
      _base,
      '/conversations/$conversationId/messages',
      // Pass pagination parameters as query parameters
      queryParams: {'limit': '$limit', if (before != null) 'before': before},
    );

    final list = response['data'] as List;
    return list.map((m) => Message.fromJson(m)).toList();
  }

  // Send a message to a conversation
  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'TEXT', // Default to 'TEXT' if not specified
  }) async {
    final response = await _apiService.post(
      _base,
      '/messages',
      body: {
        'conversationId': conversationId,
        'content': content,
        'messageType': messageType,
      },
    );

    return Message.fromJson(response['data']);
  }

  Future<Map<String, dynamic>> updateInboxSettings(String conversationId, {
    bool? isPinned, 
    bool? isMuted, 
    bool? isHidden,
    bool? isFavorite,
    int? autoDeleteSeconds,
    bool? notifyCall,
    String? wallpaperUrl,
  }) async {
    final Map<String, dynamic> body = {};
    if (isPinned != null) body['isPinned'] = isPinned;
    if (isMuted != null) body['isMuted'] = isMuted;
    if (isHidden != null) body['isHidden'] = isHidden;
    if (isFavorite != null) body['isFavorite'] = isFavorite;
    if (autoDeleteSeconds != null) body['autoDeleteSeconds'] = autoDeleteSeconds;
    if (notifyCall != null) body['notifyCall'] = notifyCall;
    if (wallpaperUrl != null) body['wallpaperUrl'] = wallpaperUrl;

    return _apiService.patch(_base, '/inbox/$conversationId', body: body);
  }

  Future<void> deleteChatHistory(String conversationId) async {
    await _apiService.delete(_base, '/inbox/$conversationId/history');
  }

  Future<void> deleteForMe(String messageId) async {
    await _apiService.delete(_base, '/messages/$messageId/for-me');
  }

  Future<void> updateMemberNickname(String conversationId, String targetUserId, String nickname) async {
    await _apiService.patch(_base, '/conversations/$conversationId/member/$targetUserId', body: {
      'nickname': nickname,
    });
  }

  Future<void> updateWallpaper(String conversationId, String wallpaperUrl, {bool isGlobal = true}) async {
    await _apiService.patch(_base, '/conversations/$conversationId/wallpaper', body: {
      'wallpaperUrl': wallpaperUrl,
      'isGlobal': isGlobal,
    });
  }

  Future<List<Message>> searchMedia(String conversationId, {String? messageType, int limit = 50}) async {
    final queryParams = {
      'limit': limit.toString(),
      if (messageType != null) 'messageType': messageType,
    };

    final response = await _apiService.get(_base, '/messages/search/$conversationId', queryParams: queryParams);
    final List items = response['items'] ?? [];
    return items.map((m) => Message.fromJson(m)).toList();
  }
}
