import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_prompt_chips.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_floating_bubble.dart';
import 'package:vnalo_mobile/features/discover/screens/discover_screen.dart';
import 'package:vnalo_mobile/services/ai_service.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';

const MethodChannel _speechChannel = MethodChannel(
  'plugin.csdcorp.com/speech_to_text',
);
const MethodChannel _ttsChannel = MethodChannel('flutter_tts');

class _StubApiService extends ApiService {
  _StubApiService({
    Map<String, Map<String, dynamic>> responses = const {},
    Duration responseDelay = Duration.zero,
  }) : _responses = responses,
       _responseDelay = responseDelay,
       super(StorageService());

  final Map<String, Map<String, dynamic>> _responses;
  final Duration _responseDelay;

  @override
  Future<Map<String, dynamic>> post(
    String baseUrl,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/ai/chat') {
      if (_responseDelay > Duration.zero) {
        await Future<void>.delayed(_responseDelay);
      }
      final prompt = (body?['prompt'] ?? '').toString();
      final response =
          _responses[prompt] ??
          {'textReply': 'Echo: $prompt', 'emotion': 'neutral'};
      return {'data': response};
    }

    if (endpoint == '/ai/history/backup') {
      return {
        'data': {'ok': true},
      };
    }

    return {};
  }
}

AiAssistantProvider _buildProvider({
  Map<String, Map<String, dynamic>> responses = const {},
  Duration responseDelay = Duration.zero,
}) {
  final aiService = AiService(
    _StubApiService(responses: responses, responseDelay: responseDelay),
  );
  return AiAssistantProvider(aiService, enableFlowLogging: false);
}

Widget _bubbleOverlayBuilder(BuildContext context, Widget? child) {
  return Stack(
    children: [child ?? const SizedBox.shrink(), const AiFloatingBubble()],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppConfig.initialize(Environment.dev);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(_speechChannel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'has_permission':
          return true;
        case 'locales':
          return ['vi_VN:Vietnamese (Vietnam)', 'en_US:English (US)'];
        case 'listen':
          return true;
        case 'stop':
        case 'cancel':
          return null;
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(_ttsChannel, (call) async {
      switch (call.method) {
        case 'awaitSpeakCompletion':
        case 'setLanguage':
        case 'setPitch':
        case 'setSpeechRate':
        case 'stop':
        case 'speak':
          return 1;
        default:
          return 1;
      }
    });
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_speechChannel, null);
    messenger.setMockMethodCallHandler(_ttsChannel, null);
  });

  testWidgets(
    'closing bubble board keeps it closed for current assistant response',
    (tester) async {
      final provider = _buildProvider(
        responses: {
          'Xin chao': {
            'textReply': 'Xin chao! Toi co the giup gi cho ban?',
            'emotion': 'joyful',
          },
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
          ),
        ),
      );

      await provider.summonMascot(
        startListening: false,
        persist: false,
        source: 'widget_test',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai_chat_board')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai_chat_send')), findsNothing);
      expect(find.byKey(const ValueKey('ai_chat_mic_idle')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('ai_chat_input')),
        'Xin chao',
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('ai_chat_send')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai_chat_mic_idle')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ai_chat_send')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);
      expect(provider.aiResponse, isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('ai_chat_close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai_chat_board')), findsNothing);
      expect(find.byKey(const ValueKey('ai_bubble_root')), findsOneWidget);

      provider.dispose();
    },
  );

  testWidgets('bubble board shows optimistic user entry and typing bubble', (
    tester,
  ) async {
    final provider = _buildProvider(
      responses: {
        'Ban oi': {'textReply': 'Minh dang o day.', 'emotion': 'neutral'},
      },
      responseDelay: const Duration(milliseconds: 300),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'typing_board_test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('ai_chat_input')),
      'Ban oi',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ai_chat_send')));
    await tester.pump();

    expect(find.text('Ban oi'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Minh dang o day.'), findsOneWidget);
    expect(provider.isAssistantGenerating, isFalse);

    provider.dispose();
  });

  testWidgets(
    'closing toggle while response is in flight keeps board collapsed',
    (tester) async {
      final provider = _buildProvider(
        responses: {
          'Ban oi': {'textReply': 'Minh dang o day.', 'emotion': 'neutral'},
        },
        responseDelay: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
          ),
        ),
      );

      await provider.summonMascot(
        startListening: false,
        persist: false,
        source: 'typing_board_close_test',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('ai_chat_input')),
        'Ban oi',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ai_chat_send')));
      await tester.pump();

      expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);
      expect(provider.isAssistantGenerating, isTrue);

      await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai_chat_board')), findsNothing);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai_chat_board')), findsNothing);
      expect(find.byKey(const ValueKey('ai_bubble_root')), findsOneWidget);

      provider.dispose();
    },
  );

  testWidgets('bubble board surfaces clarification badge and action chips', (
    tester,
  ) async {
    final provider = _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: const Scaffold(),
          builder: _bubbleOverlayBuilder,
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'clarification_board_test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await tester.pumpAndSettle();

    provider.addActionFeedback(
      'Tim thay nhieu ket qua cho "Uyen". Ban muon chon ai?',
      source: 'ai_action_ambiguity.contact::Uyen Ly,Uyen Nguyen',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);
    expect(find.text('Uyen Ly'), findsOneWidget);
    expect(find.text('Uyen Nguyen'), findsOneWidget);
    expect(find.text('Mo AI chat'), findsNothing);

    final candidateChip = find.byKey(const ValueKey('ai_board_chip_Uyen Ly'));
    expect(candidateChip, findsOneWidget);
    await tester.ensureVisible(candidateChip);
    await tester.tap(candidateChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      provider.conversationHistory.where(
        (entry) =>
            entry.role == AiConversationRole.user &&
            entry.text.contains('Uyen Ly'),
      ),
      isNotEmpty,
    );

    provider.dispose();
  });

  testWidgets('bubble board contacts shortcut closes board locally', (
    tester,
  ) async {
    final provider = _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: const Scaffold(),
          builder: _bubbleOverlayBuilder,
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'board_contacts_shortcut_test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await tester.pumpAndSettle();

    provider.addActionFeedback(
      'KhÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´ng tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬m thÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂºÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¥y liÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âªn hÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â»ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¡ trong danh bÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂºÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡.',
      source: 'ai_action_missing.contact',
      keepBubbleVisible: true,
      responseSurface: AiResponseSurface.bubble,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);
    expect(find.text(AiPromptChips.openContactsPrompt), findsOneWidget);

    await tester.tap(find.text(AiPromptChips.openContactsPrompt));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai_chat_board')), findsNothing);
    expect(find.byKey(const ValueKey('ai_bubble_root')), findsOneWidget);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets(
    'conversation screen response does not auto-open floating bubble board',
    (tester) async {
      final provider = _buildProvider(
        responses: {
          'Hoi trong man hinh tro ly': {
            'textReply': 'Day la phan hoi trong man hinh tro ly.',
            'emotion': 'neutral',
          },
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
          ),
        ),
      );

      await provider.submitTextPrompt(
        'Hoi trong man hinh tro ly',
        source: 'ai_conversation_screen',
      );
      await tester.pumpAndSettle();

      expect(provider.aiResponse, isNotEmpty);
      expect(provider.lastResponseSurface, AiResponseSurface.conversation);
      expect(provider.shouldBubbleAutoShowResponse, isFalse);
      expect(find.byKey(const ValueKey('ai_chat_board')), findsNothing);
      expect(find.byKey(const ValueKey('ai_bubble_root')), findsNothing);

      provider.dispose();
    },
  );

  testWidgets('bubble board submit keeps focus for continuous messaging', (
    tester,
  ) async {
    final provider = _buildProvider(
      responses: {
        'Mo phong dieu huong': {
          'textReply': 'Toi da xu ly yeu cau.',
          'emotion': 'neutral',
        },
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'focus_keep_test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await tester.pumpAndSettle();

    final inputFinder = find.byKey(const ValueKey('ai_chat_input'));
    await tester.tap(inputFinder);
    await tester.enterText(inputFinder, 'Mo phong dieu huong');
    await tester.pump();

    expect(tester.widget<TextField>(inputFinder).focusNode?.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('ai_chat_send')));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(inputFinder).focusNode?.hasFocus, isTrue);
    expect(provider.aiResponse, isNotEmpty);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets('bubble board remains stable on compact viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'compact_view_test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets('bubble board remains stable with large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
          ),
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'bubble_large_text_scale_test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai_chat_input')), findsOneWidget);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets('bubble board remains stable above keyboard on small viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    final provider = _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'keyboard_view_test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai_chat_board')), findsOneWidget);
    expect(find.byType(AiPromptChips), findsNothing);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets('bubble clarification remains tappable with large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: MaterialApp(
            home: const Scaffold(),
            builder: _bubbleOverlayBuilder,
          ),
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'clarification_large_text_scale_test',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai_bubble_toggle_board')));
    await tester.pumpAndSettle();

    provider.addActionFeedback(
      'Tim thay nhieu ket qua cho "Uyen". Ban muon chon ai?',
      source: 'ai_action_ambiguity.contact::Uyen Ly,Uyen Nguyen',
    );
    await tester.pumpAndSettle();

    expect(find.text('Uyen Ly'), findsOneWidget);
    final candidateChip = find.byKey(const ValueKey('ai_board_chip_Uyen Ly'));
    expect(candidateChip, findsOneWidget);
    await tester.ensureVisible(candidateChip);
    await tester.tap(candidateChip);
    await tester.pumpAndSettle();

    final selectedEntries =
        provider.conversationHistory
            .where(
              (entry) =>
                  entry.role == AiConversationRole.user &&
                  entry.text.contains('Uyen Ly'),
            )
            .toList();
    expect(selectedEntries, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bubble controls stay inside mascot visual bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [AiFloatingBubble()])),
        ),
      ),
    );

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'bubble_bounds_test',
    );
    await tester.pumpAndSettle();

    final bubbleRect = tester.getRect(
      find.byKey(const ValueKey('ai_bubble_root')),
    );
    final toggleRect = tester.getRect(
      find.byKey(const ValueKey('ai_bubble_toggle_board')),
    );
    final galleryRect = tester.getRect(
      find.byKey(const ValueKey('ai_bubble_open_gallery')),
    );

    expect(bubbleRect.contains(toggleRect.topLeft), isTrue);
    expect(bubbleRect.contains(toggleRect.bottomRight), isTrue);
    expect(bubbleRect.contains(galleryRect.topLeft), isTrue);
    expect(bubbleRect.contains(galleryRect.bottomRight), isTrue);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets('discover assistant entry summons visible mascot bubble', (
    tester,
  ) async {
    final provider = _buildProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(
          home: DiscoverScreen(),
          builder: _bubbleOverlayBuilder,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('discover_item_vnaloAi')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('ai_bubble_root')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await provider.stopListening(
      reason: 'discover_assistant_test_cleanup',
      keepBubbleVisible: false,
    );
    await tester.pump(const Duration(seconds: 3));
    provider.dispose();
  });
}
