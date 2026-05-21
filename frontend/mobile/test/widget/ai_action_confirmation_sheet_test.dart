import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_action_confirmation_sheet.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_conversation_disambiguation_sheet.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';

Conversation _directConversation({
  required String id,
  required String peerName,
}) {
  return Conversation(
    id: id,
    type: ConversationType.DIRECT,
    members: [
      ConversationMember(
        conversationId: id,
        userId: 'current-user',
        joinedAt: DateTime(2026),
      ),
      ConversationMember(
        conversationId: id,
        userId: 'peer-$id',
        joinedAt: DateTime(2026),
        user: User(id: 'peer-$id', displayName: peerName),
      ),
    ],
  );
}

void main() {
  testWidgets('AI confirmation sheet renders consistent actions', (
    tester,
  ) async {
    late Future<bool> result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      result = AiActionConfirmationSheet.show(
                        context,
                        icon: Icons.call_rounded,
                        title: 'Xác nhận gọi thoại',
                        description:
                            'Trợ lý sẽ bắt đầu cuộc gọi tới liên hệ đã chọn.',
                        confirmLabel: 'Bắt đầu gọi',
                        primaryDetail: 'Người nhận: Minh Anh',
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận gọi thoại'), findsOneWidget);
    expect(find.text('Bắt đầu gọi'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(find.text('Người nhận: Minh Anh'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
  });

  testWidgets('AI confirmation sheet confirm action returns true', (
    tester,
  ) async {
    late Future<bool> result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      result = AiActionConfirmationSheet.show(
                        context,
                        icon: Icons.undo_rounded,
                        title: 'Xác nhận thu hồi tin nhắn',
                        description: 'Trợ lý sẽ thu hồi tin nhắn gần nhất.',
                        confirmLabel: 'Thu hồi',
                        destructive: true,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
  });

  testWidgets('AI conversation disambiguation sheet returns selected chat', (
    tester,
  ) async {
    late Future<Conversation?> result;
    final matches = [
      _directConversation(id: 'c1', peerName: 'Minh Anh'),
      _directConversation(id: 'c2', peerName: 'Minh Anh Work'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      result = AiConversationDisambiguationSheet.show(
                        context,
                        matches: matches,
                        currentUserId: 'current-user',
                        targetName: 'Minh Anh',
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Minh Anh'), findsWidgets);
    expect(find.text('Minh Anh'), findsOneWidget);
    expect(find.text('Minh Anh Work'), findsOneWidget);
    expect(find.text('Trò chuyện 1-1'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey('ai_conversation_disambiguation_item_c2')),
    );
    await tester.pumpAndSettle();

    expect((await result)?.id, 'c2');
  });

  testWidgets('AI conversation disambiguation sheet cancel returns null', (
    tester,
  ) async {
    late Future<Conversation?> result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      result = AiConversationDisambiguationSheet.show(
                        context,
                        matches: [
                          _directConversation(id: 'c1', peerName: 'An'),
                        ],
                        currentUserId: 'current-user',
                        targetName: 'An',
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('ai_conversation_disambiguation_cancel')),
    );
    await tester.pumpAndSettle();

    expect(await result, isNull);
  });

  testWidgets('AI confirmation sheet remains stable on compact viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      AiActionConfirmationSheet.show(
                        context,
                        icon: Icons.call_rounded,
                        title:
                            'Xác nhận gọi thoại với liên hệ rất dài để kiểm tra bố cục',
                        description:
                            'Trợ lý sẽ bắt đầu cuộc gọi ngay sau khi bạn xác nhận. Nội dung này đủ dài để kiểm tra tình huống màn hình thấp và bàn phím đang mở.',
                        confirmLabel: 'Bắt đầu gọi',
                        primaryDetail: 'Người nhận: Minh Anh Nguyễn Văn A',
                        secondaryDetail:
                            'Đây là phần mô tả bổ sung khá dài để khóa lỗi overflow ở bottom sheet.',
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Bắt đầu gọi'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI disambiguation sheet remains stable on compact viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late Future<Conversation?> result;
    final matches = List.generate(
      8,
      (index) =>
          _directConversation(id: 'c$index', peerName: 'Minh Anh $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      result = AiConversationDisambiguationSheet.show(
                        context,
                        matches: matches,
                        currentUserId: 'current-user',
                        targetName: 'Minh Anh',
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ai_conversation_disambiguation_cancel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final lastItemFinder = find.byKey(
      const ValueKey('ai_conversation_disambiguation_item_c7'),
    );
    await tester.scrollUntilVisible(
      lastItemFinder,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(lastItemFinder);
    await tester.pumpAndSettle();

    expect((await result)?.id, 'c7');
  });
}
