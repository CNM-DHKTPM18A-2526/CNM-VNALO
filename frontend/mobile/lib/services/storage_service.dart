import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class StorageService {
  final _storage = const FlutterSecureStorage();
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyBlockedConversationIdsPrefix = 'blocked_conversation_ids_';
  static const _keyAnalyticsConsent = 'analytics_consent_enabled';

  // Save access and refresh tokens securely
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  // Retrieve tokens
  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  Future<void> saveUserId(String userId) =>
      _storage.write(key: _keyUserId, value: userId);
  Future<String?> getUserId() => _storage.read(key: _keyUserId);

  // Clear all stored data (e.g., on logout)
  Future<void> clearAll() => _storage.deleteAll();

  Future<bool> getAnalyticsConsentEnabled() async {
    final raw = await _storage.read(key: _keyAnalyticsConsent);
    return raw != 'false';
  }

  Future<void> setAnalyticsConsentEnabled(bool enabled) =>
      _storage.write(key: _keyAnalyticsConsent, value: enabled.toString());

  // Persist per-user blocked conversation IDs to avoid reappearing after leave/kick/disband.
  // This intentionally survives app restarts. Caller decides whether to keep across logout.
  String _blockedConversationsKey(String userId) => '$_keyBlockedConversationIdsPrefix$userId';

  Future<Set<String>> getBlockedConversationIds(String userId) async {
    final raw = await _storage.read(key: _blockedConversationsKey(userId));
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
      return <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> setBlockedConversationIds(String userId, Set<String> ids) async {
    final list = ids.toList()..sort();
    await _storage.write(key: _blockedConversationsKey(userId), value: jsonEncode(list));
  }

  Future<void> addBlockedConversationId(String userId, String conversationId) async {
    final current = await getBlockedConversationIds(userId);
    if (current.add(conversationId)) {
      await setBlockedConversationIds(userId, current);
    }
  }

  Future<void> removeBlockedConversationId(String userId, String conversationId) async {
    final current = await getBlockedConversationIds(userId);
    if (current.remove(conversationId)) {
      await setBlockedConversationIds(userId, current);
    }
  }
}
