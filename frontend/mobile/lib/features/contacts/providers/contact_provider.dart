import 'package:flutter/material.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class ContactProvider with ChangeNotifier {
  final FriendService _friendService;
  int _pendingRequestCount = 0;

  ContactProvider(this._friendService);

  int get pendingRequestCount => _pendingRequestCount;

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
}
