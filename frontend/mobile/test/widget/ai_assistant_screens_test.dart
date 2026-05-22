import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/ai_conversation_screen.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/mascot_gallery_screen.dart';
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

  testWidgets('ai conversation screen shows standard send action for input', (
    tester,
  ) async {
    final provider = _buildProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(home: AiConversationScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('ai_conversation_input')),
      'Xin chao',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('ai_conversation_send')), findsOneWidget);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets('ai conversation screen surfaces clarification badge and actions', (
    tester,
  ) async {
    final provider = _buildProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(home: AiConversationScreen()),
      ),
    );

    provider.addActionFeedback(
      'Mình tìm thấy nhiều kết quả cho "Uyên". Bạn muốn chọn ai?',
      source:
          'ai_action_ambiguity.contact::Uy%C3%AAn%20L%C3%BD,Uy%C3%AAn%20Nguy%E1%BB%85n',
    );
    await tester.pumpAndSettle();

    expect(find.text('Cần làm rõ'), findsOneWidget);
    expect(find.text('Uyên Lý'), findsOneWidget);
    expect(find.text('Uyên Nguyễn'), findsOneWidget);
    expect(find.text('Nói rõ họ tên'), findsOneWidget);
    expect(find.text('Mở danh bạ'), findsOneWidget);

    provider.dispose();
  });

  testWidgets(
    'ai conversation screen hides mascot bubble while open and restores on close',
    (tester) async {
      final provider = _buildProvider();
      await provider.summonMascot(
        startListening: false,
        persist: true,
        source: 'conversation_surface_test',
      );
      expect(provider.isMascotVisible, isTrue);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: const MaterialApp(home: AiConversationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.isMascotVisible, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(provider.isMascotVisible, isTrue);

      provider.dispose();
    },
  );

  testWidgets(
    'ai conversation screen sends immediately and shows typing state',
    (tester) async {
      final provider = _buildProvider(
        responses: {
          'Gui nhanh': {
            'textReply': 'Đã nhận yêu cầu của bạn.',
            'emotion': 'neutral',
          },
        },
        responseDelay: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: const MaterialApp(home: AiConversationScreen()),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('ai_conversation_input')),
        'Gui nhanh',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ai_conversation_send')));
      await tester.pump();

      expect(find.text('Gui nhanh'), findsOneWidget);
      expect(find.text('AI đang soạn phản hồi...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Đã nhận yêu cầu của bạn.'), findsOneWidget);
      expect(find.text('AI đang soạn phản hồi...'), findsNothing);

      provider.dispose();
    },
  );

  testWidgets('ai conversation screen remains stable on compact viewport', (
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
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(home: AiConversationScreen()),
      ),
    );

    expect(
      find.byKey(const ValueKey('ai_conversation_appbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ai_conversation_input_bar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets('mascot gallery uses localized title and standard actions', (
    tester,
  ) async {
    final provider = _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: MascotGalleryScreen()),
      ),
    );

    expect(find.text('Chọn trợ lý AI'), findsOneWidget);
    expect(find.byKey(const ValueKey('mascot_gallery_pager')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mascot_gallery_primary_button')),
      findsOneWidget,
    );
    expect(find.text('Mascot hiện tại'), findsOneWidget);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });

  testWidgets(
    'ai conversation screen remains stable with large text scale on compact viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = _buildProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: MaterialApp(
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: const TextScaler.linear(1.4),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AiConversationScreen(),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('ai_conversation_appbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ai_conversation_input_bar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      provider.dispose();
    },
  );
}
