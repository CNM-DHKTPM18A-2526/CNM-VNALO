import 'package:vnalo_mobile/config/app_config.dart';

/// Centralized avatar URL resolver.
///
/// Accepts absolute URLs, relative paths, or null and produces a fully
/// qualified URL ready for [CachedNetworkImage], or `null` when the
/// input cannot be resolved (which triggers the initials fallback in
/// [AvatarWidget]).
class AvatarResolver {
  AvatarResolver._();

  static final RegExp _saveUrlPattern = RegExp(
    r'^(.*/media/)([^/?]+)/save/?(?:\?([^#]*))?$',
  );

  /// Checks if [url] points to the internal media service.
  static bool isInternalUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    // Relative paths are always internal
    if (url.startsWith('/')) return true;

    if (!AppConfig.isInitialized) return false;
    
    final mediaBase = AppConfig.instance.mediaServiceUrl.replaceAll(RegExp(r'/+$'), '');
    final normalizedUrl = url.replaceAll(RegExp(r'/+$'), '');

    if (normalizedUrl.startsWith(mediaBase)) return true;

    // Additional check for internal media service path patterns
    // This handles cases where the host might change (IP vs domain) but it's clearly our service
    if (normalizedUrl.contains('/api/v1/media/')) return true;

    // Additional check for IP-based matching
    final mediaUri = Uri.tryParse(mediaBase);
    final inputUri = Uri.tryParse(url);
    if (mediaUri != null && inputUri != null) {
      if (mediaUri.host == inputUri.host && mediaUri.port == inputUri.port) return true;
    }

    return false;
  }

  /// Resolve [raw] to an absolute URL.
  ///
  /// * `null` / empty ➜ returns `null`
  /// * Already has scheme (http/https) ➜ passthrough
  /// * Relative path (e.g. `/media/abc.jpg`) ➜ prepend media-service host
  static String? resolveUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    final normalized = _normalizeSaveUrl(value);

    // If already an absolute URL, return as-is
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    // Build base from media-service URL
    if (!AppConfig.isInitialized) return normalized;

    final mediaUrl = AppConfig.instance.mediaServiceUrl;
    final mediaUri = Uri.parse(mediaUrl);

    // Extract the base path from mediaServiceUrl (e.g. "/api/v1")
    String basePath = mediaUri.path.replaceAll(RegExp(r'/+$'), '');

    // The normalized input could be something like:
    //   /api/v1/media/public-file?key=stickers/pack/img.png
    //   /media/public/abc-123
    //   /stickers/packs
    //   media/public/abc-123
    //
    // We need to:
    // 1. Separate the path from query parameters
    // 2. Prepend basePath if not already present
    // 3. Reconstruct with scheme://host:port + path + query

    // Parse the normalized value as a relative URI to extract path/query
    // But Uri.parse needs a scheme, so we use a trick:
    String fullInput = normalized;
    if (!fullInput.startsWith('/')) {
      fullInput = '/$fullInput';
    }

    // Split path and query manually since Uri constructor strips query from path
    String pathPart = fullInput;
    String? queryPart;
    final qIndex = fullInput.indexOf('?');
    if (qIndex >= 0) {
      pathPart = fullInput.substring(0, qIndex);
      queryPart = fullInput.substring(qIndex + 1);
    }

    // Avoid duplicating the base path
    String finalPath = pathPart;
    if (basePath.isNotEmpty && !pathPart.startsWith(basePath)) {
      finalPath = '$basePath$pathPart';
    }

    // Clean up double slashes
    finalPath = finalPath.replaceAll(RegExp(r'/+'), '/');

    // Build the final URL
    final buffer = StringBuffer();
    buffer.write(mediaUri.scheme);
    buffer.write('://');
    buffer.write(mediaUri.host);
    if (mediaUri.hasPort) {
      buffer.write(':');
      buffer.write(mediaUri.port);
    }
    buffer.write(finalPath);
    if (queryPart != null && queryPart.isNotEmpty) {
      buffer.write('?');
      buffer.write(queryPart);
    }

    return buffer.toString();
  }

  static String _normalizeSaveUrl(String input) {
    // If we're already sending auth headers (implemented in widgets),
    // we should NOT force a change to '/public' because the file
    // might be private and require the current token.
    return input;
  }
}
