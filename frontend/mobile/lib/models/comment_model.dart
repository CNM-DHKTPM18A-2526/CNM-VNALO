class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final String? parentCommentId;
  final int replyCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    this.parentCommentId,
    this.replyCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  Comment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? content,
    String? parentCommentId,
    int? replyCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyCount: replyCount ?? this.replyCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['commentId']?.toString() ?? json['id']?.toString() ?? '',
    postId: json['postId']?.toString() ?? '',
    authorId: json['authorId']?.toString() ?? '',
    content: json['contentText'] ?? json['content'] ?? '',
    parentCommentId: json['parentCommentId']?.toString(),
    replyCount: json['replyCount'] ?? 0,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'].toString()) 
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null 
        ? DateTime.tryParse(json['updatedAt'].toString()) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    'commentId': id,
    'postId': postId,
    'authorId': authorId,
    'content': content,
    'parentCommentId': parentCommentId,
    'replyCount': replyCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}
