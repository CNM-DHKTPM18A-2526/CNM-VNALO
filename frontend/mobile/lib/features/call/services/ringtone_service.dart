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
    try {
      debugPrint('[RingtoneService] Starting ringing sound...');
      _isPlaying = true;
      await _player.play(AssetSource('sounds/ringtone.mp3'));
    } catch (e) {
      debugPrint('[RingtoneService] Error playing ringtone: $e');
    }
  }

  Future<void> startDialing() async {
    try {
      debugPrint('[RingtoneService] Starting dialing sound...');
      _isPlaying = true;
      await _player.play(AssetSource('sounds/dialing.mp3'));
    } catch (e) {
      debugPrint('[RingtoneService] Error playing dialing sound: $e');
    }
  }

  Future<void> stop() async {
    try {
      debugPrint('[RingtoneService] Stopping sound...');
      _isPlaying = false;
      await _player.stop();
    } catch (e) {
      debugPrint('[RingtoneService] Error stopping sound: $e');
    }
  }

  void dispose() {
    unawaited(_player.dispose());
  }
}
