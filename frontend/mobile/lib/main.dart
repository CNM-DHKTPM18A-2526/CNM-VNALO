import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/core/theme/app_theme.dart';
import 'package:vnalo_mobile/core/theme/theme_provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/splash_screen.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/auth_service.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';
import 'package:vnalo_mobile/services/user_service.dart';
import 'package:vnalo_mobile/services/local_sync_service.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
import 'package:vnalo_mobile/services/media_cache_service.dart';
import 'package:vnalo_mobile/features/timeline/providers/post_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/forward_provider.dart';
import 'package:vnalo_mobile/features/profile/providers/avatar_cache_provider.dart';
import 'package:vnalo_mobile/features/call/widgets/incoming_call_coordinator.dart';
import 'package:vnalo_mobile/features/call/services/group_call_tracker.dart';
import 'package:vnalo_mobile/services/notification_service.dart';
import 'package:vnalo_mobile/services/ai_service.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_compose_draft_bus.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_floating_bubble.dart';
import 'package:vnalo_mobile/features/contacts/providers/contact_provider.dart';
import 'package:vnalo_mobile/features/notifications/providers/notification_provider.dart';

// Global key to allow navigation from anywhere (e.g. IncomingCallCoordinator)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables if available. Missing .env should not crash
  // startup because values may be provided via --dart-define.
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      'No .env file found; falling back to --dart-define values where available.',
    );
  }

  // Initialize Firebase using robust options from AppConfig.
  // Using try-catch to safely handle Hot Restarts where the app might already be initialized native-side.
  try {
    await Firebase.initializeApp(options: AppConfig.getFirebaseOptions());
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
  
  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize the AppConfig with the environment specified in the build configuration.
  // Usage: flutter run --dart-define=ENV=dev
  const envName = String.fromEnvironment('ENV', defaultValue: 'dev');
  const coreServiceOverride = String.fromEnvironment(
    'CORE_SERVICE_URL',
    defaultValue: '',
  );
  const messageServiceOverride = String.fromEnvironment(
    'MESSAGE_SERVICE_URL',
    defaultValue: '',
  );
  const mediaServiceOverride = String.fromEnvironment(
    'MEDIA_SERVICE_URL',
    defaultValue: '',
  );
  const socketOverride = String.fromEnvironment('SOCKET_URL', defaultValue: '');
  const aiServiceOverride = String.fromEnvironment(
    'AI_SERVICE_URL',
    defaultValue: '',
  );

  final env = Environment.values.firstWhere(
    (e) => e.name == envName,
    orElse: () => Environment.dev,
  );
  AppConfig.initialize(
    env,
    coreServiceUrl: coreServiceOverride.isEmpty ? null : coreServiceOverride,
    messageServiceUrl:
        messageServiceOverride.isEmpty ? null : messageServiceOverride,
    mediaServiceUrl: mediaServiceOverride.isEmpty ? null : mediaServiceOverride,
    socketUrl: socketOverride.isEmpty ? null : socketOverride,
    aiServiceUrl: aiServiceOverride.isEmpty ? null : aiServiceOverride,
  );

  if (env == Environment.dev) {
    debugPrint('DEV endpoints resolved:');
    debugPrint('  core=${AppConfig.instance.coreServiceUrl}');
    debugPrint('  media=${AppConfig.instance.mediaServiceUrl}');
    debugPrint('  message=${AppConfig.instance.messageServiceUrl}');
    debugPrint('  socket=${AppConfig.instance.socketUrl}');
    if (AppConfig.isLikelyLocalOnlyHost(AppConfig.instance.coreServiceUrl)) {
      debugPrint(
        'DEV WARNING: CORE_SERVICE_URL is using 10.0.2.2/localhost. This only works on emulator or the same host. '
        'For a physical Android device, pass your computer LAN IP via --dart-define=CORE_SERVICE_URL=http://<LAN-IP>:8081/api/v1',
      );
    }
  }

  unawaited(NotificationService().ensureInitialized());

  runApp(const VnaloApp());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background handler. 
  // Using try-catch to avoid duplicate app errors in background tasks.
  try {
    await Firebase.initializeApp(options: AppConfig.getFirebaseOptions());
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
  debugPrint('Handling a background message: ${message.messageId}');
  
  // Hand off to NotificationService's static background handler logic
  await NotificationService.handleBackgroundCallSignal(message);
}


class VnaloApp extends StatelessWidget {
  const VnaloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => StorageService()),
        ChangeNotifierProvider<SocketService>(create: (_) => SocketService()),
        Provider<ApiService>(
          create: (context) => ApiService(context.read<StorageService>()),
        ),
        Provider<AuthService>(
          create: (context) => AuthService(context.read<ApiService>()),
        ),
        Provider<ChatService>(
          create: (context) => ChatService(context.read<ApiService>()),
        ),
        Provider<FriendService>(
          create: (context) => FriendService(context.read<ApiService>()),
        ),
        Provider<UserService>(
          create: (context) => UserService(context.read<ApiService>()),
        ),
        Provider<LocalDatabase>(
          create: (_) => LocalDatabase(),
          dispose: (_, db) => db.close(),
        ),
        Provider<LocalSyncService>(
          create:
              (context) => LocalSyncService(
                db: context.read<LocalDatabase>(),
                chatService: context.read<ChatService>(),
                friendService: context.read<FriendService>(),
                storageService: context.read<StorageService>(),
              ), // Moved sync logic to AuthProvider
        ),
        Provider<MediaService>(
          create: (context) => MediaService(context.read<ApiService>()),
        ),
        Provider<MediaCacheService>(
          create: (context) => MediaCacheService(
            context.read<LocalDatabase>(),
            context.read<StorageService>(),
          ),
        ),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<AiService>(
          create: (context) => AiService(context.read<ApiService>()),
        ),
        Provider<AiComposeDraftBus>(
          create: (_) => AiComposeDraftBus(),
          dispose: (_, bus) => bus.close(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..initialize(),
        ),
        ChangeNotifierProvider<AvatarCacheProvider>(
          create: (_) => AvatarCacheProvider(),
        ),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()..initialize(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create:
              (context) => AuthProvider(
                context.read<AuthService>(),
                context.read<StorageService>(),
                context.read<SocketService>(),
                context.read<LocalSyncService>(),
              ),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, SocketService, ContactProvider>(
          create: (ctx) => ContactProvider(
            ctx.read<FriendService>(),
            ctx.read<SocketService>(),
          ),
          update: (ctx, auth, socket, contact) {
            final currentContact = contact ??
                ContactProvider(
                  ctx.read<FriendService>(),
                  socket,
                );
            currentContact.update(auth.user?.id, socket);
            return currentContact;
          },
        ),
        ChangeNotifierProxyProvider2<AuthProvider, SocketService, ChatProvider>(
          create: (context) => ChatProvider(
            chatService: context.read<ChatService>(),
            socketService: context.read<SocketService>(),
            mediaService: context.read<MediaService>(),
            db: context.read<LocalDatabase>(),
            notificationService: context.read<NotificationService>(),
            aiComposeDraftBus: context.read<AiComposeDraftBus>(),
          ),
          update: (context, auth, socket, chat) {
            final currentChat = chat ??
                ChatProvider(
                  chatService: context.read<ChatService>(),
                  socketService: socket,
                  mediaService: context.read<MediaService>(),
                  db: context.read<LocalDatabase>(),
                  notificationService: context.read<NotificationService>(),
                  aiComposeDraftBus: context.read<AiComposeDraftBus>(),
                );
            currentChat.update(auth.user?.id, socket);
            return currentChat;
          },
        ),
        ChangeNotifierProvider<PostProvider>(
          create: (_) => PostProvider(),
        ),
        ChangeNotifierProxyProvider<ChatProvider, ForwardProvider>(
          create: (context) => ForwardProvider(context.read<ChatProvider>()),
          update: (context, chat, previous) => previous ?? ForwardProvider(chat),
        ),
        ChangeNotifierProxyProvider<AuthProvider, AiAssistantProvider>(
          create:
              (context) =>
                  AiAssistantProvider(context.read<AiService>()),
          update: (context, auth, previous) {
            final provider =
                previous ?? AiAssistantProvider(context.read<AiService>());
            unawaited(provider.bindAuthUser(auth.scopedUserId));
            return provider;
          },
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (context) => NotificationProvider(context.read<ApiService>()),
        ),
        ChangeNotifierProvider<GroupCallTracker>(
          create: (_) => GroupCallTracker(),
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (_, themeProvider, languageProvider, __) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'VNALO',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              final content = child ?? const SizedBox.shrink();
              return Stack(
                children: [
                  content,
                  const IncomingCallCoordinator(),
                  const AiFloatingBubble(),
                ],
              );
            },
            locale:
                languageProvider.language == AppLanguage.vi
                    ? const Locale('vi', 'VN')
                    : const Locale('en', 'US'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
