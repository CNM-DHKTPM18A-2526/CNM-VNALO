import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/screens/voice_call_screen.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class IncomingCallCoordinator extends StatefulWidget {
  const IncomingCallCoordinator({super.key});

  @override
  State<IncomingCallCoordinator> createState() => _IncomingCallCoordinatorState();
}

class _IncomingCallCoordinatorState extends State<IncomingCallCoordinator> {
  SocketService? _socketService;
  StreamSubscription? _callSignalSub;
  final Set<String> _handledOffers = {};
  bool _isPresentingCall = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final socketService = context.watch<SocketService>();
    if (identical(_socketService, socketService)) {
      return;
    }

    _callSignalSub?.cancel();
    _socketService = socketService;
    _callSignalSub = socketService.onCallSignal.listen(_handleSignalEvent);
    debugPrint('[IncomingCallCoordinator] Subscribed to call signals');
  }

  @override
  void dispose() {
    _callSignalSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSignalEvent(Map<String, dynamic> signal) async {
    if (!mounted) return;
    
    final type = signal['type']?.toString();
    if (type != 'offer') return;

    final callId = signal['callId']?.toString();
    final conversationId = signal['conversationId']?.toString();
    final senderUserId = signal['senderUserId']?.toString() ?? signal['fromUserId']?.toString();
    
    if (conversationId == null || callId == null || senderUserId == null) {
      debugPrint('[IncomingCallCoordinator] Signal missing required IDs: $signal');
      return;
    }

    // Deduplication
    final dedupeKey = '$conversationId:$callId';
    if (_handledOffers.contains(dedupeKey)) return;
    _handledOffers.add(dedupeKey);

    debugPrint('[IncomingCallCoordinator] Received offer for callID=$callId');

    // Wait for auth to be ready if needed
    final auth = context.read<AuthProvider>();
    if (!auth.isInitialized || auth.user == null) {
      debugPrint('[IncomingCallCoordinator] Auth not ready, waiting...');
      var checks = 0;
      while ((!auth.isInitialized || auth.user == null) && checks < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        checks++;
      }
    }

    final currentUserId = auth.user?.id;
    if (currentUserId == null) {
      debugPrint('[IncomingCallCoordinator] Auth failed after delay, ignoring offer');
      return;
    }

    // If signal was meant for someone else, ignore (unlikely due to emitToUser)
    final targetUserId = signal['targetUserId']?.toString() ?? signal['toUserId']?.toString();
    if (targetUserId != null && targetUserId != currentUserId) {
      debugPrint('[IncomingCallCoordinator] Signal reached wrong user: $targetUserId != $currentUserId');
      return;
    }

    if (_isPresentingCall) {
      debugPrint('[IncomingCallCoordinator] Already presenting another call, replying busy');
      _socketService?.endCall(
        conversationId: conversationId,
        callId: callId,
        targetUserId: senderUserId,
        senderUserId: currentUserId,
        reason: 'busy',
      );
      return;
    }

    // Resolve caller display info
    final chatProvider = context.read<ChatProvider>();
    final conversationIndex = chatProvider.conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    final conversation = conversationIndex == -1
        ? null
        : chatProvider.conversations[conversationIndex];

    dynamic senderMember;
    if (conversation != null) {
      for (final member in conversation.members) {
        if (member.userId == senderUserId) {
          senderMember = member;
          break;
        }
      }
    }

    final displayName = senderMember?.nickname ??
        senderMember?.user?.displayName ??
        senderUserId;
    final avatarUrl = senderMember?.user?.avatarUrl;
    final audioOnly = _resolveAudioOnly(signal);

    if (!mounted) return;

    debugPrint('[IncomingCallCoordinator] Pushing call screen for $displayName');

    _isPresentingCall = true;
    try {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => audioOnly
              ? VoiceCallScreen(
                  conversationId: conversationId,
                  callId: callId,
                  targetUserId: senderUserId,
                  targetDisplayName: displayName,
                  targetAvatarUrl: avatarUrl,
                  isCaller: false,
                  initialSdp: signal,
                )
              : VideoCallScreen(
                  conversationId: conversationId,
                  callId: callId,
                  targetUserId: senderUserId,
                  targetDisplayName: displayName,
                  targetAvatarUrl: avatarUrl,
                  isCaller: false,
                  initialSdp: signal,
                ),
        ),
      );
    } finally {
      _isPresentingCall = false;
    }
  }

  bool _resolveAudioOnly(Map<String, dynamic> signal) {
    final explicit = signal['audioOnly'];
    if (explicit is bool) {
      return explicit;
    }
    if (explicit is String) {
      final normalized = explicit.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }

    final sdpMap = signal['sdp'];
    if (sdpMap is Map) {
      final sdp = sdpMap['sdp']?.toString() ?? '';
      if (sdp.contains('m=video')) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
