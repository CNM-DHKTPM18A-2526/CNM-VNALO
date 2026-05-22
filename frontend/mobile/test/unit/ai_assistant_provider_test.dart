import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
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
  return AiAssistantProvider(aiService, enableFlowLogging: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool speechInitAvailable = true;
  bool speechListenThrows = false;

  setUpAll(() {
    AppConfig.initialize(Environment.dev);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    speechInitAvailable = true;
    speechListenThrows = false;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(_speechChannel, (call) async {
      switch (call.method) {
        case 'initialize':
          return speechInitAvailable;
        case 'has_permission':
          return true;
        case 'locales':
          return ['vi_VN:Vietnamese (Vietnam)', 'en_US:English (US)'];
        case 'listen':
          if (speechListenThrows) {
            throw PlatformException(
              code: 'listen_error',
              message: 'listen failed',
            );
          }
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

  test('manual stop keeps bubble visible for quick retry', () async {
    final provider = _buildProvider();

    await provider.summonMascot(
      startListening: false,
      persist: false,
      source: 'test',
    );
    await provider.startListening(source: 'test');

    expect(provider.state, AiState.listening);

    await provider.stopListening(reason: 'manual', keepBubbleVisible: true);

    expect(provider.state, AiState.idle);
    expect(provider.provisionallyVisible, isTrue);
    expect(provider.isMascotVisible, isTrue);

    provider.dispose();
  });

  test(
    'stopListening can collapse contextual visibility when requested',
    () async {
      final provider = _buildProvider();

      await provider.summonMascot(
        startListening: false,
        persist: false,
        source: 'test',
      );
      await provider.startListening(source: 'test');

      await provider.stopListening(reason: 'manual', keepBubbleVisible: false);

      expect(provider.state, AiState.idle);
      expect(provider.isMascotVisible, isFalse);

      provider.dispose();
    },
  );

  test('submitTextPrompt updates prompt and response', () async {
    final provider = _buildProvider(
      responses: {
        'Xin chao': {
          'textReply': 'Xin chao! Toi co the giup gi cho ban?',
          'emotion': 'joyful',
        },
      },
    );

    await provider.submitTextPrompt('Xin chao', source: 'chat_board_test');

    expect(provider.lastUserPrompt, 'Xin chao');
    expect(provider.aiResponse, 'Xin chao! Toi co the giup gi cho ban?');
    expect(provider.state, AiState.idle);
    expect(provider.isMascotVisible, isTrue);

    provider.dispose();
  });

  test(
    'submitTextPrompt surface override takes precedence over source',
    () async {
      final provider = _buildProvider(
        responses: {
          'surface override': {
            'textReply': 'Đây là phản hồi test surface.',
            'emotion': 'neutral',
          },
        },
      );

      await provider.submitTextPrompt(
        'surface override',
        source: 'bubble_chat_board',
        surface: AiResponseSurface.conversation,
      );

      expect(provider.lastResponseSurface, AiResponseSurface.conversation);
      expect(provider.shouldBubbleAutoShowResponse, isFalse);
      expect(provider.isMascotVisible, isFalse);

      provider.dispose();
    },
  );

  test(
    'startListening surface override prevents bubble auto-visibility',
    () async {
      final provider = _buildProvider();

      await provider.startListening(
        source: 'bubble_long_press',
        surface: AiResponseSurface.conversation,
      );

      expect(provider.lastResponseSurface, AiResponseSurface.conversation);
      expect(provider.isMascotVisible, isFalse);

      await provider.stopListening(
        reason: 'override_cleanup',
        keepBubbleVisible: false,
      );
      provider.dispose();
    },
  );

  test('normalizeAiTextEncoding repairs single-pass mojibake', () {
    const raw = 'ÄÃ¢y lÃ  cÃ¢u tráº£ lá»i trong mÃ n hÃ¬nh há»™i thoáº¡i.';
    final normalized = normalizeAiTextEncoding(raw);

    expect(normalized, 'Đây là câu trả lời trong màn hình hội thoại.');
  });

  test('normalizeAiTextEncoding repairs multi-pass mojibake', () {
    const raw =
        'KhÃƒÂ´ng thÃ¡Â»Æ’ bÃ¡ÂºÂ¯t Ã„â€˜Ã¡ÂºÂ§u thu ÃƒÂ¢m. BÃ¡ÂºÂ¡n thÃ¡Â»Â­ lÃ¡ÂºÂ¡i.';
    final normalized = normalizeAiTextEncoding(raw);

    expect(normalized, 'Không thể bắt đầu thu âm. Bạn thử lại.');
  });

  test('conversation screen prompt does not force bubble auto board', () async {
    final provider = _buildProvider(
      responses: {
        'Mo lai noi dung nay': {
          'textReply': 'Đây là câu trả lời trong màn hình hội thoại.',
          'emotion': 'neutral',
        },
      },
    );

    await provider.submitTextPrompt(
      'Mo lai noi dung nay',
      source: 'ai_conversation_screen',
    );

    expect(provider.aiResponse, 'Đây là câu trả lời trong màn hình hội thoại.');
    expect(provider.lastResponseSurface, AiResponseSurface.conversation);
    expect(provider.shouldBubbleAutoShowResponse, isFalse);
    expect(provider.isMascotVisible, isFalse);

    provider.dispose();
  });

  test('repairs mojibake AI responses before rendering and history', () async {
    final provider = _buildProvider(
      responses: {
        'kiem tra utf': {
          'textReply': 'KhÃ´ng thá»ƒ báº¯t Ä‘áº§u thu Ã¢m. Báº¡n thá»­ láº¡i.',
          'emotion': 'neutral',
        },
      },
    );

    await provider.submitTextPrompt('kiem tra utf', source: 'chat_board_test');

    expect(provider.aiResponse, 'Không thể bắt đầu thu âm. Bạn thử lại.');
    expect(provider.conversationHistory.last.text, provider.aiResponse);

    provider.dispose();
  });

  test('conversation mic keeps bubble hidden while listening', () async {
    final provider = _buildProvider();

    await provider.startListening(source: 'conversation_screen_mic');

    expect(provider.state, AiState.listening);
    expect(provider.lastResponseSurface, AiResponseSurface.conversation);
    expect(provider.isMascotVisible, isFalse);

    await provider.stopListening(
      reason: 'conversation_screen_mic.toggle_stop',
      keepBubbleVisible: false,
    );

    expect(provider.isMascotVisible, isFalse);

    provider.dispose();
  });

  test('startListening falls back gracefully when listen fails', () async {
    speechListenThrows = true;
    final provider = _buildProvider();

    await provider.startListening(source: 'test_listen_fail');

    expect(provider.state, AiState.idle);
    expect(provider.aiResponse, contains('Không thể bắt đầu thu âm'));
    expect(provider.isMascotVisible, isTrue);

    provider.dispose();
  });

  test(
    'conversation mic listen failure keeps floating bubble hidden',
    () async {
      speechListenThrows = true;
      final provider = _buildProvider();

      await provider.startListening(source: 'conversation_screen_mic');

      expect(provider.state, AiState.idle);
      expect(provider.lastResponseSurface, AiResponseSurface.conversation);
      expect(provider.aiResponse, contains('Không thể bắt đầu thu âm'));
      expect(provider.shouldBubbleAutoShowResponse, isFalse);
      expect(provider.isMascotVisible, isFalse);
      expect(provider.provisionallyVisible, isFalse);

      provider.dispose();
    },
  );

  test('clearAiResponse keeps bubble visible for quick follow-up', () async {
    final provider = _buildProvider(
      responses: {
        'Xin chao': {
          'textReply': 'Xin chao! Toi co the giup gi cho ban?',
          'emotion': 'joyful',
        },
      },
    );

    await provider.submitTextPrompt('Xin chao', source: 'chat_board_test');
    provider.clearAiResponse();

    expect(provider.aiResponse, isEmpty);
    expect(provider.isMascotVisible, isTrue);
    expect(provider.provisionallyVisible, isTrue);

    provider.dispose();
  });

  test('addActionFeedback appends assistant feedback into history', () {
    final provider = _buildProvider();

    provider.addActionFeedback('Không tìm thấy "An" trong danh bạ.');

    expect(provider.aiResponse, 'Không tìm thấy "An" trong danh bạ.');
    expect(provider.conversationHistory, isNotEmpty);
    expect(
      provider.conversationHistory.last.role,
      AiConversationRole.assistant,
    );
    expect(
      provider.conversationHistory.last.text,
      'Không tìm thấy "An" trong danh bạ.',
    );

    provider.dispose();
  });

  test('addActionFeedback keeps source metadata for UI disambiguation', () {
    final provider = _buildProvider();

    provider.addActionFeedback(
      'Mình tìm thấy nhiều kết quả cho "Uyên". Bạn muốn chọn ai?',
      source: 'ai_action_ambiguity.contact',
    );

    final mapped = provider.getHistoryAsMessages('current-user');
    expect(mapped, isNotEmpty);
    expect(mapped.last.clientMessageId, 'ai_action_ambiguity.contact');

    provider.dispose();
  });

  test(
    'submitDisambiguationSelection emits selection and stores user choice',
    () async {
      final provider = _buildProvider();

      final selectionFuture = provider.disambiguationSelectionStream.first;
      provider.submitDisambiguationSelection('Uyên Lý');
      final selection = await selectionFuture;

      expect(selection.selectedName, 'Uyên Lý');
      expect(provider.conversationHistory.last.role, AiConversationRole.user);
      expect(provider.conversationHistory.last.text, 'Mình muốn chọn Uyên Lý');

      provider.dispose();
    },
  );

  test('first interaction lazily creates AI conversation thread', () async {
    final provider = _buildProvider();

    expect(provider.hasConversation, isFalse);
    await provider.startListening(source: 'lazy_create_test');

    expect(provider.hasConversation, isTrue);

    provider.dispose();
  });

  test('submitTextPrompt stores local-first conversation history', () async {
    final provider = _buildProvider(
      responses: {
        'ban la ai': {
          'textReply': 'Toi la tro ly AI cua ban.',
          'emotion': 'neutral',
        },
      },
    );

    await provider.submitTextPrompt('ban la ai', source: 'history_test');

    expect(provider.conversationHistory.length, greaterThanOrEqualTo(2));
    expect(provider.lastConversationPreview, contains('AI:'));

    provider.dispose();
  });

  test('submitTextPrompt emits compose command', () async {
    final provider = _buildProvider(
      responses: {
        'nhan tin cho An la toi den tre': {
          'textReply': 'Toi se mo khung soan tin cho ban.',
          'emotion': 'neutral',
          'actionCommand': 'COMPOSE_MESSAGE',
          'actionParams': {'recipient': 'An', 'content': 'toi den tre'},
        },
      },
    );

    final commandFuture = provider.systemActionStream.first;
    await provider.submitTextPrompt(
      'nhan tin cho An la toi den tre',
      source: 'compose_command_test',
    );
    final command = await commandFuture;

    expect(command.command, 'COMPOSE_MESSAGE');
    expect(command.params, isA<Map>());
    expect((command.params as Map)['recipient'], 'An');
    expect((command.params as Map)['content'], 'toi den tre');

    provider.dispose();
  });

  test('submitTextPrompt emits start call command', () async {
    final provider = _buildProvider(
      responses: {
        'goi video cho Minh Anh': {
          'textReply': 'Toi se bat dau cuoc goi video cho ban.',
          'emotion': 'neutral',
          'actionCommand': 'START_CALL',
          'actionParams': {'target': 'Minh Anh', 'callType': 'video'},
        },
      },
    );

    final commandFuture = provider.systemActionStream.first;
    await provider.submitTextPrompt(
      'goi video cho Minh Anh',
      source: 'call_command_test',
    );
    final command = await commandFuture;

    expect(command.command, 'START_CALL');
    expect(command.params, isA<Map>());
    expect((command.params as Map)['target'], 'Minh Anh');
    expect((command.params as Map)['callType'], 'video');

    provider.dispose();
  });

  test('cloud backup option can be toggled', () async {
    final provider = _buildProvider();

    expect(provider.cloudBackupEnabled, isFalse);
    await provider.setCloudBackupEnabled(true, reason: 'unit_test');

    expect(provider.cloudBackupEnabled, isTrue);

    provider.dispose();
  });
}
