import 'package:vnalo_mobile/config/env.dart';

// AppConfig is a singleton class that holds the configuration for the app. It is initialized with the environment configuration and can be accessed throughout the app.
class AppConfig {
  static EnvConfig? _config;

  static const _defaultDevCore = 'http://10.0.2.2:8081/api/v1';

  /// Returns the current configuration.
  /// Throws [StateError] if [initialize] has not been called yet.
  static EnvConfig get instance {
    const errorMessage =
        'AppConfig.initialize() must be called before accessing AppConfig.instance. '
        'Ensure main() calls AppConfig.initialize() before runApp().';

    assert(
      _config != null,
      errorMessage,
    );

    if (_config == null) {
      throw StateError(errorMessage);
    }

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
        final resolvedCore = _normalizeApiBaseUrl(coreServiceUrl ?? _defaultDevCore);
        final coreUri = Uri.parse(resolvedCore);
        _config = EnvConfig(
          environment: Environment.dev,
          coreServiceUrl: resolvedCore,
          messageServiceUrl:
              _normalizeApiBaseUrl(
                messageServiceUrl ?? _buildServiceUrl(coreUri, 3000, '/api/v1'),
              ),
          mediaServiceUrl:
              _normalizeApiBaseUrl(
                mediaServiceUrl ?? _buildServiceUrl(coreUri, 8083, '/api/v1'),
              ),
          socketUrl: _normalizeSocketUrl(
            socketUrl ?? _buildServiceUrl(coreUri, 3000, ''),
          ),
          enableLogging: true,
        );
        break;

      case Environment.staging:
        _config = EnvConfig(
          environment: Environment.staging,
          coreServiceUrl: _normalizeApiBaseUrl(
            coreServiceUrl ?? 'https://staging-api.vnalo.com/api/v1',
          ),
          messageServiceUrl:
              _normalizeApiBaseUrl(
                messageServiceUrl ?? 'https://staging-msg.vnalo.com/api/v1',
              ),
          mediaServiceUrl:
            _normalizeApiBaseUrl(
              mediaServiceUrl ?? 'https://staging-media.vnalo.com/api/v1',
            ),
          socketUrl: _normalizeSocketUrl(
            socketUrl ?? 'https://staging-msg.vnalo.com',
          ),
          enableLogging: true,
          enableCrashlytics: true,
        );
        break;

      case Environment.production:
        _config = EnvConfig(
          environment: Environment.production,
          coreServiceUrl: _normalizeApiBaseUrl(
            coreServiceUrl ?? 'https://api.vnalo.com/api/v1',
          ),
          messageServiceUrl:
              _normalizeApiBaseUrl(
                messageServiceUrl ?? 'https://msg.vnalo.com/api/v1',
              ),
          mediaServiceUrl: _normalizeApiBaseUrl(
            mediaServiceUrl ?? 'https://media.vnalo.com/api/v1',
          ),
          socketUrl: _normalizeSocketUrl(socketUrl ?? 'https://msg.vnalo.com'),
          enableCrashlytics: true,
        );
        break;
    }
  }

  static bool isLikelyLocalOnlyHost(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return false;
    }

    final host = uri.host.toLowerCase();
    return host == '10.0.2.2' ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1';
  }

  static String _buildServiceUrl(Uri coreUri, int port, String path) {
    return Uri(
      scheme: coreUri.scheme,
      host: coreUri.host,
      port: port,
      path: path,
    ).toString();
  }

  static String _normalizeApiBaseUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return trimmed;
    }

    var normalizedPath = uri.path.trim();
    if (normalizedPath.isEmpty || normalizedPath == '/') {
      normalizedPath = '/api/v1';
    } else {
      normalizedPath = normalizedPath.replaceAll(RegExp(r'/+$'), '');
      if (normalizedPath.endsWith('/api/v')) {
        normalizedPath = '${normalizedPath}1';
      }
      if (!normalizedPath.endsWith('/api/v1')) {
        if (normalizedPath.contains('/api/v')) {
          normalizedPath = normalizedPath.replaceFirst(RegExp(r'/api/v\d*.*$'), '/api/v1');
        } else {
          normalizedPath = '$normalizedPath/api/v1';
        }
      }
    }

    return uri
        .replace(path: normalizedPath)
        .toString()
        .replaceAll(RegExp(r'/+$'), '');
  }

  static String _normalizeSocketUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return trimmed;
    }

    return uri.replace(path: '').toString().replaceAll(RegExp(r'/+$'), '');
  }
}
