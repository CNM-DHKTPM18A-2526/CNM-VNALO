import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/services/notification_formatter.dart';
import 'dart:convert';

void main() {
  group('NotificationFormatter Tests', () {
    test('Test 1: Tin nhắn text có sender name', () {
      final data = {
        "type": "NEW_MESSAGE",
        "senderName": "Lục Tuyết Kỳ",
        "content": "hello"
      };

      final result = NotificationFormatter.formatNotification(data: data);

      expect(result.title, 'Lục Tuyết Kỳ');
      expect(result.body, 'hello');
    });

    test('Test 2: Tin nhắn text có nested sender', () {
      final data = {
        "type": "NEW_MESSAGE",
        "sender": jsonEncode({
          "displayName": "Lục Tuyết Kỳ"
        }),
        "content": "hello"
      };

      final result = NotificationFormatter.formatNotification(data: data);

      expect(result.title, 'Lục Tuyết Kỳ');
      expect(result.body, 'hello');
    });

    test('Test 3: Tin nhắn thiếu sender name', () {
      final data = {
        "type": "NEW_MESSAGE",
        "content": "hello"
      };

      final result = NotificationFormatter.formatNotification(data: data);

      expect(result.title, 'Tin nhắn mới');
      expect(result.body, 'hello');
    });

    test('Test 4: Cuộc gọi thoại', () {
      final data = {
        "type": "INCOMING_CALL",
        "callerName": "Lục Tuyết Kỳ",
        "callType": "voice"
      };

      final result = NotificationFormatter.formatNotification(data: data);

      expect(result.title, 'Lục Tuyết Kỳ');
      expect(result.body, 'Cuộc gọi thoại đến');
    });

    test('Test 5: Cuộc gọi video', () {
      final data = {
        "type": "INCOMING_CALL",
        "callerName": "Lục Tuyết Kỳ",
        "callType": "video"
      };

      final result = NotificationFormatter.formatNotification(data: data);

      expect(result.title, 'Lục Tuyết Kỳ');
      expect(result.body, 'Cuộc gọi video đến');
    });

    test('Test 6: Raw JSON body bị fallback', () {
      final data = {
        "type": "UNKNOWN_TYPE"
      };

      final result = NotificationFormatter.formatNotification(
        data: data,
        remoteTitle: 'VNALO',
        remoteBody: '{"callerId":"abc","callId":"xyz"}'
      );

      expect(result.title, 'VNALO');
      expect(result.body, 'Bạn có một thông báo mới');
    });

    test('Test 7: Type chưa hỗ trợ', () {
      final data = {
        "type": "FUTURE_EVENT"
      };

      final result = NotificationFormatter.formatNotification(data: data);

      expect(result.title, 'VNALO');
      expect(result.body, 'Bạn có một thông báo mới');
    });

    test('Test 8: "Someone" không được ưu tiên nếu có field khác', () {
      final data = {
        "type": "NEW_MESSAGE",
        "senderName": "Someone",
        "data": jsonEncode({
            "senderDisplayName": "Lục Tuyết Kỳ"
        }),
        "content": "hello"
      };

      final result = NotificationFormatter.formatNotification(data: data);

      expect(result.title, 'Lục Tuyết Kỳ');
      expect(result.body, 'hello');
    });

    test('Test 9: JSON object in content field is fallback to safe text', () {
      final data = {
        "type": "CHAT_MESSAGE",
        "senderName": "Lý Liên Kiệt",
        "content": "{\"action\":\"leave_group\"}"
      };

      final result = NotificationFormatter.formatNotification(data: data);

      expect(result.title, 'Lý Liên Kiệt');
      expect(result.body, 'Đã gửi một tin nhắn');
    });
  });
}
