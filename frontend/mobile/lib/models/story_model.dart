import 'package:vnalo_mobile/models/user_model.dart';

class Story {
  final String id;
  final User author;
  final String? mediaUrl;
  final DateTime createdAt;
  final bool isMe;

  Story({
    required this.id,
    required this.author,
    this.mediaUrl,
    required this.createdAt,
    this.isMe = false,
  });

  factory Story.fromJson(Map<String, dynamic> json) => Story(
    id: json['id'],
    author: User.fromJson(json['author']),
    mediaUrl: json['mediaUrl'],
    createdAt: DateTime.parse(json['createdAt']),
    isMe: json['isMe'] ?? false,
  );
}
