import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final bool autoPlay;
  final bool looping;

  const VideoPlayerWidget({
    super.key,
    this.url,
    this.file,
    this.autoPlay = false,
    this.looping = false,
  }) : assert(url != null || file != null, 'Must provide either url or file');

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.file != null) {
        _videoPlayerController = VideoPlayerController.file(widget.file!);
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      }

      await _videoPlayerController.initialize();
      
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white,
        ),
        placeholder: Container(
          color: isDarkMode ? Colors.black : Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[VideoPlayerWidget] Error initializing player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction == 0) {
      // Pause video when it is completely out of view
      if (_chewieController?.isPlaying ?? false) {
        _chewieController?.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black12,
        height: 200,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.grey, size: 40),
        ),
      );
    }

    if (!_isInitialized || _chewieController == null) {
      return Container(
        color: Colors.black12,
        height: 200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return VisibilityDetector(
      key: Key(widget.url ?? widget.file!.path),
      onVisibilityChanged: _handleVisibilityChanged,
      child: AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
