import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI mobile surfaces do not contain mojibake markers', () async {
    const mojibakeMarkers = <String>[
      'Ã',
      'Ä',
      'áº',
      'á»',
      'Æ',
      'Â',
      'X?c nh',
      'Tr? l?',
      'Ng??i',
      'Khong ',
      'Tro ly',
      'Thu h?i',
      'B?t ??u',
      'M? v?',
    ];

    final files = <String>[
      'lib/navigation/main_shell.dart',
      'lib/features/ai_assistant/providers/ai_assistant_provider.dart',
      'lib/features/ai_assistant/screens/ai_conversation_screen.dart',
      'lib/features/ai_assistant/widgets/ai_chat_board.dart',
      'lib/features/ai_assistant/widgets/ai_floating_bubble.dart',
      'lib/features/ai_assistant/widgets/ai_action_confirmation_sheet.dart',
    ];

    for (final relativePath in files) {
      final content = await File(relativePath).readAsString();
      for (final marker in mojibakeMarkers) {
        expect(
          content.contains(marker),
          isFalse,
          reason: 'Found mojibake marker "$marker" in $relativePath',
        );
      }
    }
  });
}
