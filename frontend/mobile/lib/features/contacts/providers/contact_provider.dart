import 'package:flutter/material.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class ContactProvider with ChangeNotifier {
  final FriendService _friendService;
  final SocketService _socketService;
  
  List<User> _friends = [];
  List<User> _incomingRequests = [];
  int _pendingRequestCount = 0;
  bool _isLoading = false;
  String? _currentUserId;

  ContactProvider(this._friendService, this._socketService) {
    _initSocketListeners();
  }

  void _initSocketListeners() {
    _socketService.onFriendshipUpdated.listen((_) {
      debugPrint('🟢 [ContactProvider] Received friendship.updated event');
      onFriendshipUpdated();
    });

    _socketService.onFriendRequestReceived.listen((_) {
      debugPrint('🟢 [ContactProvider] Received friend.request.received event');
      fetchIncomingRequests();
    });
  }

  void update(String? userId) {
    if (_currentUserId != userId) {
      debugPrint('🟢 [ContactProvider] User ID changed: $_currentUserId -> $userId');
      _currentUserId = userId;
      if (userId == null) {
        reset();
      } else {
        onFriendshipUpdated();
      }
    }
  }

  void reset() {
    _friends = [];
    _incomingRequests = [];
    _pendingRequestCount = 0;
    _isLoading = false;
    _currentUserId = null;
    notifyListeners();
  }

  List<User> get friends => _friends;
  List<User> get incomingRequests => _incomingRequests;
  int get pendingRequestCount => _pendingRequestCount;
  bool get isLoading => _isLoading;

  Future<void> fetchIncomingRequests() async {
    try {
      _incomingRequests = await _friendService.getPendingRequests();
      _pendingRequestCount = _incomingRequests.length;
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
      // Sort alphabetically
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching pending request count: $e');
    }
  }

  void updatePendingCount(int count) {
    _pendingRequestCount = count;
    notifyListeners();
  }
  
  // Method to be called by SocketService/SyncService
  void onFriendshipUpdated() {
    fetchFriends();
    fetchIncomingRequests();
  }
}
