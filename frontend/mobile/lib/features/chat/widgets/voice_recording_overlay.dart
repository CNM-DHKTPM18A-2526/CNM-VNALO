import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:audioplayers/audioplayers.dart';

enum VoiceMode { audio, text }
enum RecordingState { initial, recording, review, transcribing }

class VoiceRecordingOverlay extends StatefulWidget {
  final String conversationId;
  final VoidCallback onCancel;
  final Function(String path, String transcription) onSendAudio;
  final Function(String text) onSendText;

  const VoiceRecordingOverlay({
    super.key,
    required this.conversationId,
    required this.onCancel,
    required this.onSendAudio,
    required this.onSendText,
  });

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay> {
  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _player = AudioPlayer();

  VoiceMode _mode = VoiceMode.audio;
  RecordingState _state = RecordingState.initial;
  
  String? _path;
  String _transcription = '';
  bool _isSttAvailable = false;
  String _sttStatus = 'Đang khởi tạo...';
  bool _isListening = false;
  
  Timer? _timer;
  int _seconds = 0;
  
  List<double> _amplitudes = [];
  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  void initState() {
    super.initState();
    _initSTT();
  }

  Future<void> _initSTT() async {
    try {
      bool available = await _speech.initialize(
        onError: (error) {
           debugPrint('STT Error: $error');
           if (mounted) setState(() => _sttStatus = 'Lỗi nhận diện');
        },
        onStatus: (status) {
           debugPrint('STT Status: $status');
           if (mounted) {
             setState(() {
               if (status == 'listening') {
                 _sttStatus = 'Đang nhận diện...';
               } else if (status == 'notListening') {
                 _sttStatus = 'Sẵn sàng';
               }
             });
           }
        },
      );
      if (mounted) {
        setState(() {
          _isSttAvailable = available;
          _sttStatus = available ? 'Sẵn sàng' : 'Không hỗ trợ';
        });
      }
    } catch (e) {
      debugPrint('STT Init error: $e');
      if (mounted) setState(() => _sttStatus = 'Lỗi khởi tạo');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _path = path;

      await _recorder.start(const RecordConfig(), path: path);
      
      _startTimer();
      _amplitudes = List.filled(30, 0.0);
      _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        if (mounted) {
          setState(() {
            _amplitudes.removeAt(0);
            // Convert dB to 0.0-1.0 range roughly
            double normalized = (amp.current + 50).clamp(0, 50) / 50;
            _amplitudes.add(normalized);
          });
        }
      });

      setState(() => _state = RecordingState.recording);

      // Always start STT during recording to capture transcription for both modes
      _startSTT();
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _stopSTT();
    
    if (mounted) {
      setState(() {
        _state = RecordingState.review;
        // If STT produced nothing, we might want to try one last check or just leave it
      });
    }
  }

  void _startSTT() async {
    if (!_isSttAvailable) {
      await _initSTT();
    }
    
    if (!_isSttAvailable) return;

    // Determine locale
    var locales = await _speech.locales();
    var localeId = 'vi_VN';
    
    // Fallback if vi_VN is not installed
    bool hasVietnamese = locales.any((l) => l.localeId == 'vi_VN');
    if (!hasVietnamese) {
      if (locales.isNotEmpty) {
        localeId = locales.first.localeId;
        debugPrint('vi_VN not found, fallback to ${locales.first.name}');
      }
    }

    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _transcription = result.recognizedWords;
          });
        }
      },
      localeId: localeId,
      listenFor: const Duration(minutes: 5),
      cancelOnError: false,
    );
  }

  void _stopSTT() async {
    await _speech.stop();
    if (mounted) {
       setState(() => _isListening = false);
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _buildHandle(isDarkMode),
          const SizedBox(height: 32),
          _buildContent(isDarkMode),
          const SizedBox(height: 48),
          _buildBottomActions(isDarkMode),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDarkMode) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildContent(bool isDarkMode) {
    switch (_state) {
      case RecordingState.initial:
        return _buildInitialContent(isDarkMode);
      case RecordingState.recording:
        return _buildRecordingContent(isDarkMode);
      case RecordingState.review:
        return _buildReviewContent(isDarkMode);
      case RecordingState.transcribing:
        return _buildTranscribingContent(isDarkMode);
    }
  }

  Widget _buildInitialContent(bool isDarkMode) {
    return Column(
      children: [
        Text(
          'Bấm hoặc bấm giữ để ghi âm',
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 32),
        _buildRecordButton(isDarkMode),
      ],
    );
  }

  Widget _buildRecordingContent(bool isDarkMode) {
    return Column(
      children: [
        if (_mode == VoiceMode.text && _transcription.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _transcription,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          )
        else ...[
          _buildWaveform(isDarkMode),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isListening ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _sttStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTime(_seconds), 
                style: const TextStyle(fontSize: 14, color: Colors.grey)
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        _buildRecordingControls(isDarkMode),
      ],
    );
  }

  Widget _buildReviewContent(bool isDarkMode) {
    return Column(
      children: [
        // Show transcription preview even in audio mode so user has feedback
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                _transcription.isEmpty 
                    ? '(Không nhận diện được nội dung văn bản)' 
                    : _transcription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.w400,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontStyle: _transcription.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 16),
              if (_mode == VoiceMode.audio) _buildStaticWaveform(isDarkMode),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildReviewControls(isDarkMode),
      ],
    );
  }

  Widget _buildTranscribingContent(bool isDarkMode) {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Đang chuyển đổi...'),
      ],
    );
  }

  Widget _buildWaveform(bool isDarkMode) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _amplitudes.map((amp) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 3,
            height: (amp * 40).clamp(4, 40),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStaticWaveform(bool isDarkMode) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Icon(Icons.multitrack_audio, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Colors.blue, thickness: 1)),
          const SizedBox(width: 8),
          Text(_formatTime(_seconds), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecordButton(bool isDarkMode) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      onTap: () {
        if (_state == RecordingState.initial) {
          _transcription = ''; // Reset for new session
          _startRecording();
        } else if (_state == RecordingState.recording) {
          _stopRecording();
        }
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          _state == RecordingState.recording ? Icons.mic : Icons.mic, 
          color: Colors.white, 
          size: 40
        ),
      ),
    );
  }

  Widget _buildRecordingControls(bool isDarkMode) {
     return _buildRecordButton(isDarkMode);
  }

  Widget _buildReviewControls(bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlIcon(Icons.delete, 'Xóa', isDarkMode, () {
          setState(() {
            _state = RecordingState.initial;
            _transcription = '';
            _seconds = 0;
          });
        }),
        _buildSendButton(isDarkMode),
        if (_mode == VoiceMode.audio)
          _buildControlIcon(Icons.graphic_eq, 'Nghe lại', isDarkMode, () async {
            if (_path != null) {
              await _player.play(DeviceFileSource(_path!));
            }
          })
        else
          _buildControlIcon(Icons.edit_outlined, 'Chỉnh sửa', isDarkMode, () {
            // Implement edit transcription logic if needed
          }),
      ],
    );
  }

  Widget _buildControlIcon(IconData icon, String label, bool isDarkMode, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 28, color: isDarkMode ? Colors.white70 : Colors.black54),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildSendButton(bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        if (_mode == VoiceMode.audio && _path != null) {
          widget.onSendAudio(_path!, _transcription);
        } else {
          widget.onSendText(_transcription);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            'Gửi', 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87
            )
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeToggle('Gửi bản ghi âm', VoiceMode.audio, isDarkMode),
          ),
          Expanded(
            child: _buildModeToggle('Gửi dạng văn bản', VoiceMode.text, isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(String label, VoiceMode mode, bool isDarkMode) {
    final active = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? (isDarkMode ? Colors.white : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: active ? [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
          ] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? Colors.black : (isDarkMode ? Colors.white54 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
