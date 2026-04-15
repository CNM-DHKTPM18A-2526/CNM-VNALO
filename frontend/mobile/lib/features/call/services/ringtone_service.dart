import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class RingtoneService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  RingtoneService() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> startRinging() async {
    if (_isPlaying) return;
    try {
      debugPrint('[RingtoneService] Starting ringing sound...');
      await _player.play(AssetSource('sounds/ringtone.mp3'));
      _isPlaying = true;
    } catch (e) {
      debugPrint('[RingtoneService] Error playing ringtone: $e');
    }
  }

  Future<void> startDialing() async {
    if (_isPlaying) return;
    try {
      debugPrint('[RingtoneService] Starting dialing sound...');
      await _player.play(AssetSource('sounds/dialing.mp3'));
      _isPlaying = true;
    } catch (e) {
      debugPrint('[RingtoneService] Error playing dialing sound: $e');
    }
  }

  Future<void> stop() async {
    if (!_isPlaying) return;
    try {
      debugPrint('[RingtoneService] Stopping sound...');
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('[RingtoneService] Error stopping sound: $e');
    }
  }

  void dispose() {
    unawaited(_player.dispose());
  }
}
