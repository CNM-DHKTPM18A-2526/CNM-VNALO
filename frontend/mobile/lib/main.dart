import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/core/theme/app_theme.dart';
import 'package:vnalo_mobile/core/theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the AppConfig with the environment specified in the build configuration.
  // Usage: flutter run --dart-define=ENV=dev
  const envName = String.fromEnvironment('ENV', defaultValue: 'dev');
  final env = Environment.values.firstWhere(
    (e) => e.name == envName,
    orElse: () => Environment.dev,
  );
  AppConfig.initialize(env);
  runApp(const VnaloApp());
}

class VnaloApp extends StatelessWidget {
  const VnaloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider()..initialize(),
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'VNALO',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          // home: const SplashScreen(),
        ),
      ),
    );
  }
}
