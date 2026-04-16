import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMine;
  final String? transcriptText;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.isMine,
    this.transcriptText,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isExpanded = false;
  bool _isDownloading = false;
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

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _duration = Duration.zero;
        _position = Duration.zero;
        _isExpanded = false;
      });
    }
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
      try {
        String playPath = widget.audioUrl;
        
        if (!isLocal) {
          // Manually download for authenticated access since audioplayers 6.6.0 doesn't support headers
          final token = context.read<AuthProvider>().accessToken;

          if (token != null) {
            final uri = Uri.parse(widget.audioUrl);
            // Use a hash of the URL to ensure unique caching and prevent "old audio" playbacks
            final urlHash = widget.audioUrl.hashCode.abs().toString();
            final extension = uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.') 
                ? uri.pathSegments.last.split('.').last 
                : 'm4a';
            final fileName = 'audio_$urlHash.$extension';
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/$fileName');

            if (!await file.exists()) {
              setState(() => _isDownloading = true);
              try {
                final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
                if (response.statusCode == 200) {
                  await file.writeAsBytes(response.bodyBytes);
                  playPath = file.path;
                }
              } catch (e) {
                debugPrint('Download error: $e');
              } finally {
                setState(() => _isDownloading = false);
              }
            } else {
              playPath = file.path;
            }
          }
        }

        if (playPath.startsWith('http')) {
           await _audioPlayer.play(UrlSource(playPath));
        } else {
           await _audioPlayer.play(DeviceFileSource(playPath));
        }
      } catch (e) {
        debugPrint('Audio playback error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode 
        ? Colors.white 
        : (widget.isMine ? const Color(0xFF1A1A1A) : Colors.black87);
    final iconColor = isDarkMode 
        ? Colors.white 
        : (widget.isMine ? Colors.white : AppColors.primary);
    final sliderActiveColor = isDarkMode 
        ? Colors.white 
        : (widget.isMine ? Colors.white : AppColors.primary);
    final sliderInactiveColor = isDarkMode 
        ? Colors.white24 
        : (widget.isMine ? Colors.white.withOpacity(0.3) : Colors.grey.shade300);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isDownloading 
              ? SizedBox(
                  width: 40, 
                  height: 40, 
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2, 
                      color: iconColor
                    ),
                  )
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: iconColor,
                    size: 40,
                  ),
                  onPressed: _togglePlayPause,
                ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: sliderActiveColor,
                      inactiveTrackColor: sliderInactiveColor,
                      thumbColor: sliderActiveColor,
                    ),
                    child: Slider(
                      min: 0,
                      max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                      value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                      onChanged: (value) async {
                        final position = Duration(seconds: value.toInt());
                        await _audioPlayer.seek(position);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      _formatDuration(_position.inSeconds > 0 ? _position : _duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : (widget.isMine ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.transcriptText != null && 
                widget.transcriptText!.isNotEmpty && 
                !widget.transcriptText!.endsWith('.m4a') && 
                !widget.transcriptText!.endsWith('.wav') &&
                !widget.transcriptText!.startsWith('voice_'))
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.font_download_outlined,
                  color: iconColor.withOpacity(0.7),
                  size: 24,
                ),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
              ),
          ],
        ),
        if (_isExpanded && widget.transcriptText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              widget.transcriptText!,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
