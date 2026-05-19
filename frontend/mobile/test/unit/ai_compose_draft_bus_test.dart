import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_compose_draft_bus.dart';

void main() {
  group('AiComposeDraftBus', () {
    test('emits normalized draft events', () async {
      final bus = AiComposeDraftBus();
      addTearDown(bus.close);

      final future = bus.stream.first;
      bus.emit(conversationId: ' conv-1 ', text: '  xin chào  ');
      final event = await future;

      expect(event.conversationId, 'conv-1');
      expect(event.text, 'xin chào');
    });

    test('ignores empty conversation or draft text', () async {
      final bus = AiComposeDraftBus();
      addTearDown(bus.close);

      var emitted = false;
      final sub = bus.stream.listen((_) => emitted = true);
      addTearDown(sub.cancel);

      bus.emit(conversationId: '   ', text: 'xin chào');
      bus.emit(conversationId: 'conv-1', text: '   ');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emitted, isFalse);
    });
  });
}
