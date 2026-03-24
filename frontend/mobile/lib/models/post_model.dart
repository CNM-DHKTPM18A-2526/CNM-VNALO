import 'package:vnalo_mobile/models/user_model.dart';

class Post {
  final String id;
  final User author;
  final String content;
  final List<String> mediaUrls;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.author,
    required this.content,
    this.mediaUrls = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'],
    author: User.fromJson(json['author']),
    content: json['content'] ?? '',
    mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
    likeCount: json['likeCount'] ?? 0,
    commentCount: json['commentCount'] ?? 0,
    shareCount: json['shareCount'] ?? 0,
    isLiked: json['isLiked'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
  );
}
