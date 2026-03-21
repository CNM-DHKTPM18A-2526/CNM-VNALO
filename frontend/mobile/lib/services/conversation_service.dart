import 'package:vnalo_mobile/core/constants/api_endpoints.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class ConversationService {
  final ApiService _apiService;
  ConversationService(this._apiService);

  static get _base => ApiEndpoints.messageBaseUrl;

  // Update group conversation details like title, description, avatar
  Future<Conversation> updateGroup({
    required String conversationId,
    String? title,
    String? description,
    String? avatarUrl,
  }) async {
    final response = await _apiService.patch(
      _base,
      '${ApiEndpoints.conversations}/$conversationId',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );

    return Conversation.fromJson(response['data']);
  }

  // Update group conversation settings like join mode and member permissions
  Future<Conversation> updateGroupSettings({
    required String conversationId,
    JoinMode? joinMode,
    bool? allowMemberInvite,
    bool? allowMemberPin,
    bool? allowMemberEditInfo,
  }) async {
    final response = await _apiService.patch(
      _base,
      '${ApiEndpoints.conversations}/$conversationId',
      body: {
        if (joinMode != null) 'joinMode': joinMode.toString().split('.').last,
        if (allowMemberInvite != null) 'allowMemberInvite': allowMemberInvite,
        if (allowMemberPin != null) 'allowMemberPin': allowMemberPin,
        if (allowMemberEditInfo != null)
          'allowMemberEditInfo': allowMemberEditInfo,
      },
    );

    return Conversation.fromJson(response['data']);
  }

  // Add members to a group conversation
  Future<void> addMembers(String conversationId, List<String> memberIds) async {
    await _apiService.post(
      _base,
      '${ApiEndpoints.conversations}/$conversationId/members',
      body: {'memberIds': memberIds},
    );
  }

  // Remove a member from a group conversation
  Future<void> removeMember(String conversationId, String memberId) async {
    await _apiService.delete(
      _base,
      '${ApiEndpoints.conversations}/$conversationId/members/$memberId',
    );
  }

  // Leave a group conversation
  Future<void> leaveGroup(String conversationId, String currentUserId) async {
    await _apiService.delete(
      _base,
      '${ApiEndpoints.conversations}/$conversationId/members/$currentUserId',
    );
  }

  // Join a group conversation
  Future<Map<String, dynamic>> requrestJoin(String conversationId) async {
    return await _apiService.post(
      _base,
      '${ApiEndpoints.conversations}/$conversationId/join',
    );
  }

  // Approve join request for a group conversation
  Future<Map<String, dynamic>> approveJoinRequest(
    String conversationId,
    String userId,
  ) async {
    return await _apiService.post(
      _base,
      '${ApiEndpoints.conversations}/$conversationId/join-requests/$userId/approve',
    );
  }

  // Reject join request for a group conversation
  Future<Map<String, dynamic>> rejectJoinRequest(
    String conversationId,
    String userId,
  ) async {
    return await _apiService.delete(
      _base,
      '${ApiEndpoints.conversations}/$conversationId/join-requests/$userId',
    );
  }
}
