import 'package:flutter/material.dart';
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
import 'package:vnalo_mobile/features/timeline/providers/post_provider.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/auth_service.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';
import 'package:vnalo_mobile/services/user_service.dart';
import 'package:vnalo_mobile/services/local_sync_service.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

  final env = Environment.values.firstWhere(
    (e) => e.name == envName,
    orElse: () => Environment.dev,
  );
  AppConfig.initialize(
    env,
    coreServiceUrl: coreServiceOverride.isEmpty ? null : coreServiceOverride,
    messageServiceUrl:
        messageServiceOverride.isEmpty ? null : messageServiceOverride,
    mediaServiceUrl:
      mediaServiceOverride.isEmpty ? null : mediaServiceOverride,
    socketUrl: socketOverride.isEmpty ? null : socketOverride,
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
  runApp(const VnaloApp());
}

class VnaloApp extends StatelessWidget {
  const VnaloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<SocketService>(create: (_) => SocketService()),
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
          create: (context) => LocalSyncService(
            db: context.read<LocalDatabase>(),
            chatService: context.read<ChatService>(),
            friendService: context.read<FriendService>(),
          ), // Moved sync logic to AuthProvider
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..initialize(),
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
        ChangeNotifierProvider<ChatProvider>(
          create:
              (context) => ChatProvider(
                context.read<ChatService>(),
                context.read<SocketService>(),
              ),
        ),
        ChangeNotifierProvider<PostProvider>(
          create: (_) => PostProvider(),
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (_, themeProvider, languageProvider, __) {
          return MaterialApp(
            title: 'Vnalo',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: languageProvider.language == AppLanguage.vi
                ? const Locale('vi', 'VN')
                : const Locale('en', 'US'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('vi', 'VN'),
              Locale('en', 'US'),
            ],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
