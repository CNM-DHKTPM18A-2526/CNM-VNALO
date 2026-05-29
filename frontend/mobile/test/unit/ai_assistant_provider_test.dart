import 'dart:async';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool speechInitAvailable = true;
  bool speechListenThrows = false;
  Duration speechStopDelay = Duration.zero;

  setUpAll(() {
    AppConfig.initialize(Environment.dev);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    speechInitAvailable = true;
    speechListenThrows = false;
    speechStopDelay = Duration.zero;

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
          if (speechStopDelay > Duration.zero) {
            await Future<void>.delayed(speechStopDelay);
          }
          return null;
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

  test('assistantActivityLabel mentions 10 second listening window', () async {
    final provider = _buildProvider();

    await provider.startListening(source: 'test');

    expect(provider.state, AiState.listening);
    expect(provider.assistantActivityLabel, contains('10'));
    expect(provider.assistantActivityLabel.toLowerCase(), contains('nghe'));

    await provider.stopListening(
      reason: 'label_check_cleanup',
      keepBubbleVisible: false,
    );
    provider.dispose();
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
    'submitTextPrompt records user entry before delayed AI response',
    () async {
      final provider = _buildProvider(
        responses: {
          'Ban oi': {'textReply': 'Mình đang ở đây.', 'emotion': 'neutral'},
        },
        responseDelay: const Duration(milliseconds: 250),
      );

      final submitFuture = provider.submitTextPrompt(
        'Ban oi',
        source: 'chat_board_test',
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(provider.conversationHistory, isNotEmpty);
      expect(provider.conversationHistory.last.role, AiConversationRole.user);
      expect(provider.conversationHistory.last.text, 'Ban oi');
      expect(provider.isAssistantGenerating, isTrue);

      await submitFuture;

      expect(provider.aiResponse, 'Mình đang ở đây.');

      provider.dispose();
    },
  );

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

  test('summon auto-listen does not toggle-off active listening', () async {
    final provider = _buildProvider();

    await provider.startListening(source: 'summon_guard_test');
    expect(provider.state, AiState.listening);

    await provider.summonMascot(
      startListening: true,
      persist: false,
      source: 'summon_guard_test',
    );

    expect(provider.state, AiState.listening);

    await provider.stopListening(
      reason: 'summon_guard_cleanup',
      keepBubbleVisible: false,
    );
    provider.dispose();
  });

  test('normalizeAiTextEncoding repairs single-pass mojibake', () {
    const raw = 'Đây là câu trả lời trong màn hình hội thoại.';
    final normalized = normalizeAiTextEncoding(raw);

    expect(normalized, 'Đây là câu trả lời trong màn hình hội thoại.');
  });

  test('normalizeAiTextEncoding repairs multi-pass mojibake', () {
    const raw = 'Không thể bắt đầu thu âm. Bạn thử lại.';
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

  test(
    'leaveConversationSurface can skip notify for dispose-safe teardown',
    () {
      final provider = _buildProvider();
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount += 1;
      });

      provider.enterConversationSurface(reason: 'test_enter');
      expect(notifyCount, 1);

      provider.leaveConversationSurface(
        reason: 'test_leave_no_notify',
        notify: false,
      );

      expect(notifyCount, 1);
      expect(provider.isMascotVisible, isFalse);

      provider.dispose();
    },
  );

  test('repairs mojibake AI responses before rendering and history', () async {
    final provider = _buildProvider(
      responses: {
        'kiem tra utf': {
          'textReply': 'Không thể bắt đầu thu âm. Bạn thử lại.',
          'emotion': 'neutral',
        },
      },
    );

    await provider.submitTextPrompt('kiem tra utf', source: 'chat_board_test');

    expect(provider.aiResponse, 'Không thể bắt đầu thu âm. Bạn thử lại.');
    expect(provider.conversationHistory.last.text, provider.aiResponse);

    provider.dispose();
  });

  test(
    'submitTextPrompt records user message before slow STT stop completes',
    () async {
      speechStopDelay = const Duration(milliseconds: 300);
      final provider = _buildProvider(
        responses: {
          'Xin chao': {'textReply': 'Chao ban', 'emotion': 'neutral'},
        },
        responseDelay: const Duration(milliseconds: 300),
      );

      await provider.startListening(source: 'preempt_listening_test');
      expect(provider.state, AiState.listening);

      unawaited(
        provider.submitTextPrompt(
          'Xin chao',
          source: 'ai_conversation_screen',
          surface: AiResponseSurface.conversation,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        provider.conversationHistory.any(
          (entry) =>
              entry.role == AiConversationRole.user && entry.text == 'Xin chao',
        ),
        isTrue,
      );
      expect(provider.state, AiState.thinking);

      await Future<void>.delayed(const Duration(milliseconds: 650));
      provider.dispose();
    },
  );

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
    'addActionFeedback preserves bubble surface for bubble action flow',
    () async {
      final provider = _buildProvider();

      await provider.summonMascot(
        startListening: false,
        persist: false,
        source: 'bubble_feedback_test',
      );
      await provider.submitTextPrompt(
        'mo chat voi uyen',
        source: 'bubble_chat_board',
        surface: AiResponseSurface.bubble,
      );

      provider.addActionFeedback(
        'Mình tìm thấy nhiều kết quả cho "Uyên". Bạn muốn chọn ai?',
        source: 'ai_action_ambiguity.contact',
        keepBubbleVisible: true,
      );

      expect(provider.lastResponseSurface, AiResponseSurface.bubble);
      expect(provider.shouldBubbleAutoShowResponse, isTrue);
      expect(provider.isMascotVisible, isTrue);

      provider.dispose();
    },
  );

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

  test('ambiguity feedback populates clarification state until resolved', () {
    final provider = _buildProvider();

    provider.addActionFeedback(
      'Mình tìm thấy nhiều kết quả cho "Uyên". Bạn muốn chọn ai?',
      source: 'ai_action_ambiguity.contact::Uy%C3%AAn%20L%C3%BD',
    );

    expect(provider.clarificationState, isNotNull);
    expect(provider.clarificationState!.isAmbiguous, isTrue);
    expect(provider.clarificationState!.candidates, const ['Uyên Lý']);

    provider.submitDisambiguationSelection('Uyên Lý');

    expect(provider.clarificationState, isNull);
    provider.dispose();
  });

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

  test(
    'submitTextPrompt with action command defers assistant text reply',
    () async {
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
        source: 'compose_command_defer_reply_test',
      );
      final command = await commandFuture;

      expect(command.command, 'COMPOSE_MESSAGE');
      expect(provider.aiResponse, isEmpty);

      final assistantReplies = provider.conversationHistory
          .where(
            (entry) =>
                entry.role == AiConversationRole.assistant &&
                entry.source == 'assistant_chat',
          )
          .toList(growable: false);
      expect(assistantReplies, isEmpty);
      expect(provider.conversationHistory.last.role, AiConversationRole.user);

      provider.dispose();
    },
  );

  test('action failure feedback replaces deferred command reply', () async {
    final provider = _buildProvider(
      responses: {
        'goi cho nguoi khong ton tai': {
          'textReply': 'Toi se chuan bi cuoc goi cho ban.',
          'emotion': 'neutral',
          'actionCommand': 'START_CALL',
          'actionParams': {'target': 'Nguoi Khong Ton Tai'},
        },
      },
    );

    final commandFuture = provider.systemActionStream.first;
    await provider.submitTextPrompt(
      'goi cho nguoi khong ton tai',
      source: 'missing_contact_action_test',
    );
    final command = await commandFuture;

    expect(command.command, 'START_CALL');
    expect(provider.aiResponse, isEmpty);
    expect(
      provider.lastConversationPreview,
      isNot(contains('Toi se chuan bi')),
    );

    provider.addActionFeedback(
      'Không tìm thấy người có tên "Nguoi Khong Ton Tai" trong danh bạ.',
      source: 'ai_action_missing.contact',
      keepBubbleVisible: true,
      responseSurface: AiResponseSurface.conversation,
    );

    expect(provider.aiResponse, contains('Không tìm thấy'));
    expect(provider.lastConversationPreview, contains('Không tìm thấy'));
    expect(provider.clarificationState?.message, contains('Không tìm thấy'));

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

  test('conversation history is isolated per auth user scope', () async {
    final provider = _buildProvider(
      responses: {
        'user-a': {'textReply': 'reply-a', 'emotion': 'neutral'},
        'user-b': {'textReply': 'reply-b', 'emotion': 'neutral'},
      },
    );

    await provider.bindAuthUser('user-a');
    await provider.submitTextPrompt('user-a', source: 'scope_test');

    expect(provider.conversationHistory, isNotEmpty);
    expect(
      provider.conversationHistory.any((entry) => entry.text == 'user-a'),
      isTrue,
    );

    await provider.bindAuthUser('user-b');

    expect(provider.conversationHistory, isEmpty);
    expect(provider.aiResponse, isEmpty);

    await provider.submitTextPrompt('user-b', source: 'scope_test');
    expect(
      provider.conversationHistory.any((entry) => entry.text == 'user-b'),
      isTrue,
    );
    expect(
      provider.conversationHistory.any((entry) => entry.text == 'user-a'),
      isFalse,
    );

    await provider.bindAuthUser('user-a');

    expect(
      provider.conversationHistory.any((entry) => entry.text == 'user-a'),
      isTrue,
    );
    expect(
      provider.conversationHistory.any((entry) => entry.text == 'user-b'),
      isFalse,
    );

    provider.dispose();
  });
}
