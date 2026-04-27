import 'package:flutter/foundation.dart';

class AvatarCacheProvider extends ChangeNotifier {
  final Duration _ttl;
  final DateTime Function() _now;
  final Map<String, int> _userAvatarVersion = <String, int>{};
  final Map<String, DateTime> _updatedAt = <String, DateTime>{};

  AvatarCacheProvider({
    Duration ttl = const Duration(hours: 12),
    DateTime Function()? nowProvider,
  })  : _ttl = ttl,
        _now = nowProvider ?? DateTime.now;

  int versionForUser(String userId) {
    if (userId.isEmpty) return 0;
    _evictIfExpired(userId);
    return _userAvatarVersion[userId] ?? 0;
  }

  void bumpUserAvatarVersion(String userId) {
    if (userId.isEmpty) return;
    final next = (_userAvatarVersion[userId] ?? 0) + 1;
    _userAvatarVersion[userId] = next;
    _updatedAt[userId] = _now();
    notifyListeners();
  }

  void purgeExpired() {
    final keys = _updatedAt.keys.toList();
    bool changed = false;
    for (final userId in keys) {
      final before = _userAvatarVersion.containsKey(userId);
      _evictIfExpired(userId);
      final after = _userAvatarVersion.containsKey(userId);
      if (before != after) changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _evictIfExpired(String userId) {
    final updatedAt = _updatedAt[userId];
    if (updatedAt == null) return;
    if (_now().difference(updatedAt) <= _ttl) return;
    _userAvatarVersion.remove(userId);
    _updatedAt.remove(userId);
  }

  void clear() {
    if (_userAvatarVersion.isEmpty && _updatedAt.isEmpty) return;
    _userAvatarVersion.clear();
    _updatedAt.clear();
    notifyListeners();
  }
}
