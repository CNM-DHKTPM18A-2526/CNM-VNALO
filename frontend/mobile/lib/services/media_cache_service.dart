import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
import 'package:open_file/open_file.dart';

/// Manages on-demand file download + local-path caching.
///
/// Strategy:
///  1. Check if local_path already stored in DB and file still exists → open immediately.
///  2. Otherwise, download to <AppDocumentsDir>/vnalo_files/<messageId>.<ext>
///  3. Persist the local_path back to [LocalDatabase] for future use.
///  4. Open the file using the system default application.
class MediaCacheService {
  final LocalDatabase _db;

  MediaCacheService(this._db);

  static const String _filesDir = 'vnalo_files';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the local path if the file has already been downloaded.
  /// Pass [messageId] as stored in [LocalMessage.id].
  Future<String?> getLocalPath(String messageId) async {
    final rows = await _db.customSelect(
      'SELECT local_path FROM messages WHERE id = ? LIMIT 1',
      variables: [Variable.withString(messageId)],
    ).get();

    if (rows.isEmpty) return null;
    final path = rows.first.readNullable<String>('local_path');
    if (path == null) return null;

    // Verify the file still physically exists (could have been deleted by OS or user)
    final exists = await File(path).exists();
    if (!exists) {
      // Stale path — clear it
      await _db.clearStalePaths([messageId]);
      return null;
    }
    return path;
  }

  /// Download a remote file on demand and persist the local path.
  ///
  /// Returns the local [File] path.
  /// Throws on network errors so callers can show an error state.
  Future<String> downloadAndCache({
    required String messageId,
    required String remoteUrl,
    String? mimeType,
    Map<String, String>? headers,
  }) async {
    // Guard — avoid double-download if another call is in-flight
    final existing = await getLocalPath(messageId);
    if (existing != null) return existing;

    final ext = _extensionFromMime(mimeType) ?? _extensionFromUrl(remoteUrl) ?? 'bin';
    final dir = await _localDir(_filesDir);
    final localFile = File(p.join(dir.path, '${messageId.replaceAll('-', '')}.$ext'));

    debugPrint('[MediaCacheService] Downloading $remoteUrl → ${localFile.path}');
    final response = await http.get(Uri.parse(remoteUrl), headers: headers ?? {});

    if (response.statusCode != 200) {
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }

    await localFile.writeAsBytes(response.bodyBytes);
    await _db.updateLocalPath(messageId, localFile.path);

    debugPrint('[MediaCacheService] Cached at ${localFile.path}');
    return localFile.path;
  }

  /// Open a downloaded file with the system default application.
  Future<OpenResult> openFile(String localPath) async {
    return OpenFile.open(localPath);
  }

  /// Total size of the files cache in bytes.
  Future<int> cacheSize() async {
    final dir = await _localDir(_filesDir);
    int total = 0;
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Delete all downloaded files and clear local_path in the DB.
  /// Called from Settings → "Clear media cache".
  Future<void> clearAll() async {
    final dir = await _localDir(_filesDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    // Mark all local_paths as NULL for all messages (bulk clear)
    await _db.customStatement('UPDATE messages SET local_path = NULL');
    debugPrint('[MediaCacheService] All media cache cleared.');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Directory> _localDir(String subDir) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, subDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String? _extensionFromMime(String? mime) {
    if (mime == null) return null;
    const map = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'application/pdf': 'pdf',
      'application/msword': 'doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
      'application/vnd.ms-excel': 'xls',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
      'video/mp4': 'mp4',
      'audio/mpeg': 'mp3',
      'audio/ogg': 'ogg',
    };
    return map[mime.toLowerCase()];
  }

  String? _extensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isEmpty) return null;
      final last = segments.last;
      final dot = last.lastIndexOf('.');
      if (dot == -1 || dot == last.length - 1) return null;
      return last.substring(dot + 1).split('?').first;
    } catch (_) {
      return null;
    }
  }
}
