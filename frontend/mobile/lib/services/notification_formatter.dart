import 'dart:convert';

class NotificationDisplayContent {
  final String title;
  final String body;

  const NotificationDisplayContent({
    required this.title,
    required this.body,
  });
}

class NotificationFormatter {
  static const String _defaultTitle = 'VNALO';
  static const String _defaultBody = 'Bạn có một thông báo mới';

  /// Lọc bỏ các chuỗi kỹ thuật không thân thiện (như JSON, Instance of, v.v.)
  static bool _looksLikeTechnicalContent(String? value) {
    if (value == null) return true;

    final text = value.trim();

    if (text.isEmpty) return true;

    if (text == 'null' ||
        text == '{}' ||
        text == '[]' ||
        text.contains('Instance of') ||
        text.contains('[object Object]')) {
      return true;
    }

    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      return true;
    }

    return false;
  }

  /// Trích xuất danh sách giá trị string hợp lệ đầu tiên
  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String) {
        final text = value.trim();
        // Không dùng "Someone", "Unknown" làm kết quả cuối nếu có field khác
        if (text.isNotEmpty && text != 'Someone' && text != 'Unknown' && text != 'null') {
          return text;
        }
      }
    }
    return null;
  }

  /// Parse dữ liệu an toàn để chống rò rỉ field khi lồng ghép JSON string
  static Map<String, dynamic> _tryParseMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        // Invalid JSON: fallback safely.
      }
    }

    return <String, dynamic>{};
  }

  /// Xử lý payload Notification tổng quát để tạo Title và Body hiển thị.
  static NotificationDisplayContent formatNotification({
    required Map<String, dynamic> data,
    String? remoteTitle,
    String? remoteBody,
  }) {
    final root = _tryParseMap(data);
    final nestedData = _tryParseMap(root['data']);
    final nestedPayload = _tryParseMap(root['payload']);

    final sender = _tryParseMap(
      nestedPayload['sender'] ?? nestedData['sender'] ?? root['sender'],
    );
    final actor = _tryParseMap(
      nestedPayload['actor'] ?? nestedData['actor'] ?? root['actor'],
    );
    final caller = _tryParseMap(
      nestedPayload['caller'] ?? nestedData['caller'] ?? root['caller'],
    );

    final String type = (root['type'] ??
            root['eventType'] ??
            nestedData['type'] ??
            nestedPayload['type'] ??
            '')
        .toString()
        .toUpperCase();

    // 1. Trích xuất tên người thao tác
    String? senderName = _firstNonEmptyString([
      root['senderDisplayName'],
      root['senderName'],
      root['displayName'],
      root['callerName'],
      root['callerDisplayName'],
      root['actorName'],
      root['actorDisplayName'],
      root['fromName'],
      nestedData['senderDisplayName'],
      nestedData['senderName'],
      nestedData['displayName'],
      nestedData['callerName'],
      nestedData['actorName'],
      nestedPayload['senderDisplayName'],
      nestedPayload['senderName'],
      nestedPayload['displayName'],
      nestedPayload['callerName'],
      nestedPayload['actorName'],
      sender['displayName'],
      sender['fullName'],
      sender['name'],
      actor['displayName'],
      actor['fullName'],
      actor['name'],
      caller['displayName'],
      caller['fullName'],
      caller['name'],
    ]);

    // Format theo từng loại event
    switch (type) {
      case 'CHAT_MESSAGE':
      case 'NEW_MESSAGE':
      case 'MESSAGE_CREATED':
        return _formatChatMessage(root, nestedData, nestedPayload, senderName);
      
      case 'CALL_INCOMING':
      case 'INCOMING_CALL':
      case 'CALL_OFFER':
      case 'GROUP_CALL_STARTED':
        return _formatIncomingCall(root, nestedData, nestedPayload, senderName, type == 'GROUP_CALL_STARTED');
      
      case 'CALL_MISSED':
      case 'MISSED_CALL':
        return _formatMissedCall(root, senderName);

      case 'FRIEND_REQUEST':
      case 'NEW_FRIEND_REQUEST':
        return NotificationDisplayContent(
          title: senderName ?? 'Lời mời kết bạn',
          body: senderName != null 
              ? 'Đã gửi cho bạn một lời mời kết bạn'
              : 'Bạn nhận được một lời mời kết bạn mới',
        );

      case 'FRIEND_ACCEPTED':
      case 'FRIEND_REQUEST_ACCEPTED':
        return NotificationDisplayContent(
          title: senderName ?? 'Đồng ý kết bạn',
          body: senderName != null 
              ? 'Đã chấp nhận lời mời kết bạn của bạn'
              : 'Một người dùng đã chấp nhận lời mời kết bạn',
        );

      case 'TIMELINE_LIKE':
      case 'POST_LIKE':
        return NotificationDisplayContent(
          title: senderName ?? 'Lượt thích mới',
          body: senderName != null 
              ? 'Đã thích bài viết của bạn'
              : 'Ai đó đã thích bài viết của bạn',
        );

      case 'TIMELINE_COMMENT':
      case 'POST_COMMENT':
        final comment = root['comment'] ?? nestedData['comment'];
        final commentText = comment is String ? comment : null;
        return NotificationDisplayContent(
          title: senderName ?? 'Bình luận mới',
          body: _looksLikeTechnicalContent(commentText) 
              ? (senderName != null ? 'Đã bình luận về bài viết của bạn' : 'Có một bình luận mới trên bài viết của bạn')
              : commentText!,
        );

      case 'MENTION':
      case 'MENTIONS':
        return NotificationDisplayContent(
          title: senderName ?? 'Tin nhắn mới',
          body: senderName != null ? 'Đã nhắc đến bạn' : 'Bạn được nhắc đến trong một cuộc trò chuyện',
        );

      default:
        // Cố gắng dùng remoteTitle/remoteBody nếu nó là chữ viết an toàn
        if (!_looksLikeTechnicalContent(remoteTitle) && !_looksLikeTechnicalContent(remoteBody)) {
          // Lưu ý: remoteTitle thường từ backend FCM có thể bị "Someone" do backend truyền xuống
          // Chúng ta có thể ghi đè nếu chúng ta tìm thấy senderName hợp lệ và remoteTitle là 'Someone'
          final String finalTitle = (remoteTitle == 'Someone' || remoteTitle == 'Unknown') && senderName != null
              ? senderName
              : (remoteTitle ?? _defaultTitle);
          return NotificationDisplayContent(
            title: finalTitle,
            body: remoteBody!,
          );
        }

        // Nếu nội dung trả về là JSON/raw code hoặc null, fallback an toàn
        return const NotificationDisplayContent(
          title: _defaultTitle,
          body: _defaultBody,
        );
    }
  }

  static NotificationDisplayContent _formatChatMessage(
    Map<String, dynamic> root,
    Map<String, dynamic> nestedData,
    Map<String, dynamic> nestedPayload,
    String? senderName,
  ) {
    final title = senderName ?? 'Tin nhắn mới';

    // Lấy messageType
    final String msgType = (root['messageType'] ??
            nestedData['messageType'] ??
            nestedPayload['messageType'] ??
            'TEXT')
        .toString()
        .toUpperCase();

    // Lấy content
    final String? contentStr = (root['content'] ??
            nestedData['content'] ??
            nestedPayload['content'] ??
            root['body'] ??
            nestedData['body'] ??
            nestedPayload['body'])
        ?.toString();

    String body = '';

    switch (msgType) {
      case 'IMAGE':
        body = 'Đã gửi một hình ảnh';
        break;
      case 'VIDEO':
        body = 'Đã gửi một video';
        break;
      case 'FILE':
        body = 'Đã gửi một tệp';
        break;
      case 'STICKER':
        body = 'Đã gửi một sticker';
        break;
      case 'AUDIO':
      case 'VOICE':
        body = 'Đã gửi một tin nhắn thoại';
        break;
      default:
        // Text hoặc Reply hoặc Default
        if (!_looksLikeTechnicalContent(contentStr)) {
          body = contentStr!;
        } else {
          body = 'Đã gửi một tin nhắn';
        }
    }

    return NotificationDisplayContent(title: title, body: body);
  }

  static NotificationDisplayContent _formatIncomingCall(
    Map<String, dynamic> root,
    Map<String, dynamic> nestedData,
    Map<String, dynamic> nestedPayload,
    String? senderName,
    bool isGroupCall,
  ) {
    final title = senderName ?? (isGroupCall ? 'Cuộc gọi nhóm' : 'Cuộc gọi đến');

    final String callType = (root['callType'] ??
            nestedData['callType'] ??
            nestedPayload['callType'] ??
            '')
        .toString()
        .toLowerCase();
    
    // Fallback if audioOnly flag exists
    final isAudioOnly = (root['audioOnly'] ?? nestedData['audioOnly'] ?? nestedPayload['audioOnly'])?.toString() == 'true';
    final typeIsVideo = callType == 'video' || (!isAudioOnly && callType != 'voice' && callType != 'audio');

    String body;
    if (typeIsVideo) {
      body = 'Cuộc gọi video đến';
    } else {
      body = 'Cuộc gọi thoại đến';
    }

    return NotificationDisplayContent(title: title, body: body);
  }

  static NotificationDisplayContent _formatMissedCall(
    Map<String, dynamic> root,
    String? senderName,
  ) {
    final title = senderName ?? 'Cuộc gọi đến';
    
    final String callType = (root['callType'] ?? '')
        .toString()
        .toLowerCase();

    if (callType == 'video') {
      return NotificationDisplayContent(
        title: title,
        body: 'Bạn có một cuộc gọi video nhỡ',
      );
    } else if (callType == 'voice' || callType == 'audio') {
      return NotificationDisplayContent(
        title: title,
        body: 'Bạn có một cuộc gọi thoại nhỡ',
      );
    } else {
      return NotificationDisplayContent(
        title: title,
        body: 'Bạn có một cuộc gọi nhỡ',
      );
    }
  }
}
