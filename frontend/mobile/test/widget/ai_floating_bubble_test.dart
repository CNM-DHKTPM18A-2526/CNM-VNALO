import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_floating_bubble.dart';
import 'package:vnalo_mobile/services/ai_service.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';

const MethodChannel _speechChannel = MethodChannel(
  'plugin.csdcorp.com/speech_to_text',
);
const MethodChannel _ttsChannel = MethodChannel('flutter_tts');

class _StubApiService extends ApiService {
  _StubApiService({Map<String, Map<String, dynamic>> responses = const {}})
    : _responses = responses,
      super(StorageService());

  final Map<String, Map<String, dynamic>> _responses;

  @override
  Future<Map<String, dynamic>> post(
    String baseUrl,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/ai/chat') {
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
}) {
  final aiService = AiService(_StubApiService(responses: responses));
  return AiAssistantProvider(aiService);
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

      await tester.enterText(
        find.byKey(const ValueKey('ai_chat_input')),
        'Xin chao',
      );
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
}
