import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class ChatService {
  final ApiService _apiService;

  ChatService(this._apiService);

  String get _base => AppConfig.instance.messageServiceUrl;

  Future<List<Conversation>> getInbox() async {
    final response = await _apiService.get(_base, '/inbox');
    final list = response['data'] as List;
    // Map each item in the list to a Conversation object and return the list of conversations
    return list.map((c) => Conversation.fromJson(c)).toList();
  }

  // Get or create a direct conversation with another user
  Future<Conversation> getOrCreateDirect(String otherUserId) async {
    final response = await _apiService.post(
      _base,
      '/conversations/direct',
      body: {'targetUserId': otherUserId},
    );

    return Conversation.fromJson(response['data']);
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
}
