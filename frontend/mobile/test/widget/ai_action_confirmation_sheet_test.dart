import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_action_confirmation_sheet.dart';

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
}
