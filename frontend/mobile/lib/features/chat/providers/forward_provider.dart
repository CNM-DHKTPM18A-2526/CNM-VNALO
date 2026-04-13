import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class ForwardProvider extends ChangeNotifier {
  final ChatProvider _chatProvider;

  List<Message> _sourceMessages = [];
  final Set<String> _selectedConversationIds = {};
  String _searchQuery = '';
  bool _isSending = false;

  ForwardProvider(this._chatProvider);

  List<Message> get sourceMessages => _sourceMessages;
  Set<String> get selectedConversationIds => _selectedConversationIds;
  String get searchQuery => _searchQuery;
  bool get isSending => _isSending;

  int get selectedCount => _selectedConversationIds.length;

  /// Start a new forwarding session
  void startForwarding(List<Message> messages) {
    _sourceMessages = messages;
    _selectedConversationIds.clear();
    _searchQuery = '';
    _isSending = false;
    notifyListeners();
  }

  void toggleSelection(String conversationId) {
    if (_selectedConversationIds.contains(conversationId)) {
      _selectedConversationIds.remove(conversationId);
    } else {
      _selectedConversationIds.add(conversationId);
    }
    notifyListeners();
  }

  void removeSelection(String conversationId) {
    _selectedConversationIds.remove(conversationId);
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Conversation> getFilteredConversations(String currentUserId) {
    final query = _searchQuery.toLowerCase();
    return _chatProvider.conversations.where((c) {
      if (query.isEmpty) return true;
      final displayName = c.getDisplayName(currentUserId).toLowerCase();
      return displayName.contains(query);
    }).toList();
  }

  Future<void> sendForward(String? additionalText) async {
    if (_selectedConversationIds.isEmpty || _sourceMessages.isEmpty) return;

    final selectedIds = _selectedConversationIds.toList();
    final sourceMsgs = List<Message>.from(_sourceMessages);

    _isSending = true;
    notifyListeners();

    try {
      // Use the new batch sending method for maximum speed and zero UI jank
      await _chatProvider.sendForwardBatch(
        conversationIds: selectedIds,
        sourceMessages: sourceMsgs,
        additionalText: additionalText,
      );
    } catch (e) {
      debugPrint('Forward background error: $e');
    } finally {
      _selectedConversationIds.clear();
      _isSending = false;
      notifyListeners();
    }
  }
}
