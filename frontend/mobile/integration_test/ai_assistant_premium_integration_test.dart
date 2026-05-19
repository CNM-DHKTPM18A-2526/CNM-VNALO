import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFor(
    WidgetTester tester,
    Duration total, {
    Duration step = const Duration(milliseconds: 250),
  }) async {
    final iterations =
        total.inMilliseconds ~/ step.inMilliseconds.clamp(1, 1000000);
    for (var i = 0; i < iterations; i++) {
      await tester.pump(step);
    }
  }

  Future<void> launchAppWithVisibleBubble(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {
      'vnalo_ai_is_visible': true,
      'vnalo_ai_conversation_created': true,
      'vnalo_ai_history_v1':
          '[{"role":"assistant","text":"Xin chao","source":"seed","createdAt":"2026-04-21T08:00:00.000Z"}]',
    });

    app.main();
    await pumpFor(tester, const Duration(seconds: 4));
  }

  testWidgets('Bubble drag-to-trash works with constrained drop zone', (
    tester,
  ) async {
    await launchAppWithVisibleBubble(tester);

    final bubble = find.byKey(const ValueKey('ai_bubble_root'));
    expect(bubble, findsOneWidget);

    final start = tester.getCenter(bubble);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 120));

    await gesture.moveBy(const Offset(0, 420));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('ai_bubble_trash_zone')), findsOneWidget);

    await gesture.up();
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('ai_bubble_root')), findsNothing);
  });

  testWidgets('Tap bubble opens board and close keeps bubble visible', (
    tester,
  ) async {
    await launchAppWithVisibleBubble(tester);

    final bubble = find.byKey(const ValueKey('ai_bubble_root'));
    expect(bubble, findsOneWidget);

    await tester.tap(bubble);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ai_chat_close')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('ai_chat_board')), findsNothing);
    expect(find.byKey(const ValueKey('ai_bubble_root')), findsOneWidget);
  });

  testWidgets('Open AI conversation from bubble board', (tester) async {
    await launchAppWithVisibleBubble(tester);

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await pumpFor(tester, const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ai_chat_open_conversation')));
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.text('Hội thoại AI'), findsOneWidget);
  });
}
