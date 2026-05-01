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

  // M-03: Message deduplication — prevents double delivery from room + emitToUser paths
  final _seenMessageKeys = <String>{};
  static const kMaxDedupCache = 500;

  String? _globalToken;

  // Stream controller for send errors (added by M-01)
  final _sendErrorController = StreamController<Map<String, dynamic>>.broadcast();

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
  Stream<Map<String, dynamic>> get onSendError => _sendErrorController.stream;

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
    final hasToken = token.isNotEmpty;
    debugPrint('[SocketService] token present: $hasToken');
    debugPrint('[SocketService] existing socket: ${_socket != null}, connected: ${_socket?.connected}');

    if (_socket != null && _socket!.connected) {
      debugPrint('[SocketService] Already connected, skipping connect.');
      return;
    }

    // M-04: If token changed (logout/re-login), dispose old controllers before creating new socket
    if (_globalToken != null && _globalToken != token) {
      debugPrint('[SocketService] Token changed — disposing old controllers and socket');
      _disposeAllControllers();
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _joinedRooms.clear();
      _pendingRoomJoins.clear();
      _seenMessageKeys.clear();
      _disposed = false;
    } else if (_socket != null) {
      debugPrint('[SocketService] Disposing existing socket.');
      disconnect();
    }

    _globalToken = token;

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
          // Thundering herd fix (M-02): exponential backoff with jitter
          .setReconnectionDelay(1000)       // base: 1 second
          .setReconnectionDelayMax(8000)    // max cap: 8 seconds
          .setRandomizationFactor(0.5)      // ±50% jitter — spreads reconnect load over 0.5–12s
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
      
      // ⚡ AUTO-REPORT ONLINE STATUS
      emitPresence(true);
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
        // M-03 Deduplication: skip if already processed
        final message = Message.fromJson(data);
        final key = message.id;
        if (_seenMessageKeys.contains(key)) {
          debugPrint('[SocketService][DEDUP] message.received ignored: $key');
          return;
        }
        if (_seenMessageKeys.length >= kMaxDedupCache) {
          // Evict oldest entries to prevent unbounded memory growth
          final oldest = _seenMessageKeys.first;
          _seenMessageKeys.remove(oldest);
        }
        _seenMessageKeys.add(key);

        debugPrint('[SocketService][RECV] ✅ Parsed message ID: ${message.id} conv: ${message.conversationId} sender: ${message.senderId}');
        _messageController.add(message);
      } catch (e) {
        debugPrint('[SocketService][RECV] ❌ ERROR parsing message: $e');
      }
    });

    _socket!.on('message.sent', (data) {
      debugPrint('[SocketService][RECV] 📤 message.sent: $data');
      try {
        // M-03 Deduplication: skip if already processed
        final msg = Message.fromJson(data);
        final key = msg.id;
        if (_seenMessageKeys.contains(key)) {
          debugPrint('[SocketService][DEDUP] message.sent ignored: $key');
          return;
        }
        if (_seenMessageKeys.length >= kMaxDedupCache) {
          final oldest = _seenMessageKeys.first;
          _seenMessageKeys.remove(oldest);
        }
        _seenMessageKeys.add(key);

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
    _socket!.on('group.memberLeft', (data) {
      // B-02: group.memberLeft emitted when user voluntarily leaves group
      debugPrint('[SocketService] group.memberLeft received: $data');
      _groupMemberRemovedController.add(Map<String, dynamic>.from(data));
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

    _socket!.on('group-call:started', (data) => _emitGroupCallSignal('started', data));
    _socket!.on('group-call.started', (data) => _emitGroupCallSignal('started', data));

    _socket!.on('group-call:join', (data) => _emitGroupCallSignal('join', data));
    _socket!.on('group-call.join', (data) => _emitGroupCallSignal('join', data));

    _socket!.on('group-call:user-joined', (data) => _emitGroupCallSignal('user-joined', data));
    _socket!.on('group-call.user-joined', (data) => _emitGroupCallSignal('user-joined', data));

    _socket!.on('group-call:offer', (data) => _emitGroupCallSignal('offer', data));
    _socket!.on('group-call.offer', (data) => _emitGroupCallSignal('offer', data));

    _socket!.on('group-call:answer', (data) => _emitGroupCallSignal('answer', data));
    _socket!.on('group-call.answer', (data) => _emitGroupCallSignal('answer', data));

    _socket!.on('group-call:ice-candidate', (data) => _emitGroupCallSignal('ice-candidate', data));
    _socket!.on('group-call.ice-candidate', (data) => _emitGroupCallSignal('ice-candidate', data));

    _socket!.on('group-call:user-left', (data) => _emitGroupCallSignal('user-left', data));
    _socket!.on('group-call.user-left', (data) => _emitGroupCallSignal('user-left', data));

    _socket!.on('group-call:ended', (data) => _emitGroupCallSignal('ended', data));
    _socket!.on('group-call.ended', (data) => _emitGroupCallSignal('ended', data));
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

  // M-01: Send a message with ACK timeout — prevents silent message loss on socket stalling.
  // If no server ACK within 3 seconds, emits error to _sendErrorController for UI feedback.
  static const kSendAckTimeoutMs = 3000;

  Future<void> sendMessage({
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
      debugPrint('[SocketService] sendMessage FAILED: socket is null');
      _sendErrorController.add({
        'conversationId': conversationId,
        'message': 'Socket chưa kết nối',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }
    if (!_socket!.connected) {
      debugPrint('[SocketService] sendMessage FAILED: socket not connected');
      _sendErrorController.add({
        'conversationId': conversationId,
        'message': 'Mất kết nối socket',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }

    debugPrint('[SocketService] sendMessage: conv=$conversationId type=$messageType clientId=$clientMessageId mediaUrl=$mediaUrl connected=${_socket?.connected}');

    final completer = Completer<void>();
    final timeoutKey = clientMessageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    Timer(Duration(milliseconds: kSendAckTimeoutMs), () {
      if (!completer.isCompleted) {
        debugPrint('[SocketService][M-01] ⏱️ sendMessage ACK timeout for conv=$conversationId, key=$timeoutKey');
        completer.completeError(TimeoutException(
          'Message send timeout — network may be unstable',
        ));
        _sendErrorController.add({
          'conversationId': conversationId,
          'clientMessageId': timeoutKey,
          'message': 'Gửi tin nhắn thất bại. Nhấn để gửi lại.',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });

    try {
      await _socket!.emitWithAckAsync(
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
      debugPrint('[SocketService][M-01] ✅ sendMessage ACK received for conv=$conversationId');
    } catch (e) {
      debugPrint('[SocketService][M-01] ❌ sendMessage ACK error/timeout: $e');
      _sendErrorController.add({
        'conversationId': conversationId,
        'clientMessageId': timeoutKey,
        'message': 'Gửi tin nhắn thất bại. Nhấn để gửi lại.',
        'timestamp': DateTime.now().toIso8601String(),
      });
      rethrow;
    }
  }

  void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('message.typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  void emitPresence(bool isOnline) {
    if (_socket == null || !_socket!.connected) return;
    debugPrint('[SocketService] 📡 Emitting presence: ${isOnline ? 'ONLINE' : 'OFFLINE'}');
    _socket?.emit('presence.set', {'isOnline': isOnline});
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
      'callerUserId': senderUserId,  // Backend expects this
      'callerName': senderName,      // Backend expects this
      'callerAvatar': senderAvatarUrl, // Backend expects this
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
    debugPrint('[SocketService][GROUP_CALL][SEND] join callId=$callId conv=$conversationId');
    _socket?.emit('group-call:join', {
      'conversationId': conversationId,
      'callId': callId,
      'senderUserId': senderUserId,
      'displayName': senderName,
      'avatarUrl': senderAvatarUrl,
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

  // M-04: Extract controller cleanup into reusable helper
  void _disposeAllControllers() {
    _messageController.close();
    _typingController.close();
    _presenceController.close();
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
    _sendErrorController.close();
  }

  bool _disposed = false;

  void dispose() {
    if (_disposed) return; // Idempotent: guard against double-dispose
    _disposed = true;
    disconnect();
    _disposeAllControllers();
  }
}
