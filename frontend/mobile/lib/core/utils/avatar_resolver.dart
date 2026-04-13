import 'package:vnalo_mobile/config/app_config.dart';

/// Centralized avatar URL resolver.
///
/// Accepts absolute URLs, relative paths, or null and produces a fully
/// qualified URL ready for [CachedNetworkImage], or `null` when the
/// input cannot be resolved (which triggers the initials fallback in
/// [AvatarWidget]).
class AvatarResolver {
  AvatarResolver._();

  static final RegExp _saveUrlPattern = RegExp(r'^(.*/media/)([^/]+)/save/?$');

  /// Resolve [raw] to an absolute URL.
  ///
  /// * `null` / empty ➜ returns `null`
  /// * Already has scheme (http/https) ➜ passthrough
  /// * Relative path (e.g. `/media/abc.jpg`) ➜ prepend media-service host
  static String? resolveUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    final normalized = _normalizeSaveUrl(value);

    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      return normalized;
    }

    // Build base from media-service URL, fallback to core-service URL.
    if (!AppConfig.isInitialized) return normalized;

    final mediaUri = Uri.parse(AppConfig.instance.mediaServiceUrl);
    final coreUri = Uri.parse(AppConfig.instance.coreServiceUrl);
    final host = mediaUri.host.isNotEmpty ? mediaUri.host : coreUri.host;
    final scheme =
        mediaUri.scheme.isNotEmpty ? mediaUri.scheme : coreUri.scheme;
    if (host.isEmpty || scheme.isEmpty) return normalized;

    final path = normalized.startsWith('/') ? normalized : '/$normalized';
    return Uri(
      scheme: scheme,
      host: host,
      port: mediaUri.hasPort ? mediaUri.port : null,
      path: path,
    ).toString();
  }

  static String _normalizeSaveUrl(String input) {
    final match = _saveUrlPattern.firstMatch(input);
    if (match == null) return input;
    final prefix = match.group(1)!;
    final mediaId = match.group(2)!;
    return '${prefix}public/$mediaId';
  }
}
