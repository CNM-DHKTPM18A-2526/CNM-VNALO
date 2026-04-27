import 'package:vnalo_mobile/models/api_response.dart';

enum NotificationType {
  FRIEND_REQUEST,
  SYSTEM,
  TIMELINE_LIKE,
  TIMELINE_COMMENT,
  OTHER
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: _parseType(json['type']),
      metadata: json['metadata'] is Map ? json['metadata'] : null,
      isRead: json['isRead'] == true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  static NotificationType _parseType(dynamic type) {
    final t = type?.toString().toUpperCase();
    return switch (t) {
      'FRIEND_REQUEST' => NotificationType.FRIEND_REQUEST,
      'SYSTEM' => NotificationType.SYSTEM,
      'TIMELINE_LIKE' => NotificationType.TIMELINE_LIKE,
      'TIMELINE_COMMENT' => NotificationType.TIMELINE_COMMENT,
      _ => NotificationType.OTHER,
    };
  }
}
