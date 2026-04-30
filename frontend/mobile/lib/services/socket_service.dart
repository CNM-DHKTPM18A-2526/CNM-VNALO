import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/services/auth_events.dart';

class SocketService {
  io.Socket? _socket;
  final _joinedRooms = <String>{};
  final _pendingRoomJoins = <String>{};

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
  final _pinnedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _unpinnedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _callSignalController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _callErrorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _reactionAddedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _reactionRemovedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _groupDisbandedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _friendshipUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _friendRequestReceivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _groupSettingsChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _groupMemberAddedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _groupMemberRemovedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _groupRoleChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _groupAdminTransferredController =
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
  Stream<Map<String, dynamic>> get onPinned => _pinnedController.stream;
  Stream<Map<String, dynamic>> get onUnpinned => _unpinnedController.stream;
  Stream<Map<String, dynamic>> get onCallSignal => _callSignalController.stream;
  Stream<Map<String, dynamic>> get onCallError => _callErrorController.stream;
  Stream<Map<String, dynamic>> get onReactionAdded => _reactionAddedController.stream;
  Stream<Map<String, dynamic>> get onReactionRemoved => _reactionRemovedController.stream;
  Stream<Map<String, dynamic>> get onGroupDisbanded => _groupDisbandedController.stream;
  Stream<Map<String, dynamic>> get onFriendshipUpdated => _friendshipUpdatedController.stream;
  Stream<Map<String, dynamic>> get onFriendRequestReceived => _friendRequestReceivedController.stream;
  Stream<Map<String, dynamic>> get onGroupSettingsChanged => _groupSettingsChangedController.stream;
  Stream<Map<String, dynamic>> get onGroupMemberAdded => _groupMemberAddedController.stream;
  Stream<Map<String, dynamic>> get onGroupMemberRemoved => _groupMemberRemovedController.stream;
  Stream<Map<String, dynamic>> get onGroupRoleChanged => _groupRoleChangedController.stream;
  Stream<Map<String, dynamic>> get onGroupAdminTransferred => _groupAdminTransferredController.stream;

  void _emitCallSignal(String type, dynamic data) {
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    debugPrint(
      '🟢 [SocketService][CALL][RECV] type=$type callId=${payload['callId']} conversationId=${payload['conversationId']} sender=${payload['senderUserId'] ?? payload['senderId'] ?? payload['fromUserId']} target=${payload['targetUserId'] ?? payload['toUserId']}',
    );
    _callSignalController.add({'type': type, ...payload});
  }

  void connect(String token) {
    debugPrint('[SocketService] connect() called — socketUrl=${AppConfig.instance.socketUrl}/chat');
    debugPrint('[SocketService] token present: ${token != null && token.isNotEmpty}');
    debugPrint('[SocketService] existing socket: ${_socket != null}, connected: ${_socket?.connected}');

    if (_socket != null && _socket!.connected) {
      debugPrint('[SocketService] Already connected, skipping connect.');
      return;
    }

    if (_socket != null) {
      debugPrint('[SocketService] Disposing existing socket.');
      disconnect();
    }

    final url = '${AppConfig.instance.socketUrl}/chat';
    debugPrint('[SOCKET] 🔌 Connecting to: $url');
    debugPrint('[SOCKET]   Path: /socket.io/');
    debugPrint('[SOCKET]   Token: ${token.substring(0, 10)}...');

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports([
            'websocket',
            'polling',
          ])
          .setAuth({'token': token})
          .setPath('/socket.io/')
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _setupListeners();
  }

  void _setupListeners() {
    if (_socket == null) return;

    // Re-register all event listeners (called on connect and reconnect)
    _socket!.onConnect((_) {
      debugPrint('[SOCKET] 🟢🟢🟢 CONNECTED to gateway - ID: ${_socket?.id}');
      // Re-join all previously joined rooms after reconnect
      debugPrint('[SocketService] Re-joining ${_joinedRooms.length} rooms...');
      for (final room in _joinedRooms) {
        _socket!.emit('conversation.join', {'conversationId': room});
        debugPrint('[SocketService]   → Joined room: $room');
      }
      // Process any pending room joins (queued while socket was disconnected)
      if (_pendingRoomJoins.isNotEmpty) {
        debugPrint('[SocketService] Processing ${_pendingRoomJoins.length} pending room joins...');
        for (final room in _pendingRoomJoins) {
          if (!_joinedRooms.contains(room)) {
            _socket!.emit('conversation.join', {'conversationId': room});
            _joinedRooms.add(room);
            debugPrint('[SocketService]   → Pending room joined: $room');
          }
        }
        _pendingRoomJoins.clear();
      }
      _connectController.add(null);
      _onSocketReady?.call();
    });
    
    _socket!.onDisconnect((data) {
      debugPrint('[SOCKET] 🔴 DISCONNECTED from gateway: $data');
    });

    _socket!.onConnectError((data) {
      debugPrint('[SOCKET] ⚠️ Connect Error: $data');
    });

    _socket!.onError((data) {
      debugPrint('[SOCKET] ❌ General Error: $data');
    });

    // Listen for incoming messages, typing indicators, and presence updates
    _socket!.on('message.received', (data) {
      debugPrint('[SOCKET] 📨 message.received: $data');
      try {
        final message = Message.fromJson(data);
        debugPrint('[SocketService][RECV] ✅ Parsed message ID: ${message.id} conv: ${message.conversationId} sender: ${message.senderId}');
        _messageController.add(message);
      } catch (e) {
        debugPrint('[SocketService][RECV] ❌ ERROR parsing message: $e');
      }
    });

    _socket!.on('message.sent', (data) {
      debugPrint('[SocketService][RECV] 📤 message.sent: $data');
      try {
        final msg = Message.fromJson(data);
        debugPrint('[SocketService][RECV] ✅ Parsed message.sent ID: ${msg.id} conv: ${msg.conversationId}');
        _messageController.add(msg);
      } catch (e) {
        debugPrint('[SocketService][RECV] ❌ ERROR parsing message.sent: $e');
      }
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

    _socket!.on('message.pinned', (data) {
      debugPrint('[SocketService] RECEIVED message.pinned raw: ${data.runtimeType} = $data');
      _pinnedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message.unpinned', (data) {
      debugPrint('[SocketService] RECEIVED message.unpinned raw: ${data.runtimeType} = $data');
      _unpinnedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('call.offer', (data) => _emitCallSignal('offer', data));
    _socket!.on('call.answer', (data) => _emitCallSignal('answer', data));
    _socket!.on(
      'call.ice-candidate',
      (data) => _emitCallSignal('ice-candidate', data),
    );
    _socket!.on('call.end', (data) => _emitCallSignal('end', data));
    _socket!.on('call.error', (data) {
      final payload =
          data is Map
              ? Map<String, dynamic>.from(data)
              : {
                'error':
                    data?.toString() ?? 'Unknown call signaling error from server',
              };
      debugPrint('[SocketService][CALL][ERROR] payload=$payload');
      _callErrorController.add(payload);
    });
    _socket!.on('call.signal', (data) {
      if (data is! Map) return;
      final payload = Map<String, dynamic>.from(data);
      _callSignalController.add(payload);
    });

    _socket!.on('message.reaction.added', (data) {
      _reactionAddedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message.reaction.removed', (data) {
      _reactionRemovedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('group.disbanded', (data) {
      _groupDisbandedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('group.settingsChanged', (data) {
      debugPrint('[SocketService] group.settingsChanged received: $data');
      _groupSettingsChangedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('group.memberAdded', (data) {
      debugPrint('[SocketService] group.memberAdded received: $data');
      _groupMemberAddedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('group.memberRemoved', (data) {
      debugPrint('[SocketService] group.memberRemoved received: $data');
      _groupMemberRemovedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('group.roleChanged', (data) {
      debugPrint('[SocketService] group.roleChanged received: $data');
      _groupRoleChangedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('group.adminTransferred', (data) {
      debugPrint('[SocketService] group.adminTransferred received: $data');
      _groupAdminTransferredController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('friendship.updated', (data) {
      _friendshipUpdatedController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('friend.request.received', (data) {
      _friendRequestReceivedController.add(Map<String, dynamic>.from(data));
    });

    // ─── Group Call Signal Listeners ────────────────────────────────────────
    void _emitGroupCallSignal(String type, dynamic data) {
      if (data is! Map) return;
      final payload = Map<String, dynamic>.from(data);
      _groupCallSignalController.add({'type': type, ...payload});
    }

    _socket!.on('group-call:started', (data) {
      debugPrint('[SocketService] 🔔🔔🔔 group-call:started received: $data');
      _emitGroupCallSignal('started', data);
    });
    _socket!.on('group-call:join', (data) {
      debugPrint('[SocketService] 🔔 group-call:join received: $data');
      _emitGroupCallSignal('join', data);
    });
    _socket!.on('group-call:user-joined', (data) {
      _emitGroupCallSignal('user-joined', data);
    });
    _socket!.on('group-call:offer', (data) {
      _emitGroupCallSignal('offer', data);
    });
    _socket!.on('group-call:answer', (data) {
      _emitGroupCallSignal('answer', data);
    });
    _socket!.on('group-call:ice-candidate', (data) {
      _emitGroupCallSignal('ice-candidate', data);
    });
    _socket!.on('group-call:user-left', (data) {
      _emitGroupCallSignal('user-left', data);
    });
    _socket!.on('group-call:ended', (data) {
      debugPrint('[SocketService] group-call:ended received: $data');
      _emitGroupCallSignal('ended', data);
    });
    _socket!.on('group-call:mute-state', (data) {
      _emitGroupCallSignal('mute-state', data);
    });

    _socket!.on('auth.logout.force', (data) {
      final reason = data is Map ? data['reason']?.toString() : null;
      AuthEvents.onForceLogout?.call(reason ?? 'Tài khoản đã đăng nhập từ thiết bị khác');
    });
  }

  // Join a conversation by emitting a 'conversation.join' event with the conversation ID
  void joinConversation(String conversationId) {
    if (_joinedRooms.contains(conversationId)) {
      debugPrint('[SocketService] joinConversation: already joined $conversationId');
      return;
    }
    
    if (_socket == null) {
      debugPrint('[SocketService] joinConversation FAILED: socket is null');
      return;
    }
    
    if (!_socket!.connected) {
      debugPrint('[SocketService] joinConversation WARNING: socket not connected yet, queuing for retry');
      _pendingRoomJoins.add(conversationId);
      return;
    }
    
    debugPrint('[SocketService] joinConversation: conv=$conversationId connected=${_socket!.connected}');
    _socket?.emit('conversation.join', {'conversationId': conversationId});
    _joinedRooms.add(conversationId);
    debugPrint('[SocketService] ✅ Joined room (total: ${_joinedRooms.length}): $conversationId');
  }

  // Leave a conversation by emitting a 'conversation.leave' event with the conversation ID
  void leaveConversation(String conversationId) {
    _socket?.emit('conversation.leave', {'conversationId': conversationId});
    _joinedRooms.remove(conversationId);
  }

  // Send a message by emitting a 'message.send' event with the conversation ID,
  //message content, and optional message type and client message ID.
  // Uses fire-and-forget: message.sent event will update UI when server confirms.
  void sendMessage({
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
  }) {
    if (_socket == null) {
      debugPrint('[SocketService] sendMessage FAILED: socket is null');
      return;
    }
    if (!_socket!.connected) {
      debugPrint('[SocketService] sendMessage FAILED: socket not connected');
      return;
    }

    debugPrint('[SocketService] sendMessage: conv=$conversationId type=$messageType clientId=$clientMessageId mediaUrl=$mediaUrl connected=${_socket?.connected}');
    _socket?.emit(
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

  void pinMessage(String messageId, String conversationId) {
    debugPrint('[SocketService] EMIT message.pin: messageId=$messageId conversationId=$conversationId isConnected=$isConnected()');
    if (!isConnected()) {
      debugPrint('[SocketService] ERROR: socket not connected, cannot pin!');
    }
    _socket?.emit('message.pin', {
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  void unpinMessage(String messageId, String conversationId) {
    debugPrint('[SocketService] EMIT message.unpin: messageId=$messageId conversationId=$conversationId isConnected=$isConnected()');
    if (!isConnected()) {
      debugPrint('[SocketService] ERROR: socket not connected, cannot unpin!');
    }
    _socket?.emit('message.unpin', {
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  void sendCallOffer({
    required String conversationId,
    required String callId,
    required String targetUserId,
    String? senderUserId,
    required bool audioOnly,
    required Map<String, dynamic> sdp,
  }) {
    debugPrint(
      '[SocketService][CALL][SEND] type=offer callId=$callId conversationId=$conversationId sender=$senderUserId target=$targetUserId',
    );
    _socket?.emit('call.offer', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      if (senderUserId != null) 'senderUserId': senderUserId,
      'audioOnly': audioOnly,
      'sdp': sdp,
    });
  }

  void sendCallAnswer({
    required String conversationId,
    required String callId,
    required String targetUserId,
    String? senderUserId,
    required Map<String, dynamic> sdp,
  }) {
    debugPrint(
      '[SocketService][CALL][SEND] type=answer callId=$callId conversationId=$conversationId sender=$senderUserId target=$targetUserId',
    );
    _socket?.emit('call.answer', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      if (senderUserId != null) 'senderUserId': senderUserId,
      'sdp': sdp,
    });
  }

  void sendCallIceCandidate({
    required String conversationId,
    required String callId,
    required String targetUserId,
    String? senderUserId,
    required Map<String, dynamic> candidate,
  }) {
    debugPrint(
      '[SocketService][CALL][SEND] type=ice-candidate callId=$callId conversationId=$conversationId sender=$senderUserId target=$targetUserId',
    );
    _socket?.emit('call.ice-candidate', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      if (senderUserId != null) 'senderUserId': senderUserId,
      'candidate': candidate,
    });
  }

  void endCall({
    required String conversationId,
    required String callId,
    required String targetUserId,
    String? senderUserId,
    String? reason,
  }) {
    debugPrint(
      '[SocketService][CALL][SEND] type=end callId=$callId conversationId=$conversationId sender=$senderUserId target=$targetUserId reason=$reason',
    );
    _socket?.emit('call.end', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      if (senderUserId != null) 'senderUserId': senderUserId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  void addReaction(String messageId, String emoji) {
    _socket?.emit('message.reaction.add', {
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  void removeReaction(String messageId) {
    _socket?.emit('message.reaction.remove', {
      'messageId': messageId,
    });
  }

  // ─── Group Call Signaling ─────────────────────────────────────────────────

  void emitGroupCallStarted({
    required String conversationId,
    required String callId,
    required bool audioOnly,
    required String senderUserId,
    String? senderName,
    String? senderAvatarUrl,
    List<String>? targetUserIds,
  }) {
    debugPrint('[SocketService][GROUP_CALL][SEND] started callId=$callId conv=$conversationId targets=$targetUserIds');
    _socket?.emit('group-call:started', {
      'conversationId': conversationId,
      'callId': callId,
      'audioOnly': audioOnly,
      'senderUserId': senderUserId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      if (targetUserIds != null) 'targetUserIds': targetUserIds,
    });
  }

  void emitGroupCallJoin({
    required String conversationId,
    required String callId,
    required String senderUserId,
    String? senderName,
    String? senderAvatarUrl,
  }) {
    _socket?.emit('group-call:join', {
      'conversationId': conversationId,
      'callId': callId,
      'senderUserId': senderUserId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
    });
  }

  void emitGroupCallOffer({
    required String conversationId,
    required String callId,
    required String targetUserId,
    required Map<String, dynamic> sdp,
    required String senderUserId,
  }) {
    debugPrint('[SocketService][GROUP_CALL][SEND] offer callId=$callId target=$targetUserId');
    _socket?.emit('group-call:offer', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      'sdp': sdp,
      'senderUserId': senderUserId,
    });
  }

  void emitGroupCallAnswer({
    required String conversationId,
    required String callId,
    required String targetUserId,
    required Map<String, dynamic> sdp,
    required String senderUserId,
  }) {
    _socket?.emit('group-call:answer', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      'sdp': sdp,
      'senderUserId': senderUserId,
    });
  }

  void emitGroupCallIceCandidate({
    required String conversationId,
    required String callId,
    required String targetUserId,
    required Map<String, dynamic> candidate,
    required String senderUserId,
  }) {
    _socket?.emit('group-call:ice-candidate', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      'candidate': candidate,
      'senderUserId': senderUserId,
    });
  }

  void emitGroupCallLeave({
    required String conversationId,
    required String callId,
    required String senderUserId,
  }) {
    _socket?.emit('group-call:leave', {
      'conversationId': conversationId,
      'callId': callId,
      'senderUserId': senderUserId,
    });
  }

  void emitGroupCallEnded({
    required String conversationId,
    required String callId,
  }) {
    debugPrint('[SocketService][GROUP_CALL][SEND] ended callId=$callId');
    _socket?.emit('group-call:ended', {
      'conversationId': conversationId,
      'callId': callId,
    });
  }

  void emitGroupCallMuteState({
    required String conversationId,
    required String callId,
    bool? isMuted,
    bool? isCameraOff,
  }) {
    _socket?.emit('group-call:mute-state', {
      'conversationId': conversationId,
      'callId': callId,
      if (isMuted != null) 'isMuted': isMuted,
      if (isCameraOff != null) 'isCameraOff': isCameraOff,
    });
  }

  // ─── Stream for group call signals ────────────────────────────────────────

  final _groupCallSignalController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectController = StreamController<void>.broadcast();
  
  // Callback for when socket is ready (connected and authenticated)
  VoidCallback? _onSocketReady;

  Stream<Map<String, dynamic>> get onGroupCallSignal => _groupCallSignalController.stream;
  Stream<void> get onConnectStream => _connectController.stream;

  /// Set a callback to be called when socket is ready (connected)
  void setOnSocketReady(VoidCallback? callback) {
    _onSocketReady = callback;
    // If already connected, call it immediately
    if (_socket?.connected == true) {
      debugPrint('[SocketService] Socket already connected, calling onSocketReady immediately');
      _onSocketReady?.call();
    }
  }

  bool isConnected() {
    return _socket != null && _socket!.connected;
  }

  void disconnect() {
    _socket?.disconnect(); // Disconnect from the socket server
    _socket?.dispose(); // Dispose the socket instance to free up resources
    _socket = null; // Set the socket instance to null
    _joinedRooms.clear(); // Clear joined rooms on disconnect
  }

  void dispose() {
    disconnect(); // Disconnect from the socket server and dispose the socket instance
    _messageController.close(); // Close the message stream controller
    _typingController.close(); // Close the typing stream controller
    _presenceController.close(); // Close the presence stream controller
    _readController.close();
    _deliveredController.close();
    _recalledController.close();
    _pinnedController.close();
    _unpinnedController.close();
    _callSignalController.close();
    _callErrorController.close();
    _reactionAddedController.close();
    _reactionRemovedController.close();
    _groupDisbandedController.close();
    _friendshipUpdatedController.close();
    _friendRequestReceivedController.close();
    _groupSettingsChangedController.close();
    _groupMemberAddedController.close();
    _groupMemberRemovedController.close();
    _groupRoleChangedController.close();
    _groupAdminTransferredController.close();
    _groupCallSignalController.close();
    _connectController.close();
  }
}
