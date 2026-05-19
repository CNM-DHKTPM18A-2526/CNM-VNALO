import 'dart:async';

class AiComposeDraftEvent {
  final String conversationId;
  final String text;

  const AiComposeDraftEvent({required this.conversationId, required this.text});
}

class AiComposeDraftBus {
  final StreamController<AiComposeDraftEvent> _controller =
      StreamController<AiComposeDraftEvent>.broadcast();

  Stream<AiComposeDraftEvent> get stream => _controller.stream;

  void emit({required String conversationId, required String text}) {
    final normalizedConversationId = conversationId.trim();
    final normalizedText = text.trim();
    if (normalizedConversationId.isEmpty || normalizedText.isEmpty) {
      return;
    }
    if (_controller.isClosed) {
      return;
    }
    _controller.add(
      AiComposeDraftEvent(
        conversationId: normalizedConversationId,
        text: normalizedText,
      ),
    );
  }

  Future<void> close() async {
    if (_controller.isClosed) {
      return;
    }
    await _controller.close();
  }
}
