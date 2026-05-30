class Post {
  final String id;
  final String authorId;
  final String content;
  final List<String> mediaUrls;
  final String? visibility;
  final List<String> includedIds;
  final List<String> excludedIds;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final String? status;
  final bool isLiked;
  final String? myReactionType;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Post({
    required this.id,
    required this.authorId,
    required this.content,
    this.mediaUrls = const [],
    this.visibility,
    this.includedIds = const [],
    this.excludedIds = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.status,
    this.isLiked = false,
    this.myReactionType,
    required this.createdAt,
    this.updatedAt,
  });

  Post copyWith({
    String? id,
    String? authorId,
    String? content,
    List<String>? mediaUrls,
    String? visibility,
    List<String>? includedIds,
    List<String>? excludedIds,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    String? status,
    bool? isLiked,
    String? myReactionType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      visibility: visibility ?? this.visibility,
      includedIds: includedIds ?? this.includedIds,
      excludedIds: excludedIds ?? this.excludedIds,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      status: status ?? this.status,
      isLiked: isLiked ?? this.isLiked,
      myReactionType: myReactionType ?? this.myReactionType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['postId']?.toString() ?? json['id']?.toString() ?? '',
    authorId: json['authorId']?.toString() ?? '',
    content: json['contentText'] ?? json['content'] ?? '',
    mediaUrls: json['mediaUrls'] != null 
        ? List<String>.from(json['mediaUrls']) 
        : (json['mediaUrl'] != null ? [json['mediaUrl'].toString()] : []),
    visibility: json['visibility'],
    includedIds: json['includedIds'] != null ? List<String>.from(json['includedIds']) : [],
    excludedIds: json['excludedIds'] != null ? List<String>.from(json['excludedIds']) : [],
    likeCount: json['likeCount'] ?? 0,
    commentCount: json['commentCount'] ?? 0,
    shareCount: json['shareCount'] ?? 0,
    status: json['status'],
    isLiked: json['isLiked'] ?? false,
    myReactionType: json['myReactionType'],
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'].toString()) 
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null 
        ? DateTime.tryParse(json['updatedAt'].toString()) 
        : null,
  );

  Map<String, dynamic> toJson() => {
    'postId': id,
    'authorId': authorId,
    'contentText': content,
    'mediaUrls': mediaUrls,
    'visibility': visibility,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'shareCount': shareCount,
    'status': status,
    'isLiked': isLiked,
    'myReactionType': myReactionType,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}
