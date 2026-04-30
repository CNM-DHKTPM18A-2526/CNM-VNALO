import 'dart:convert';

enum CallMediaType { voice, video }

enum CallOutcome { answered, declined, missed, busy, canceled, failed }

class CallLogMessage {
  static const String _prefix = 'CALL_LOG::';

  final String callId;
  final String conversationId;
  final String callerId;
  final String calleeId;
  final CallMediaType mediaType;
  final CallOutcome outcome;
  final int durationSeconds;
  final DateTime createdAt;
  final bool isGroup;

  const CallLogMessage({
    required this.callId,
    required this.conversationId,
    required this.callerId,
    required this.calleeId,
    required this.mediaType,
    required this.outcome,
    required this.durationSeconds,
    required this.createdAt,
    this.isGroup = false,
  });

  String toMessageContent() {
    final payload = {
      'v': 1,
      'callId': callId,
      'conversationId': conversationId,
      'callerId': callerId,
      'calleeId': calleeId,
      'mediaType': mediaType.name,
      'outcome': outcome.name,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'isGroup': isGroup,
    };
    return '$_prefix${jsonEncode(payload)}';
  }

  String toLocalizedText({required bool isMine}) {
    final incoming = !isMine;
    final isVideo = mediaType == CallMediaType.video;
    
    if (isGroup) {
      final base = isVideo ? 'Cuộc gọi video nhóm' : 'Cuộc gọi thoại nhóm';
      if (outcome == CallOutcome.answered) {
        final minutes = durationSeconds ~/ 60;
        final seconds = durationSeconds % 60;
        final durationText = '($minutes:${seconds.toString().padLeft(2, '0')})';
        return '$base $durationText';
      }
      return base;
    }

    final base = isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';

    switch (outcome) {
      case CallOutcome.answered:
        final minutes = durationSeconds ~/ 60;
        final seconds = durationSeconds % 60;
        final durationText = '($minutes:${seconds.toString().padLeft(2, '0')})';
        return '${incoming ? '$base đến' : '$base đi'} $durationText';
      case CallOutcome.declined:
        return incoming ? 'Bạn đã từ chối' : 'Người nhận đã từ chối';
      case CallOutcome.missed:
        return incoming ? 'Bạn bị nhỡ' : 'Không trả lời';
      case CallOutcome.busy:
        return incoming ? 'Bạn bận' : 'Người nhận bận';
      case CallOutcome.canceled:
        return incoming ? 'Cuộc gọi đã hủy' : 'Bạn đã hủy cuộc gọi';
      case CallOutcome.failed:
        return 'Cuộc gọi thất bại';
    }
  }

  static CallLogMessage? tryParse(String? content) {
    if (content == null) return null;

    final index = content.indexOf(_prefix);
    if (index == -1) return null;

    try {
      // Tìm phần nội dung sau tiền tố
      String jsonPart = content.substring(index + _prefix.length).trim();
      
      // Tìm vị trí của dấu { đầu tiên và } cuối cùng để trích xuất JSON sạch
      final start = jsonPart.indexOf('{');
      final end = jsonPart.lastIndexOf('}');
      if (start == -1 || end == -1 || start >= end) return null;
      
      jsonPart = jsonPart.substring(start, end + 1);
      
      // Unescape toàn diện (loại bỏ \" và các ký tự escape lồng nhau)
      jsonPart = jsonPart.replaceAll('\\"', '"').replaceAll('\\\\', '\\');

      final decoded = jsonDecode(jsonPart);
      if (decoded is! Map) return null;

      final map = Map<String, dynamic>.from(decoded);
      final mediaType = _enumOrDefault(
        CallMediaType.values,
        map['mediaType']?.toString(),
        CallMediaType.voice,
      );
      final outcome = _enumOrDefault(
        CallOutcome.values,
        map['outcome']?.toString(),
        CallOutcome.answered,
      );

      return CallLogMessage(
        callId: map['callId'] ?? '',
        conversationId: map['conversationId'] ?? '',
        callerId: map['callerId'] ?? '',
        calleeId: map['calleeId'] ?? '',
        mediaType: mediaType,
        outcome: outcome,
        durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        isGroup: map['isGroup'] == true,
      );
    } catch (e) {
      return null;
    }
  }

  static T _enumOrDefault<T>(List<T> values, String? value, T fallback) {
    if (value == null || value.isEmpty) return fallback;
    for (final item in values) {
      if (item.toString().split('.').last == value) return item;
    }
    return fallback;
  }
}
