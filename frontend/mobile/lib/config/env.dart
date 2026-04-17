enum Environment { dev, staging, production }

class EnvConfig {
  final Environment environment;
  final String coreServiceUrl;
  final String mediaServiceUrl;
  final String socketUrl;
  final String aiServiceUrl;
  final bool enableLogging;
  final bool enableCrashlytics;

  const EnvConfig({
    required this.environment,
    required this.coreServiceUrl,
    required this.messageServiceUrl,
    required this.mediaServiceUrl,
    required this.socketUrl,
    required this.aiServiceUrl,
    this.enableLogging = false,
    this.enableCrashlytics = false,
  });

  bool get isDev => environment == Environment.dev;
  bool get isProd => environment == Environment.production;
}
