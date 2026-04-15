import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/message_reaction_model.dart';
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

    if (allMemberIds.isNotEmpty) {
      await _enrichConversations(conversations, allMemberIds);
    }

    // Some inbox entries may come with incomplete conversation payload
    // (missing members/title/avatar), causing direct chats to fall back to
    // generic labels. Fetch conversation detail for those entries only.
    final missingDetailIds = conversations
        .where(
          (c) => c.members.isEmpty ||
              ((c.title == null || c.title!.trim().isEmpty) &&
                  c.type == ConversationType.DIRECT),
        )
        .map((c) => c.id)
        .toSet()
        .toList();

    if (missingDetailIds.isNotEmpty) {
      final detailMap = <String, Conversation>{};
      await Future.wait(
        missingDetailIds.map((id) async {
          final detail = await getConversationById(id);
          if (detail != null) {
            detailMap[id] = detail;
          }
        }),
      );

      if (detailMap.isNotEmpty) {
        for (int i = 0; i < conversations.length; i++) {
          final existing = conversations[i];
          final detail = detailMap[existing.id];
          if (detail == null) continue;

          conversations[i] = existing.copyWith(
            type: detail.type,
            title: (existing.title == null || existing.title!.trim().isEmpty)
                ? detail.title
                : existing.title,
            avatarUrl: existing.avatarUrl ?? detail.avatarUrl,
            members: detail.members.isNotEmpty ? detail.members : existing.members,
          );
        }
      }
    }

    // Run one more hydration pass because detail conversations can add members
    // that were not present in the initial inbox payload.
    final allIdsAfterMerge = <String>{};
    for (final conv in conversations) {
      for (final member in conv.members) {
        allIdsAfterMerge.add(member.userId);
      }
    }
    if (allIdsAfterMerge.isNotEmpty) {
      await _enrichConversationMembers(conversations, allIdsAfterMerge);
    }

    return conversations;
  }

  Future<void> _enrichConversationMembers(
    List<Conversation> conversations,
    Iterable<String> userIds,
  ) async {
    final userProfiles = <String, Map<String, dynamic>>{};
    await Future.wait(
      userIds.map((uid) async {
        try {
          final res = await _apiService.get(_coreBase, '/users/$uid');
          final data = res['data'];
          if (data is Map<String, dynamic>) {
            userProfiles[uid] = data;
          } else if (res.containsKey('displayName')) {
            userProfiles[uid] = res;
          }
        } catch (_) {
          // User not found or transient error; keep existing fallback name/avatar.
        }
      }),
    );

    for (int i = 0; i < conversations.length; i++) {
      final conv = conversations[i];
      if (conv.members.isEmpty) continue;

      final enrichedMembers = conv.members.map((member) {
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

      conversations[i] = conv.copyWith(members: enrichedMembers);
    }
  }

  Future<Conversation?> getConversationById(String conversationId) async {
    try {
      final response = await _apiService.get(_base, '/conversations/$conversationId');
      final data = response['data'] ?? response;
      if (data is! Map<String, dynamic>) return null;

      final conversation = Conversation.fromJson(data);
      return await _enrichConversation(conversation);
    } catch (_) {
      return null;
    }
  }

  // Helper to enrich a single conversation
  Future<Conversation> _enrichConversation(Conversation conversation) async {
    if (conversation.members.isEmpty) return conversation;
    final missingIds = conversation.members
        .where((m) => m.user == null)
        .map((m) => m.userId)
        .toSet();
    
    if (missingIds.isEmpty) return conversation;
    
    final profiles = await _fetchUserProfiles(missingIds);
    final enrichedMembers = conversation.members.map((m) {
      final profile = profiles[m.userId];
      if (profile != null && m.user == null) {
        return ConversationMember.fromJson({
          'conversationId': m.conversationId,
          'userId': m.userId,
          'role': m.role.name,
          'nickname': m.nickname,
          'joinedAt': m.joinedAt.toIso8601String(),
          'user': profile,
        });
      }
      return m;
    }).toList();
    
    return conversation.copyWith(members: enrichedMembers);
  }

  // Helper to enrich a list of conversations
  Future<void> _enrichConversations(List<Conversation> conversations, Set<String> memberIds) async {
    final profiles = await _fetchUserProfiles(memberIds);
    
    for (int i = 0; i < conversations.length; i++) {
      final conv = conversations[i];
      if (conv.members.isEmpty) continue;
      
      final enrichedMembers = conv.members.map((m) {
        final profile = profiles[m.userId];
        if (profile != null && m.user == null) {
          return ConversationMember.fromJson({
            'conversationId': m.conversationId,
            'userId': m.userId,
            'role': m.role.name,
            'nickname': m.nickname,
            'joinedAt': m.joinedAt.toIso8601String(),
            'user': profile,
          });
        }
        return m;
      }).toList();
      
      conversations[i] = conv.copyWith(members: enrichedMembers);
    }
  }

  // Shared user profile fetcher
  Future<Map<String, Map<String, dynamic>>> _fetchUserProfiles(Set<String> userIds) async {
    final results = <String, Map<String, dynamic>>{};
    await Future.wait(userIds.map((uid) async {
      try {
        final res = await _apiService.get(_coreBase, '/users/$uid');
        final uData = res['data'] ?? res;
        if (uData is Map<String, dynamic>) results[uid] = uData;
      } catch (_) {}
    }));
    return results;
  }

  // Get or create a direct conversation with another user
  Future<Conversation> getOrCreateDirect(String otherUserId) async {
    final response = await _apiService.post(
      _base,
      '/conversations/direct',
      body: {'targetUserId': otherUserId},
    );

    final data = response['data'];
    Conversation conversation;
    if (data is Map<String, dynamic>) {
      conversation = Conversation.fromJson(data);
    } else if (response.containsKey('id')) {
      conversation = Conversation.fromJson(response);
    } else if (response['conversation'] is Map<String, dynamic>) {
      conversation = Conversation.fromJson(response['conversation']);
    } else {
      throw Exception('Invalid response format from conversations/direct');
    }
    
    return await _enrichConversation(conversation);
  }

  // Create a new group conversation with a name and a list of member IDs
  Future<Conversation> createGroup({
    required String title,
    required List<String> memberIds,
    String? avatarUrl,
  }) async {
    final response = await _apiService.post(
      _base,
      '/conversations/group',
      body: {
        'title': title, 
        'memberIds': memberIds,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );

    final conversation = Conversation.fromJson(response['data'] ?? response);
    return await _enrichConversation(conversation);
  }

  Future<Conversation> updateGroup(String conversationId, Map<String, dynamic> body) async {
    final response = await _apiService.patch(
      _base,
      '/conversations/$conversationId',
      body: body,
    );
    return Conversation.fromJson(response['data'] ?? response);
  }

  Future<void> addMembers(String conversationId, List<String> memberIds) async {
    await _apiService.post(
      _base,
      '/conversations/$conversationId/members',
      body: {'memberIds': memberIds},
    );
  }

  Future<void> removeMember(String conversationId, String userId) async {
    await _apiService.delete(_base, '/conversations/$conversationId/members/$userId');
  }

  Future<List<dynamic>> getJoinRequests(String conversationId) async {
    final response = await _apiService.get(_base, '/conversations/$conversationId/join-requests');
    return response['data'] ?? response;
  }

  Future<void> approveJoinRequest(String conversationId, String userId) async {
    await _apiService.post(_base, '/conversations/$conversationId/join-requests/$userId/approve');
  }

  Future<void> rejectJoinRequest(String conversationId, String userId) async {
    await _apiService.delete(_base, '/conversations/$conversationId/join-requests/$userId');
  }

  Future<void> updateMemberRole(String conversationId, String userId, String role) async {
    await _apiService.patch(_base, '/conversations/$conversationId/member/$userId', body: {
      'role': role,
    });
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
  Future<Map<String, dynamic>> requestJoin(String conversationId) async {
    final response = await _apiService.post(_base, '/conversations/$conversationId/join', body: {});
    return response['data'] ?? response;
  }

  Future<List<dynamic>> getPinnedMessages(String conversationId) async {
    final response = await _apiService.get(_base, '/conversations/$conversationId/pins');
    return response['data'] ?? response as List;
  }

  // ─── Reactions ───────────────────────────────────────

  /// Add a reaction to a message
  Future<MessageReaction> addReaction(String messageId, String emoji) async {
    final response = await _apiService.post(
      _base,
      '/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    return MessageReaction.fromJson(response['data'] ?? response);
  }

  /// Remove a reaction from a message
  Future<void> removeReaction(String messageId) async {
    await _apiService.delete(_base, '/messages/$messageId/reactions');
  }

  /// Get all reactions for a message
  Future<List<MessageReaction>> getReactions(String messageId) async {
    final response = await _apiService.get(_base, '/messages/$messageId/reactions');
    final list = response['data'] as List? ?? [];
    return list.map((r) => MessageReaction.fromJson(r)).toList();
  }
}
