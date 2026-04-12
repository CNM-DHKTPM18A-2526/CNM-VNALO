import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMine;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.isMine,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final isLocal = widget.audioUrl.startsWith('/') || widget.audioUrl.contains('Users') || widget.audioUrl.contains('storage');

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (isLocal) {
        await _audioPlayer.play(DeviceFileSource(widget.audioUrl));
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMine ? const Color(0xFF1A1A1A) : Colors.black87;
    final iconColor = widget.isMine ? AppColors.primary : Colors.black87;
    final sliderActiveColor = widget.isMine ? AppColors.primary : Colors.grey.shade700;
    final sliderInactiveColor = widget.isMine ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade300;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: iconColor,
            size: 36,
          ),
          onPressed: _togglePlayPause,
        ),
        SizedBox(
          width: 140,
          child: Slider(
            min: 0,
            max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
            value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
            onChanged: (value) async {
              final position = Duration(seconds: value.toInt());
              await _audioPlayer.seek(position);
            },
            activeColor: sliderActiveColor,
            inactiveColor: sliderInactiveColor,
          ),
        ),
        Text(
          _formatDuration(_position.inSeconds > 0 ? _position : _duration),
          style: TextStyle(
            fontSize: 12,
            color: textColor,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
