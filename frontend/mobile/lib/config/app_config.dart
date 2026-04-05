import 'package:vnalo_mobile/config/env.dart';

// AppConfig is a singleton class that holds the configuration for the app. It is initialized with the environment configuration and can be accessed throughout the app.
class AppConfig {
  static EnvConfig? _config;

  /// Returns the current configuration.
  /// Throws [StateError] if [initialize] has not been called yet.
  static EnvConfig get instance {
    assert(
      _config != null,
      'AppConfig.initialize() must be called before accessing AppConfig.instance. '
      'Ensure main() calls AppConfig.initialize() before runApp().',
    );
    return _config!;
  }

  /// Whether [initialize] has been called at least once.
  static bool get isInitialized => _config != null;

  /// Initializes the AppConfig with the given environment.
  /// This method should be called at the start of the app before accessing the configuration.
  static void initialize(
    Environment env, {
    String? coreServiceUrl,
    String? messageServiceUrl,
    String? mediaServiceUrl,
    String? socketUrl,
  }) {
    switch (env) {
      case Environment.dev:
        _config = EnvConfig(
          environment: Environment.dev,
          coreServiceUrl: coreServiceUrl ?? 'http://10.0.2.2:8081/api/v1',
          messageServiceUrl: messageServiceUrl ?? 'http://10.0.2.2:3000/api/v1',
          mediaServiceUrl: mediaServiceUrl ?? 'http://10.0.2.2:8083/api/v1',
          socketUrl: socketUrl ?? 'http://10.0.2.2:3000',
          enableLogging: true,
        );
        break;

      case Environment.staging:
        _config = EnvConfig(
          environment: Environment.staging,
          coreServiceUrl:
              coreServiceUrl ?? 'https://staging-api.vnalo.com/api/v1',
          messageServiceUrl:
              messageServiceUrl ?? 'https://staging-msg.vnalo.com/api/v1',
          mediaServiceUrl:
            mediaServiceUrl ?? 'https://staging-media.vnalo.com/api/v1',
          socketUrl: socketUrl ?? 'https://staging-msg.vnalo.com',
          enableLogging: true,
          enableCrashlytics: true,
        );
        break;

      case Environment.production:
        _config = EnvConfig(
          environment: Environment.production,
          coreServiceUrl: coreServiceUrl ?? 'https://api.vnalo.com/api/v1',
          messageServiceUrl:
              messageServiceUrl ?? 'https://msg.vnalo.com/api/v1',
          mediaServiceUrl: mediaServiceUrl ?? 'https://media.vnalo.com/api/v1',
          socketUrl: socketUrl ?? 'https://msg.vnalo.com',
          enableCrashlytics: true,
        );
        break;
    }
  }
}
