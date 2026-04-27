import 'package:flutter/material.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/notification_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService;
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  NotificationProvider(this._apiService);

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final baseUrl = AppConfig.instance.coreServiceUrl; // Or specific notification service URL
      final response = await _apiService.get(baseUrl, '/notifications');
      
      final List<dynamic> data = response['data'] ?? [];
      _notifications = data.map((json) => NotificationModel.fromJson(json)).toList();
      
      // Sort by newest first
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final baseUrl = AppConfig.instance.coreServiceUrl;
      await _apiService.post(baseUrl, '/notifications/$notificationId/read');
      
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          title: _notifications[index].title,
          body: _notifications[index].body,
          type: _notifications[index].type,
          isRead: true,
          createdAt: _notifications[index].createdAt,
          metadata: _notifications[index].metadata,
        );
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final baseUrl = AppConfig.instance.coreServiceUrl;
      await _apiService.post(baseUrl, '/notifications/read-all');
      
      _notifications = _notifications.map((n) => NotificationModel(
        id: n.id,
        userId: n.userId,
        title: n.title,
        body: n.body,
        type: n.type,
        isRead: true,
        createdAt: n.createdAt,
        metadata: n.metadata,
      )).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }
}
