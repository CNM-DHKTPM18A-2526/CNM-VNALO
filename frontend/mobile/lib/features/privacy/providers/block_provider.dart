import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/models/blocked_user_model.dart';
import 'package:vnalo_mobile/services/block_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class BlockProvider extends ChangeNotifier {
  final BlockService _blockService;
  final SocketService _socketService;

  final List<BlockedUser> _blockedUsers = [];
  List<BlockedUser> get blockedUsers => List.unmodifiable(_blockedUsers);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _page = 0;
  StreamSubscription<Map<String, dynamic>>? _blockCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _blockUpdatedSub;
  StreamSubscription<Map<String, dynamic>>? _blockRemovedSub;

  final Map<String, Timer> _debounce = {};

  BlockProvider(this._blockService, this._socketService) {
    _blockCreatedSub = _socketService.onBlockCreated.listen(_handleBlockCreated);
    _blockUpdatedSub = _socketService.onBlockUpdated.listen(_handleBlockUpdated);
    _blockRemovedSub = _socketService.onBlockRemoved.listen(_handleBlockRemoved);
  }

  @override
  void dispose() {
    for (final t in _debounce.values) {
      t.cancel();
    }
    _debounce.clear();
    _blockCreatedSub?.cancel();
    _blockUpdatedSub?.cancel();
    _blockRemovedSub?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    _page = 0;
    _hasMore = true;
    _blockedUsers.clear();
    notifyListeners();
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _blockService.getBlockedUsers(page: _page, size: 20);
      final data = res['data'];
      final content = data is Map<String, dynamic> ? (data['content'] as List?) : null;
      final items = (content ?? const [])
          .whereType<Map>()
          .map((e) => BlockedUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      _blockedUsers.addAll(items);
      _page += 1;

      final isLast = data is Map<String, dynamic> ? (data['last'] == true) : (items.isEmpty);
      _hasMore = !isLast;
    } catch (e) {
      debugPrint('[BlockProvider] loadMore error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void scheduleUpdateFlags(
    String userId, {
    bool? blockMessages,
    bool? blockCalls,
  }) {
    _debounce[userId]?.cancel();
    _debounce[userId] = Timer(const Duration(milliseconds: 350), () async {
      try {
        await _blockService.updateBlock(
          userId,
          blockMessages: blockMessages,
          blockCalls: blockCalls,
        );
      } catch (e) {
        debugPrint('[BlockProvider] updateBlock error: $e');
      }
    });
  }

  Future<void> unblock(String userId) async {
    try {
      await _blockService.unblockUser(userId);
      _blockedUsers.removeWhere((u) => u.userId == userId);
      notifyListeners();
    } catch (e) {
      debugPrint('[BlockProvider] unblock error: $e');
      rethrow;
    }
  }

  void _handleBlockCreated(Map<String, dynamic> payload) {
    // For blocker: include full payload; for blocked: still safe to ignore.
    final blockedId = payload['blockedId']?.toString();
    if (blockedId == null) return;

    final idx = _blockedUsers.indexWhere((u) => u.userId == blockedId);
    if (idx >= 0) {
      _blockedUsers[idx] = _blockedUsers[idx].copyWith(
        blockMessages: payload['blockMessages'] == true,
        blockCalls: payload['blockCalls'] == true,
      );
    } else {
      _blockedUsers.insert(0, BlockedUser.fromJson(payload));
    }
    notifyListeners();
  }

  void _handleBlockUpdated(Map<String, dynamic> payload) {
    final blockedId = payload['blockedId']?.toString();
    if (blockedId == null) return;

    final idx = _blockedUsers.indexWhere((u) => u.userId == blockedId);
    if (idx < 0) return;

    _blockedUsers[idx] = _blockedUsers[idx].copyWith(
      blockMessages: payload['blockMessages'] == true,
      blockCalls: payload['blockCalls'] == true,
    );
    notifyListeners();
  }

  void _handleBlockRemoved(Map<String, dynamic> payload) {
    final blockedId = payload['blockedId']?.toString();
    if (blockedId == null) return;

    _blockedUsers.removeWhere((u) => u.userId == blockedId);
    notifyListeners();
  }
}
