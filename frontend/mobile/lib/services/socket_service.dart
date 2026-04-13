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
  final _readController = StreamController<Map<String, dynamic>>.broadcast();
  final _deliveredController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _recalledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _callSignalController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Message> get onMessage =>
      _messageController.stream; // Stream for incoming messages
  Stream<Map<String, dynamic>> get onTyping =>
      _typingController.stream; // Stream for typing indicators
  Stream<Map<String, dynamic>> get onPresence =>
      _presenceController.stream; // Stream for presence updates
  Stream<Map<String, dynamic>> get onRead => _readController.stream;
  Stream<Map<String, dynamic>> get onDelivered => _deliveredController.stream;
  Stream<Map<String, dynamic>> get onRecalled => _recalledController.stream;
  Stream<Map<String, dynamic>> get onCallSignal => _callSignalController.stream;

  void _emitCallSignal(String type, dynamic data) {
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    _callSignalController.add({'type': type, ...payload});
  }

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

    _socket!.on('message.read', (data) {
      _readController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message.delivered', (data) {
      _deliveredController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message.recalled', (data) {
      _recalledController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('call.offer', (data) => _emitCallSignal('offer', data));
    _socket!.on('call.answer', (data) => _emitCallSignal('answer', data));
    _socket!.on(
      'call.ice-candidate',
      (data) => _emitCallSignal('ice-candidate', data),
    );
    _socket!.on('call.end', (data) => _emitCallSignal('end', data));
    _socket!.on('call.signal', (data) {
      if (data is! Map) return;
      final payload = Map<String, dynamic>.from(data);
      final type = payload['type']?.toString();
      if (type == null || type.isEmpty) return;
      _callSignalController.add(payload);
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
    String? mediaUrl,
    String? mediaThumbnailUrl,
    String? mediaMimeType,
    int? mediaSizeBytes,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToContent,
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
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaThumbnailUrl != null) 'mediaThumbnailUrl': mediaThumbnailUrl,
        if (mediaMimeType != null) 'mediaMimeType': mediaMimeType,
        if (mediaSizeBytes != null) 'mediaSizeBytes': mediaSizeBytes,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
        if (replyToContent != null) 'replyToContent': replyToContent,
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

  void markDelivered(String messageId, String conversationId) {
    _socket?.emit('message.delivered', {
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  void recallMessage(String messageId, String conversationId) {
    _socket?.emit('message.recall', {
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  void sendCallOffer({
    required String conversationId,
    required String callId,
    required String targetUserId,
    required Map<String, dynamic> sdp,
  }) {
    _socket?.emit('call.offer', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      'sdp': sdp,
    });
  }

  void sendCallAnswer({
    required String conversationId,
    required String callId,
    required String targetUserId,
    required Map<String, dynamic> sdp,
  }) {
    _socket?.emit('call.answer', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      'sdp': sdp,
    });
  }

  void sendCallIceCandidate({
    required String conversationId,
    required String callId,
    required String targetUserId,
    required Map<String, dynamic> candidate,
  }) {
    _socket?.emit('call.ice-candidate', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      'candidate': candidate,
    });
  }

  void endCall({
    required String conversationId,
    required String callId,
    required String targetUserId,
  }) {
    _socket?.emit('call.end', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
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
    _readController.close();
    _deliveredController.close();
    _recalledController.close();
    _callSignalController.close();
  }
}
