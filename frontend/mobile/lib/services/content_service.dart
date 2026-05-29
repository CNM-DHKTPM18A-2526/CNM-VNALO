import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/comment_model.dart';
import 'package:vnalo_mobile/models/post_model.dart';
import 'package:vnalo_mobile/models/story_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class ContentService {
  final ApiService _apiService;

  ContentService(this._apiService);

  String get _base => AppConfig.instance.contentServiceUrl;

  // ==================== STORY API ====================

  Future<List<Story>> getStories() async {
    try {
      final response = await _apiService.get(_base, '/stories');
      final data = response['data'] is List ? response['data'] : [];
      return data.map<Story>((json) => Story.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[ContentService] getStories error: $e');
      return [];
    }
  }

  Future<Story?> createStory({
    required String mediaUrl,
    String? caption,
    String visibility = 'PUBLIC',
    List<String>? includedIds,
    List<String>? excludedIds,
  }) async {
    final response = await _apiService.post(
      _base,
      '/stories',
      body: {
        'mediaUrl': mediaUrl,
        'caption': caption ?? '',
        'visibility': visibility,
        if (includedIds != null) 'includedIds': includedIds,
        if (excludedIds != null) 'excludedIds': excludedIds,
      },
    );
    final data = response['data'] ?? response;
    return Story.fromJson(data);
  }

  Future<bool> deleteStory(String storyId) async {
    try {
      await _apiService.delete(_base, '/stories/$storyId');
      return true;
    } catch (e) {
      debugPrint('[ContentService] deleteStory error: $e');
      return false;
    }
  }

  Future<bool> markStoryViewed(String storyId) async {
    try {
      await _apiService.post(_base, '/stories/$storyId/view', body: {});
      return true;
    } catch (e) {
      debugPrint('[ContentService] markStoryViewed error: $e');
      return false;
    }
  }

  Future<List<String>> getStoryViewers(String storyId) async {
    try {
      final response = await _apiService.get(_base, '/stories/$storyId/views');
      final data = response['data'] is List ? response['data'] : [];
      return data.map<String>((json) => json['viewerId']?.toString() ?? '').toList();
    } catch (e) {
      debugPrint('[ContentService] getStoryViewers error: $e');
      return [];
    }
  }

  // ==================== POST API ====================

  Future<TimelineResult> getTimeline({int page = 0, int size = 20}) async {
    try {
      final response = await _apiService.get(
        _base,
        '/posts/timeline',
        queryParams: {'page': page.toString(), 'size': size.toString()},
      );
      final data = response['data'] ?? response;
      return TimelineResult.fromJson(data);
    } catch (e) {
      debugPrint('[ContentService] getTimeline error: $e');
      return TimelineResult(posts: [], hasMore: false);
    }
  }

  Future<Post?> createPost({
    String? contentText,
    List<String>? mediaUrls,
    String visibility = 'PUBLIC',
    List<String>? includedIds,
    List<String>? excludedIds,
  }) async {
    try {
      final response = await _apiService.post(
        _base,
        '/posts',
        body: {
          'contentText': contentText ?? '',
          'mediaUrls': mediaUrls ?? [],
          'visibility': visibility,
          if (includedIds != null) 'includedIds': includedIds,
          if (excludedIds != null) 'excludedIds': excludedIds,
        },
      );
      final data = response['data'] ?? response;
      return Post.fromJson(data);
    } catch (e) {
      debugPrint('[ContentService] createPost error: $e');
      return null;
    }
  }

  Future<Post?> getPostById(String postId) async {
    try {
      final response = await _apiService.get(_base, '/posts/$postId');
      final data = response['data'] ?? response;
      return Post.fromJson(data);
    } catch (e) {
      debugPrint('[ContentService] getPostById error: $e');
      return null;
    }
  }

  Future<Post?> updatePost({
    required String postId,
    String? contentText,
    List<String>? mediaUrls,
    String? visibility,
    List<String>? includedIds,
    List<String>? excludedIds,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (contentText != null) body['contentText'] = contentText;
      if (mediaUrls != null) body['mediaUrls'] = mediaUrls;
      if (visibility != null) body['visibility'] = visibility;
      if (includedIds != null) body['includedIds'] = includedIds;
      if (excludedIds != null) body['excludedIds'] = excludedIds;

      final response = await _apiService.patch(_base, '/posts/$postId', body: body);
      final data = response['data'] ?? response;
      return Post.fromJson(data);
    } catch (e) {
      debugPrint('[ContentService] updatePost error: $e');
      return null;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _apiService.delete(_base, '/posts/$postId');
      return true;
    } catch (e) {
      debugPrint('[ContentService] deletePost error: $e');
      return false;
    }
  }

  // ==================== LIKE API ====================

  Future<bool> likePost(String postId, {String reactionType = 'LOVE'}) async {
    try {
      await _apiService.post(_base, '/posts/$postId/like?reactionType=$reactionType');
      return true;
    } catch (e) {
      debugPrint('[ContentService] likePost error: $e');
      return false;
    }
  }

  Future<bool> unlikePost(String postId) async {
    try {
      await _apiService.delete(_base, '/posts/$postId/like');
      return true;
    } catch (e) {
      debugPrint('[ContentService] unlikePost error: $e');
      return false;
    }
  }

  // ==================== SHARE API ====================

  // ==================== REACTIONS/LIKES LIST API ====================

  Future<List<Map<String, dynamic>>> getPostLikers(String postId) async {
    try {
      final response = await _apiService.get(_base, '/posts/$postId/likes');
      final data = response['data'] ?? response;
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      debugPrint('[ContentService] getPostLikers error: $e');
      return [];
    }
  }

  // ==================== COMMENT API ====================

  Future<CommentPageResult> getComments(String postId, {int page = 0, int size = 20}) async {
    try {
      final response = await _apiService.get(
        _base,
        '/posts/$postId/comments',
        queryParams: {'page': page.toString(), 'size': size.toString()},
      );
      final data = response['data'] ?? response;
      return CommentPageResult.fromJson(data);
    } catch (e) {
      debugPrint('[ContentService] getComments error: $e');
      return CommentPageResult(comments: [], hasMore: false);
    }
  }

  Future<Comment?> createComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final body = <String, dynamic>{'contentText': content};
      if (parentCommentId != null) body['parentCommentId'] = parentCommentId;

      final response = await _apiService.post(_base, '/posts/$postId/comments', body: body);
      final data = response['data'] ?? response;
      return Comment.fromJson(data);
    } catch (e) {
      debugPrint('[ContentService] createComment error: $e');
      return null;
    }
  }

  Future<Comment?> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final response = await _apiService.patch(
        _base,
        '/comments/$commentId',
        body: {'content': content},
      );
      final data = response['data'] ?? response;
      return Comment.fromJson(data);
    } catch (e) {
      debugPrint('[ContentService] updateComment error: $e');
      return null;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _apiService.delete(_base, '/comments/$commentId');
      return true;
    } catch (e) {
      debugPrint('[ContentService] deleteComment error: $e');
      return false;
    }
  }
}

// Timeline result wrapper
class TimelineResult {
  final List<Post> posts;
  final bool hasMore;

  TimelineResult({required this.posts, required this.hasMore});

  factory TimelineResult.fromJson(Map<String, dynamic> json) {
    List<Post> posts = [];
    bool hasMore = false;

    if (json['content'] is List) {
      posts = (json['content'] as List).map<Post>((p) => Post.fromJson(p)).toList();
    } else if (json['posts'] is List) {
      posts = (json['posts'] as List).map<Post>((p) => Post.fromJson(p)).toList();
    } else if (json is List) {
      posts = (json as List).map<Post>((p) => Post.fromJson(p)).toList();
    }

    if (json['hasMore'] is bool) {
      hasMore = json['hasMore'];
    } else if (json['last'] == false) {
      hasMore = true;
    }

    return TimelineResult(posts: posts, hasMore: hasMore);
  }
}

// Comment page result wrapper
class CommentPageResult {
  final List<Comment> comments;
  final bool hasMore;
  final int total;

  CommentPageResult({required this.comments, required this.hasMore, this.total = 0});

  factory CommentPageResult.fromJson(Map<String, dynamic> json) {
    List<Comment> comments = [];
    bool hasMore = false;
    int total = 0;

    if (json['items'] is List) {
      comments = (json['items'] as List).map<Comment>((c) => Comment.fromJson(c)).toList();
    } else if (json['content'] is List) {
      comments = (json['content'] as List).map<Comment>((c) => Comment.fromJson(c)).toList();
    } else if (json is List) {
      comments = (json as List).map<Comment>((c) => Comment.fromJson(c)).toList();
    }

    if (json['hasMore'] is bool) {
      hasMore = json['hasMore'];
    } else if (json['last'] == false) {
      hasMore = true;
    }
    
    if (json['totalElements'] is int) {
      total = json['totalElements'];
    } else {
      total = comments.length;
    }

    return CommentPageResult(comments: comments, hasMore: hasMore, total: total);
  }
}
