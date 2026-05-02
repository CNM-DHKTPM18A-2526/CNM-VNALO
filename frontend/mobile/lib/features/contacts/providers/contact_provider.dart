import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class ContactProvider with ChangeNotifier {
  final FriendService _friendService;
  SocketService _socketService;
  Timer? _pollingTimer;
  
  List<User> _friends = [];
  List<Map<String, dynamic>> _incomingRequestsRaw = [];
  int _pendingRequestCount = 0;
  bool _isLoading = false;
  String? _currentUserId;
  int _lastSocketReinitCount = -1;

  final List<StreamSubscription> _subscriptions = [];

  ContactProvider(this._friendService, this._socketService) {
    _initSocketListeners();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
       fetchIncomingRequests();
    });
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  void _cancelSubscriptions() {
    _pollingTimer?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _initSocketListeners() {
    _cancelSubscriptions();
    
    debugPrint('🟢 [ContactProvider] Initializing socket listeners (Socket reinit count: ${_socketService.reinitCount})');
    _lastSocketReinitCount = _socketService.reinitCount;

    _subscriptions.add(
      _socketService.onFriendshipUpdated.listen((_) async {
        debugPrint('🟢 [ContactProvider] Received friendship.updated event');
        // Add a small delay to allow backend transaction to commit
        await Future.delayed(const Duration(milliseconds: 500));
        onFriendshipUpdated();
      })
    );

    _subscriptions.add(
      _socketService.onFriendRequestReceived.listen((data) async {
        debugPrint('🟢 [ContactProvider] Received friend.request.received event: $data');
        // Add a small delay to allow backend transaction to commit
        await Future.delayed(const Duration(milliseconds: 500));
        fetchIncomingRequests();
      })
    );
  }

  void update(String? userId, SocketService socketService) {
    bool needsReinit = false;

    if (socketService != _socketService) {
      debugPrint('🟢 [ContactProvider] SocketService instance changed, updating reference');
      _socketService = socketService;
      needsReinit = true;
    }

    if (_currentUserId != userId) {
      debugPrint('🟢 [ContactProvider] User ID changed: $_currentUserId -> $userId');
      _currentUserId = userId;
      needsReinit = true;
      if (userId == null) {
        reset();
      } else {
        onFriendshipUpdated();
      }
    }

    if (userId != null && _lastSocketReinitCount != _socketService.reinitCount) {
      debugPrint('🟢 [ContactProvider] Socket re-initialized, re-subscribing listeners');
      needsReinit = true;
    }

    if (needsReinit && userId != null) {
      _initSocketListeners();
      _startPolling();
      fetchIncomingRequests();
    }
  }

  void reset() {
    _friends = [];
    _incomingRequestsRaw = [];
    _pendingRequestCount = 0;
    _isLoading = false;
    _currentUserId = null;
    _cancelSubscriptions();
    notifyListeners();
  }

  List<User> get friends => _friends;
  List<Map<String, dynamic>> get incomingRequestsRaw => _incomingRequestsRaw;
  int get pendingRequestCount => _pendingRequestCount;
  bool get isLoading => _isLoading;

  Future<void> fetchIncomingRequests() async {
    try {
      _incomingRequestsRaw = await _friendService.getIncomingRequests();
      _pendingRequestCount = _incomingRequestsRaw.length;
      debugPrint('🟢 [ContactProvider] Fetched ${_incomingRequestsRaw.length} incoming requests');
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching incoming requests: $e');
    }
  }

  Future<void> fetchFriends() async {
    if (_currentUserId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _friends = await _friendService.getFriends();
      _friends.sort((a, b) => a.displayName.compareTo(b.displayName));
    } catch (e) {
      debugPrint('Error fetching friends: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPendingRequestCount() async {
    try {
      _pendingRequestCount = await _friendService.getPendingRequestCount();
      debugPrint('🟢 [ContactProvider] Polled pending request count: $_pendingRequestCount');
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching pending request count: $e');
    }
  }

  void updatePendingCount(int count) {
    _pendingRequestCount = count;
    notifyListeners();
  }
  
  void onFriendshipUpdated() {
    fetchFriends();
    fetchIncomingRequests();
  }
}
