import 'package:flutter/foundation.dart';

class AvatarCacheProvider extends ChangeNotifier {
  final Map<String, int> _userAvatarVersion = <String, int>{};

  int versionForUser(String userId) {
    if (userId.isEmpty) return 0;
    return _userAvatarVersion[userId] ?? 0;
  }

  void bumpUserAvatarVersion(String userId) {
    if (userId.isEmpty) return;
    final next = (_userAvatarVersion[userId] ?? 0) + 1;
    _userAvatarVersion[userId] = next;
    notifyListeners();
  }
}