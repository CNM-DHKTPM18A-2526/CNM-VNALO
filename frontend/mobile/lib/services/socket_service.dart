import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/services/auth_events.dart';

class SocketService with ChangeNotifier {
  io.Socket? _socket;
  final _joinedRooms = <String>{};
  final _pendingRoomJoins = <String>{};

  // M-03: Message deduplication — prevents double delivery from room + emitToUser paths
  final _seenMessageKeys = <String>{};
  static const kMaxDedupCache = 500;

  String? _lastToken;
  int _reinitCount = 0;
  int get reinitCount => _reinitCount;
  String? _globalToken;
  bool _disposed = false;
  VoidCallback? _onSocketReady;

  // Heartbeat timer — emits 'heartbeat' every 25 seconds (well under the 60s Redis TTL on the server)
  Timer? _heartbeatTimer;
  static const _heartbeatIntervalSeconds = 25;

  // ─── Stream Controllers (Non-final to allow re-initialization) ───────────
  StreamController<Message> _messageController = StreamController<Message>.broadcast();
  StreamController<Map<String, dynamic>> _typingController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<dynamic> _presenceListController = StreamController<dynamic>.broadcast();
  StreamController<Map<String, dynamic>> _readController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _deliveredController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _recalledController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _pinnedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _unpinnedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _callSignalController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _callErrorController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _reactionAddedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _reactionRemovedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _postCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _postUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _postDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _reactionUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _commentCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _storyCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _storyDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _storyViewedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _storyExpiredController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _groupDisbandedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _friendshipUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _friendRequestReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _groupSettingsChangedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _groupMemberAddedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _groupMemberRemovedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _groupRoleChangedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _groupAdminTransferredController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _sendErrorController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _blockCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _blockUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _blockRemovedController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _groupCallSignalController = StreamController<Map<String, dynamic>>.broadcast();
  StreamController<void> _connectController = StreamController<void>.broadcast();


  void _disposeAllControllers() {
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _presenceListController.close();
    _readController.close();
    _deliveredController.close();
    _recalledController.close();
    _pinnedController.close();
    _unpinnedController.close();
    _callSignalController.close();
    _callErrorController.close();
    _reactionAddedController.close();
    _reactionRemovedController.close();
    _postCreatedController.close();
    _postUpdatedController.close();
    _postDeletedController.close();
    _reactionUpdatedController.close();
    _commentCreatedController.close();
    _storyCreatedController.close();
    _storyDeletedController.close();
    _storyViewedController.close();
    _storyExpiredController.close();
    _groupDisbandedController.close();
    _friendshipUpdatedController.close();
    _friendRequestReceivedController.close();
    _groupSettingsChangedController.close();
    _groupMemberAddedController.close();
    _groupMemberRemovedController.close();
    _groupRoleChangedController.close();
    _groupAdminTransferredController.close();
    _sendErrorController.close();
    _blockCreatedController.close();
    _blockUpdatedController.close();
    _blockRemovedController.close();
    _groupCallSignalController.close();
    _connectController.close();
  }

  Stream<Message> get onMessage =>
      _messageController.stream; // Stream for incoming messages
  Stream<Map<String, dynamic>> get onTyping =>
      _typingController.stream; // Stream for typing indicators
  Stream<Map<String, dynamic>> get onPresence =>
      _presenceController.stream; // Stream for presence updates
  Stream<dynamic> get onPresenceList => _presenceListController.stream;
  Stream<Map<String, dynamic>> get onRead => _readController.stream;
  Stream<Map<String, dynamic>> get onDelivered => _deliveredController.stream;
  Stream<Map<String, dynamic>> get onRecalled => _recalledController.stream;
  Stream<Map<String, dynamic>> get onPinned => _pinnedController.stream;
  Stream<Map<String, dynamic>> get onUnpinned => _unpinnedController.stream;
  Stream<Map<String, dynamic>> get onCallSignal => _callSignalController.stream;
  Stream<Map<String, dynamic>> get onCallError => _callErrorController.stream;
  Stream<Map<String, dynamic>> get onReactionAdded => _reactionAddedController.stream;
  Stream<Map<String, dynamic>> get onReactionRemoved => _reactionRemovedController.stream;
  Stream<Map<String, dynamic>> get onPostCreated => _postCreatedController.stream;
  Stream<Map<String, dynamic>> get onPostUpdated => _postUpdatedController.stream;
  Stream<Map<String, dynamic>> get onPostDeleted => _postDeletedController.stream;
  Stream<Map<String, dynamic>> get onReactionUpdated => _reactionUpdatedController.stream;
  Stream<Map<String, dynamic>> get onCommentCreated => _commentCreatedController.stream;
  Stream<Map<String, dynamic>> get onStoryCreated => _storyCreatedController.stream;
  Stream<Map<String, dynamic>> get onStoryDeleted => _storyDeletedController.stream;
  Stream<Map<String, dynamic>> get onStoryViewed => _storyViewedController.stream;
  Stream<Map<String, dynamic>> get onStoryExpired => _storyExpiredController.stream;
  Stream<Map<String, dynamic>> get onGroupDisbanded => _groupDisbandedController.stream;
  Stream<Map<String, dynamic>> get onFriendshipUpdated => _friendshipUpdatedController.stream;
  Stream<Map<String, dynamic>> get onFriendRequestReceived => _friendRequestReceivedController.stream;
  Stream<Map<String, dynamic>> get onGroupSettingsChanged => _groupSettingsChangedController.stream;
  Stream<Map<String, dynamic>> get onGroupMemberAdded => _groupMemberAddedController.stream;
  Stream<Map<String, dynamic>> get onGroupMemberRemoved => _groupMemberRemovedController.stream;
  Stream<Map<String, dynamic>> get onGroupRoleChanged => _groupRoleChangedController.stream;
  Stream<Map<String, dynamic>> get onGroupAdminTransferred => _groupAdminTransferredController.stream;
  Stream<Map<String, dynamic>> get onSendError => _sendErrorController.stream;
  Stream<Map<String, dynamic>> get onBlockCreated => _blockCreatedController.stream;
  Stream<Map<String, dynamic>> get onBlockUpdated => _blockUpdatedController.stream;
  Stream<Map<String, dynamic>> get onBlockRemoved => _blockRemovedController.stream;

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

    if (!hasToken) {
      debugPrint('[SocketService] ⚠️ connect() called with empty/invalid token — SKIPPING to prevent timeout loop');
      return;
    }

    // M-04: If token changed (logout/re-login), dispose old controllers before creating new socket
    if (_globalToken != null && _globalToken != token) {
      debugPrint('[SocketService] Token changed — re-initializing controllers');
      _disposeAllControllers();
      _initControllers();
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _joinedRooms.clear();
      _pendingRoomJoins.clear();
      _seenMessageKeys.clear();
      _disposed = false;
    } else if (_socket != null) {
      if (_socket!.connected) {
        debugPrint('[SocketService] Already connected, skipping connect.');
        return;
      }
      debugPrint('[SocketService] Disposing existing socket (disconnected state).');
      _socket?.dispose();
      _socket = null;
    }

    _globalToken = token;

    final url = '${AppConfig.instance.socketUrl}/chat';
    debugPrint('[SOCKET] 🔌 Connecting to: $url');
    debugPrint('[SOCKET]   Path: /socket.io/');
    debugPrint('[SOCKET]   Token: ${token.substring(0, min(10, token.length))}...');

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
          // Explicit ping/pong timeouts — prevents proxy/load-balancer from closing idle connections
          .setTimeout(10000)                 // Socket.IO client-side timeout: 10s
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

      // Start heartbeat timer — keeps Redis presence TTL alive on the server
      _startHeartbeat();
    });

    _socket!.onDisconnect((data) {
      debugPrint('[SOCKET] 🔴 DISCONNECTED from gateway: $data');
      _stopHeartbeat();
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
      _presenceController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('presence.list', (data) {
      _presenceListController.add(data);
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

    Map<String, dynamic> _safePayload(dynamic data) {
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'data': data};
    }

    _socket!.on('post.created', (data) {
      debugPrint('[SOCKET][SOCIAL] post.created: $data');
      _postCreatedController.add(_safePayload(data));
    });
    _socket!.on('post.updated', (data) {
      debugPrint('[SOCKET][SOCIAL] post.updated: $data');
      _postUpdatedController.add(_safePayload(data));
    });
    _socket!.on('post.deleted', (data) {
      debugPrint('[SOCKET][SOCIAL] post.deleted: $data');
      _postDeletedController.add(_safePayload(data));
    });
    _socket!.on('reaction.updated', (data) {
      debugPrint('[SOCKET][SOCIAL] reaction.updated: $data');
      _reactionUpdatedController.add(_safePayload(data));
    });
    _socket!.on('comment.created', (data) {
      debugPrint('[SOCKET][SOCIAL] comment.created: $data');
      _commentCreatedController.add(_safePayload(data));
    });
    _socket!.on('story.created', (data) {
      debugPrint('[SOCKET][SOCIAL] story.created: $data');
      _storyCreatedController.add(_safePayload(data));
    });
    _socket!.on('story.deleted', (data) {
      debugPrint('[SOCKET][SOCIAL] story.deleted: $data');
      _storyDeletedController.add(_safePayload(data));
    });
    _socket!.on('story.viewed', (data) {
      debugPrint('[SOCKET][SOCIAL] story.viewed: $data');
      _storyViewedController.add(_safePayload(data));
    });
    _socket!.on('story.expired', (data) {
      debugPrint('[SOCKET][SOCIAL] story.expired: $data');
      _storyExpiredController.add(_safePayload(data));
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
    _socket!.onAny((event, data) {
      // Reduce noise: heartbeat emits frequently and can flood logs.
      if (event == 'heartbeat' || event == 'heartbeat.ack') return;
      debugPrint('📩 [SOCKET ANY] Event: $event | Data: $data');
    });

    _socket!.on('friendship.updated', (data) {
      debugPrint('[SOCKET] 🤝 friendship.updated: $data');
      _friendshipUpdatedController.add(Map<String, dynamic>.from(data ?? {}));
    });
    _socket!.on('friend.request.received', (data) {
      debugPrint('[SOCKET] 🤝 friend.request.received: $data');
      if (data != null) {
        _friendRequestReceivedController.add(Map<String, dynamic>.from(data as Map));
      } else {
        _friendRequestReceivedController.add({});
      }
    });

    _socket!.on('block.created', (data) {
      debugPrint('[SOCKET] 🚫 block.created: $data');
      if (data is Map) {
        _blockCreatedController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket!.on('block.updated', (data) {
      debugPrint('[SOCKET] 🚫 block.updated: $data');
      if (data is Map) {
        _blockUpdatedController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket!.on('block.removed', (data) {
      debugPrint('[SOCKET] ✅ block.removed: $data');
      if (data is Map) {
        _blockRemovedController.add(Map<String, dynamic>.from(data));
      }
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
    final id = conversationId.trim();
    if (id.isEmpty) return;

    if (_joinedRooms.contains(id)) {
      debugPrint('[SocketService] joinConversation: already joined $id');
      return;
    }

    if (_socket == null) {
      debugPrint('[SocketService] joinConversation FAILED: socket is null (queued)');
      _pendingRoomJoins.add(id);
      return;
    }

    if (!_socket!.connected) {
      debugPrint('[SocketService] joinConversation WARNING: socket not connected yet, queuing for retry');
      _pendingRoomJoins.add(id);
      return;
    }

    debugPrint('[SocketService] joinConversation: conv=$id connected=${_socket!.connected}');
    _socket?.emit('conversation.join', {'conversationId': id});
    _joinedRooms.add(id);
    debugPrint('[SocketService] ✅ Joined room (total: ${_joinedRooms.length}): $id');
  }

  // Leave a conversation by emitting a 'conversation.leave' event with the conversation ID
  void leaveConversation(String conversationId) {
    _socket?.emit('conversation.leave', {'conversationId': conversationId});
    _joinedRooms.remove(conversationId);
  }

  // Emit group.removeMember to trigger real-time updates for leaving or kicking members
  void emitRemoveMember(String conversationId, String targetUserId) {
    _socket?.emit('group.removeMember', {
      'conversationId': conversationId,
      'targetUserId': targetUserId,
    });
  }

  Future<Map<String, dynamic>> emitRemoveMemberWithAck(String conversationId, String targetUserId) async {
    final completer = Completer<Map<String, dynamic>>();
    
    if (_socket == null || !_socket!.connected) {
      completer.completeError(Exception('Socket not connected'));
      return completer.future;
    }

    _socket!.emitWithAck('group.removeMember', {
      'conversationId': conversationId,
      'targetUserId': targetUserId,
    }, ack: (dynamic data) {
      if (!completer.isCompleted) {
        if (data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'event': 'unknown', 'data': data});
        }
      }
    });

    // Timeout
    Future.delayed(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Socket emitRemoveMember timed out'));
      }
    });

    return completer.future;
  }

  Future<Map<String, dynamic>> emitDisbandGroupWithAck(String conversationId) async {
    final completer = Completer<Map<String, dynamic>>();
    
    if (_socket == null || !_socket!.connected) {
      completer.completeError(Exception('Socket not connected'));
      return completer.future;
    }

    _socket!.emitWithAck('group.disband', {
      'conversationId': conversationId,
    }, ack: (dynamic data) {
      if (!completer.isCompleted) {
        if (data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete({'event': 'unknown', 'data': data});
        }
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Socket emitDisbandGroup timed out'));
      }
    });

    return completer.future;
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
    _socket?.emit('presence.set', {'isOnline': isOnline});
  }

  void requestPresence(List<String> userIds) {
    if (_socket == null || !_socket!.connected) {
      return;
    }
    if (userIds.isEmpty) return;
    
    _socket?.emit('presence.get', userIds);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatIntervalSeconds),
      (_) {
        if (_socket != null && _socket!.connected) {
          _socket!.emit('heartbeat');
          debugPrint('[SocketService] 💓 Heartbeat sent');
        }
      },
    );
    debugPrint('[SocketService] 💓 Heartbeat timer started (interval: ${_heartbeatIntervalSeconds}s)');
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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
    String? displayName,
  }) {
    debugPrint('[SocketService][GROUP_CALL][SEND] offer callId=$callId target=$targetUserId displayName=$displayName');
    _socket?.emit('group-call:offer', {
      'conversationId': conversationId,
      'callId': callId,
      'targetUserId': targetUserId,
      'sdp': sdp,
      'senderUserId': senderUserId,
      if (displayName != null) 'displayName': displayName,
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

  /// Emit group.updateSettings via WebSocket so backend broadcasts to all members.
  /// Prefer this over REST updateGroupInfo to get real-time sync.
  void emitGroupUpdateSettings({
    required String conversationId,
    String? title,
    String? description,
    String? avatarUrl,
    String? joinMode,
    bool? allowMemberInvite,
    bool? allowMemberPin,
    bool? allowMemberEditInfo,
    bool? onlyAdminCanPost,
    bool? highlightAdminMessages,
    bool? showHistoryToNewMembers,
    bool? allowMemberCreateNote,
    bool? allowMemberCreatePoll,
  }) {
    final payload = <String, dynamic>{'conversationId': conversationId};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (avatarUrl != null) payload['avatarUrl'] = avatarUrl;
    if (joinMode != null) payload['joinMode'] = joinMode;
    if (allowMemberInvite != null) payload['allowMemberInvite'] = allowMemberInvite;
    if (allowMemberPin != null) payload['allowMemberPin'] = allowMemberPin;
    if (allowMemberEditInfo != null) payload['allowMemberEditInfo'] = allowMemberEditInfo;
    if (onlyAdminCanPost != null) payload['onlyAdminCanPost'] = onlyAdminCanPost;
    if (highlightAdminMessages != null) payload['highlightAdminMessages'] = highlightAdminMessages;
    if (showHistoryToNewMembers != null) payload['showHistoryToNewMembers'] = showHistoryToNewMembers;
    if (allowMemberCreateNote != null) payload['allowMemberCreateNote'] = allowMemberCreateNote;
    if (allowMemberCreatePoll != null) payload['allowMemberCreatePoll'] = allowMemberCreatePoll;
    debugPrint('[SocketService] emitGroupUpdateSettings: $payload');
    _socket?.emit('group.updateSettings', payload);
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

  Stream<Map<String, dynamic>> get onGroupCallSignal => _groupCallSignalController.stream;
  Stream<void> get onConnectStream => _connectController.stream;

  void _initControllers() {
    if (_messageController.isClosed) _messageController = StreamController<Message>.broadcast();
    if (_typingController.isClosed) _typingController = StreamController<Map<String, dynamic>>.broadcast();
    if (_presenceController.isClosed) _presenceController = StreamController<Map<String, dynamic>>.broadcast();
    if (_readController.isClosed) _readController = StreamController<Map<String, dynamic>>.broadcast();
    if (_deliveredController.isClosed) _deliveredController = StreamController<Map<String, dynamic>>.broadcast();
    if (_recalledController.isClosed) _recalledController = StreamController<Map<String, dynamic>>.broadcast();
    if (_pinnedController.isClosed) _pinnedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_unpinnedController.isClosed) _unpinnedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_callSignalController.isClosed) _callSignalController = StreamController<Map<String, dynamic>>.broadcast();
    if (_callErrorController.isClosed) _callErrorController = StreamController<Map<String, dynamic>>.broadcast();
    if (_reactionAddedController.isClosed) _reactionAddedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_reactionRemovedController.isClosed) _reactionRemovedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_postCreatedController.isClosed) _postCreatedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_postUpdatedController.isClosed) _postUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_postDeletedController.isClosed) _postDeletedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_reactionUpdatedController.isClosed) _reactionUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_commentCreatedController.isClosed) _commentCreatedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_storyCreatedController.isClosed) _storyCreatedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_storyDeletedController.isClosed) _storyDeletedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_storyViewedController.isClosed) _storyViewedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_storyExpiredController.isClosed) _storyExpiredController = StreamController<Map<String, dynamic>>.broadcast();
    if (_groupDisbandedController.isClosed) _groupDisbandedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_friendshipUpdatedController.isClosed) _friendshipUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_friendRequestReceivedController.isClosed) _friendRequestReceivedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_groupSettingsChangedController.isClosed) _groupSettingsChangedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_groupMemberAddedController.isClosed) _groupMemberAddedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_groupMemberRemovedController.isClosed) _groupMemberRemovedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_groupRoleChangedController.isClosed) _groupRoleChangedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_groupAdminTransferredController.isClosed) _groupAdminTransferredController = StreamController<Map<String, dynamic>>.broadcast();
    if (_blockCreatedController.isClosed) _blockCreatedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_blockUpdatedController.isClosed) _blockUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_blockRemovedController.isClosed) _blockRemovedController = StreamController<Map<String, dynamic>>.broadcast();
    if (_groupCallSignalController.isClosed) _groupCallSignalController = StreamController<Map<String, dynamic>>.broadcast();
    if (_connectController.isClosed) _connectController = StreamController<void>.broadcast();
    if (_sendErrorController.isClosed) _sendErrorController = StreamController<Map<String, dynamic>>.broadcast();
    _reinitCount++;
    notifyListeners();
  }

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
    _stopHeartbeat();
    _socket?.disconnect(); // Disconnect from the socket server
    _socket?.dispose(); // Dispose the socket instance to free up resources
    _socket = null;
    _joinedRooms.clear(); // Clear joined rooms on disconnect
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    _disposeAllControllers();
  }
}
