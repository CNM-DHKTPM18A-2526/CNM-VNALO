import 'package:flutter/material.dart';
import 'package:vnalo_mobile/models/post_model.dart';
import 'package:vnalo_mobile/models/story_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';

class PostProvider with ChangeNotifier {
  List<Post> _posts = [];
  List<Story> _stories = [];
  bool _isLoading = false;

  List<Post> get posts => _posts;
  List<Story> get stories => _stories;
  bool get isLoading => _isLoading;

  PostProvider() {
    _loadMockData();
  }

  void _loadMockData() {
    _isLoading = true;
    
    // Simulating mock data for now as per user request to avoid backend dependency
    _stories = [];
    _posts = [];

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshTimeline() async {
    _isLoading = true;
    notifyListeners();
    
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));
    _loadMockData();
  }
}
