import 'package:flutter/material.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class ContactProvider with ChangeNotifier {
  final FriendService _friendService;
  final SocketService _socketService;
  
  List<User> _friends = [];
  int _pendingRequestCount = 0;
  bool _isLoading = false;

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
      fetchPendingRequestCount();
    });
  }

  List<User> get friends => _friends;
  int get pendingRequestCount => _pendingRequestCount;
  bool get isLoading => _isLoading;

  Future<void> fetchFriends() async {
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
    fetchPendingRequestCount();
  }
}
