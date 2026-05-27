class Story {
  final String id;
  final String authorId;
  final String? mediaUrl;
  final String? caption;
  final String? visibility;
  final DateTime? expiresAt;
  final DateTime createdAt;

  Story({
    required this.id,
    required this.authorId,
    this.mediaUrl,
    this.caption,
    this.visibility,
    this.expiresAt,
    required this.createdAt,
  });

  factory Story.fromJson(Map<String, dynamic> json) => Story(
    id: json['storyId']?.toString() ?? json['id']?.toString() ?? '',
    authorId: json['authorId']?.toString() ?? '',
    mediaUrl: json['mediaUrl'],
    caption: json['caption'],
    visibility: json['visibility'],
    expiresAt: json['expiresAt'] != null 
        ? DateTime.tryParse(json['expiresAt'].toString()) 
        : null,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'].toString())
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'storyId': id,
    'authorId': authorId,
    'mediaUrl': mediaUrl,
    'caption': caption,
    'visibility': visibility,
    'expiresAt': expiresAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
