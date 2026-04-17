import 'package:flutter/material.dart';
import 'package:vnalo_mobile/services/ai_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum AiState { idle, listening, thinking, speaking }

class AiAssistantProvider with ChangeNotifier {
  final AiService _aiService;
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  AiState _state = AiState.idle;
  String _lastWords = '';
  String _aiResponse = '';
  bool _isMascotVisible = true;

  AiAssistantProvider(this._aiService) {
    _initTts();
  }

  AiState get state => _state;
  String get lastWords => _lastWords;
  String get aiResponse => _aiResponse;
  bool get isMascotVisible => _isMascotVisible;

  void _initTts() {
    _tts.setLanguage("vi-VN");
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.5);
  }

  void toggleMascot() {
    _isMascotVisible = !_isMascotVisible;
    notifyListeners();
  }

  Future<void> startListening() async {
    bool available = await _stt.initialize(
      onStatus: (status) => debugPrint('STT Status: $status'),
      onError: (error) => debugPrint('STT Error: $error'),
    );

    if (available) {
      _state = AiState.listening;
      _lastWords = '';
      notifyListeners();

      await _stt.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          if (result.finalResult) {
            _handleCommand(_lastWords);
          }
          notifyListeners();
        },
        localeId: "vi_VN",
      );
    }
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _state = AiState.idle;
    notifyListeners();
  }

  Future<void> _handleCommand(String text) async {
    if (text.isEmpty) return;

    _state = AiState.thinking;
    notifyListeners();

    try {
      final response = await _aiService.chat(text, analyzeIntent: true);
      
      _aiResponse = response['textReply'] ?? '';
      final actionCommand = response['actionCommand'];
      final actionParams = response['actionParams'];

      if (actionCommand != null) {
        _executeSystemAction(actionCommand, actionParams);
      }

      if (_aiResponse.isNotEmpty) {
        _state = AiState.speaking;
        notifyListeners();
        await _tts.speak(_aiResponse);
      }

      _state = AiState.idle;
    } catch (e) {
      debugPrint('AI Error: $e');
      _aiResponse = 'Xin lỗi, tôi đang gặp chút trục trặc mạng.';
      await _tts.speak(_aiResponse);
      _state = AiState.idle;
    }
    notifyListeners();
  }

  void _executeSystemAction(String command, dynamic params) {
     debugPrint('AI System Action: $command with params $params');
     // Future logic to trigger calls or navigation
  }
}
