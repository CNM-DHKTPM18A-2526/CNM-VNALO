import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/models/comment_model.dart';
import 'package:vnalo_mobile/models/post_model.dart';
import 'package:vnalo_mobile/models/story_model.dart';
import 'package:vnalo_mobile/services/content_service.dart';

class PostProvider with ChangeNotifier {
  final ContentService _contentService;

  List<Post> _posts = [];
  List<Story> _stories = [];
  bool _isLoading = false;
  bool _hasMorePosts = true;
  int _currentPage = 0;
  String? _error;

  List<Post> get posts => _posts;
  List<Story> get stories => _stories;
  bool get isLoading => _isLoading;
  bool get hasMorePosts => _hasMorePosts;
  String? get error => _error;

  PostProvider(this._contentService);

  Future<void> loadStories() async {
    try {
      final stories = await _contentService.getStories();
      _stories = stories;
      notifyListeners();
    } catch (e) {
      debugPrint('[PostProvider] loadStories error: $e');
    }
  }

  Future<void> loadTimeline({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMorePosts) return;

    if (refresh) {
      _currentPage = 0;
      _hasMorePosts = true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _contentService.getTimeline(
        page: _currentPage,
        size: 20,
      );

      if (refresh) {
        _posts = result.posts;
      } else {
        _posts.addAll(result.posts);
      }

      _hasMorePosts = result.hasMore;
      _currentPage++;
    } catch (e) {
      _error = 'Không thể tải bài viết';
      debugPrint('[PostProvider] loadTimeline error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshTimeline() async {
    await loadStories();
    await loadTimeline(refresh: true);
  }

  Future<Post?> createPost({
    String? contentText,
    List<String>? mediaUrls,
    String visibility = 'PUBLIC',
    List<String>? includedIds,
    List<String>? excludedIds,
  }) async {
    try {
      final post = await _contentService.createPost(
        contentText: contentText,
        mediaUrls: mediaUrls,
        visibility: visibility,
        includedIds: includedIds,
        excludedIds: excludedIds,
      );

      if (post != null) {
        _posts.insert(0, post);
        notifyListeners();
      }

      return post;
    } catch (e) {
      _error = 'Không thể tạo bài viết';
      debugPrint('[PostProvider] createPost error: $e');
      notifyListeners();
      return null;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      final success = await _contentService.deletePost(postId);
      if (success) {
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[PostProvider] deletePost error: $e');
      return false;
    }
  }

  Future<bool> toggleLike(String postId, {String reactionType = 'LOVE'}) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return false;

    final post = _posts[postIndex];
    final wasLiked = post.isLiked;
    final oldReaction = post.myReactionType;

    // Optimistic update
    _posts[postIndex] = post.copyWith(
      isLiked: true, // If changing reaction, it's always liked
      myReactionType: reactionType,
      likeCount: wasLiked ? post.likeCount : post.likeCount + 1,
    );
    notifyListeners();

    try {
      bool success = false;
      // If it was already liked and we tap with the same reaction (or default LOVE), we unlike it
      if (wasLiked && reactionType == (oldReaction ?? 'LOVE')) {
        success = await _contentService.unlikePost(postId);
        if (success) {
          _posts[postIndex] = post.copyWith(
            isLiked: false, 
            myReactionType: null, 
            likeCount: post.likeCount > 0 ? post.likeCount - 1 : 0
          );
        } else {
          _posts[postIndex] = post; // Revert
        }
      } else {
        success = await _contentService.likePost(postId, reactionType: reactionType);
        if (!success) _posts[postIndex] = post; // Revert
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      // Revert on error
      _posts[postIndex] = post;
      notifyListeners();
      debugPrint('[PostProvider] toggleLike error: $e');
      return false;
    }
  }

  /// Called locally after a comment is submitted to update the UI count immediately.
  void incrementCommentCount(String postId) {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = _posts[postIndex];
      _posts[postIndex] = post.copyWith(commentCount: post.commentCount + 1);
      notifyListeners();
    }
  }

  Future<Comment?> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      return await _contentService.createComment(
        postId: postId,
        content: content,
        parentCommentId: parentCommentId,
      );
    } catch (e) {
      debugPrint('[PostProvider] addComment error: $e');
      return null;
    }
  }

  Future<bool> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    try {
      return await _contentService.deleteComment(commentId);
    } catch (e) {
      debugPrint('[PostProvider] deleteComment error: $e');
      return false;
    }
  }

  Future<CommentPageResult?> getComments(String postId, {int page = 0}) async {
    try {
      return await _contentService.getComments(postId, page: page);
    } catch (e) {
      debugPrint('[PostProvider] getComments error: $e');
      return null;
    }
  }

  Future<Story?> createStory({
    required String mediaUrl,
    String? caption,
    String visibility = 'PUBLIC',
  }) async {
    final story = await _contentService.createStory(
      mediaUrl: mediaUrl,
      caption: caption,
      visibility: visibility,
    );

    if (story != null) {
      _stories.insert(0, story);
      notifyListeners();
    }

    return story;
  }

  Future<bool> deleteStory(String storyId) async {
    try {
      final success = await _contentService.deleteStory(storyId);
      if (success) {
        _stories.removeWhere((s) => s.id == storyId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[PostProvider] deleteStory error: $e');
      return false;
    }
  }

  Future<void> markStoryViewed(String storyId) async {
    try {
      await _contentService.markStoryViewed(storyId);
    } catch (e) {
      debugPrint('[PostProvider] markStoryViewed error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
