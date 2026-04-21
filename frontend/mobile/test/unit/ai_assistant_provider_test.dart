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
  }) async {
    if (endpoint == '/ai/chat') {
      final prompt = (body?['prompt'] ?? '').toString();
      final response =
          _responses[prompt] ??
          {'textReply': 'Echo: $prompt', 'emotion': 'neutral'};
      return {'data': response};
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

  test('startListening falls back gracefully when listen fails', () async {
    speechListenThrows = true;
    final provider = _buildProvider();

    await provider.startListening(source: 'test_listen_fail');

    expect(provider.state, AiState.idle);
    expect(provider.aiResponse, contains('Không thể bắt đầu thu âm'));
    expect(provider.isMascotVisible, isTrue);

    provider.dispose();
  });
}
