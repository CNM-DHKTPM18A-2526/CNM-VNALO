import 'package:vnalo_mobile/config/env.dart';

// AppConfig is a singleton class that holds the configuration for the app. It is initialized with the environment configuration and can be accessed throughout the app.
class AppConfig {
  static late EnvConfig _config;

  static EnvConfig get instance => _config;

  /// Initializes the AppConfig with the given environment.
  /// This method should be called at the start of the app before accessing the configuration.
  static void initialize(Environment env) {
    switch (env) {
      case Environment.dev:
        _config = const EnvConfig(
          environment: Environment.dev,
          coreServiceUrl: 'http://10.0.2.2:8081/api/v1',
          messageServiceUrl: 'http://10.0.2.2:3000/api/v1',
          socketUrl: 'http://10.0.2.2:3000',
          enableLogging: true,
        );
        break;

      case Environment.staging:
        _config = const EnvConfig(
          environment: Environment.staging,
          coreServiceUrl: 'https://staging-api.vnalo.com/api/v1',
          messageServiceUrl: 'https://staging-msg.vnalo.com/api/v1',
          socketUrl: 'https://staging-msg.vnalo.com',
          enableLogging: true,
          enableCrashlytics: true,
        );
        break;

      case Environment.production:
        _config = const EnvConfig(
          environment: Environment.production,
          coreServiceUrl: 'https://api.vnalo.com/api/v1',
          messageServiceUrl: 'https://msg.vnalo.com/api/v1',
          socketUrl: 'https://msg.vnalo.com',
          enableCrashlytics: true,
        );
        break;
    }
  }
}
