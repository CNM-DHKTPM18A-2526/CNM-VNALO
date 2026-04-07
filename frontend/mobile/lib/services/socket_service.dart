import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class SocketService {
  io.Socket? _socket;

  final _messageController =
      StreamController<
        Message
      >.broadcast(); // Stream controller for incoming messages
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Message> get onMessage =>
      _messageController.stream; // Stream for incoming messages
  Stream<Map<String, dynamic>> get onTyping =>
      _typingController.stream; // Stream for typing indicators
  Stream<Map<String, dynamic>> get onPresence =>
      _presenceController.stream; // Stream for presence updates

  void connect(String token) {
    _socket = io.io(
      '${AppConfig.instance.socketUrl}/chat',
      io.OptionBuilder()
          .setTransports([
            'websocket',
            'polling',
          ]) // Use the same transports as gateway
          .setAuth({'token': token}) // Set the authentication token
          .enableAutoConnect() // Enable auto-connect
          .enableReconnection() // Enable reconnection
          .setReconnectionDelay(1000) // Set reconnection delay to 1 second
          .setReconnectionAttempts(10) // Set maximum reconnection attempts
          .build(),
    );

    _socket!.onConnect((_) => debugPrint('Connected to socket server'));
    _socket!.onDisconnect((_) => debugPrint('Disconnected from socket server'));

    // Listen for incoming messages, typing indicators, and presence updates
    _socket!.on('message.received', (data) {
      _messageController.add(
        Message.fromJson(data),
      ); // Add incoming message to the stream
    });

    _socket!.on('message.sent', (data) {
      _messageController.add(
        Message.fromJson(data),
      ); // Add sent message to the stream (for optimistic UI updates)
    });

    _socket!.on('message.typing', (data) {
      _typingController.add(
        Map<String, dynamic>.from(data),
      ); // Add typing indicator data to the stream
    });

    _socket!.on('presence.changed', (data) {
      _presenceController.add(
        Map<String, dynamic>.from(data),
      ); // Add presence update data to the stream (e.g., user online/offline status)
    });
  }

  // Join a conversation by emitting a 'conversation.join' event with the conversation ID
  void joinConversation(String conversationId) {
    _socket?.emit('conversation.join', {'conversationId': conversationId});
  }

  // Leave a conversation by emitting a 'conversation.leave' event with the conversation ID
  void leaveConversation(String conversationId) {
    _socket?.emit('conversation.leave', {'conversationId': conversationId});
  }

  // Send a message by emitting a 'message.send' event with the conversation ID,
  //message content, and optional message type and client message ID
  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'TEXT',
    String? clientMessageId,
  }) async {
    if (_socket == null) {
      return null;
    }

    final completer = Completer<Map<String, dynamic>?>();
    _socket?.emitWithAck(
      'message.send',
      {
      'conversationId': conversationId,
      'content': content,
      'messageType': messageType,
      'clientMessageId': clientMessageId,
      },
      ack: (data) {
        if (data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
          return;
        }
        completer.complete(null);
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );
  }

  void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('message.typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  void markRead(String conversationId, int lastReadSeq) {
    _socket?.emit('message.read', {
      'conversationId': conversationId,
      'lastReadSeq': lastReadSeq,
    });
  }

  void disconnect() {
    _socket?.disconnect(); // Disconnect from the socket server
    _socket?.dispose(); // Dispose the socket instance to free up resources
    _socket = null; // Set the socket instance to null
  }

  void dispose() {
    disconnect(); // Disconnect from the socket server and dispose the socket instance
    _messageController.close(); // Close the message stream controller
    _typingController.close(); // Close the typing stream controller
    _presenceController.close(); // Close the presence stream controller
  }
}
