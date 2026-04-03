import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';

class _FakeApiService extends ApiService {
  _FakeApiService(this.payload) : super(StorageService());

  final Map<String, dynamic> payload;

  @override
  Future<Map<String, dynamic>> get(
    String baseUrl,
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    return payload;
  }
}

void main() {
  setUpAll(() {
    AppConfig.initialize(Environment.dev);
  });

  test('getInbox maps nested inbox entries from message-service', () async {
    final api = _FakeApiService({
      'data': [
        {
          'conversationId': 'conv-1',
          'unreadCount': 3,
          'isPinned': true,
          'lastMessagePreview': 'Xin chao',
          'lastMessageAt': '2026-03-28T00:00:00Z',
          'lastMessageType': 'TEXT',
          'lastMessageSenderId': 'user-2',
          'conversation': {
            'id': 'conv-1',
            'type': 'DIRECT',
            'title': 'Chat 1',
            'status': 'ACTIVE',
          },
        },
      ],
    });

    final service = ChatService(api);
    final items = await service.getInbox();

    expect(items.length, 1);
    expect(items.first.id, 'conv-1');
    expect(items.first.unreadCount, 3);
    expect(items.first.isPinned, true);
    expect(items.first.lastMessage?.content, 'Xin chao');
  });
}
