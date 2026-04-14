import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/screens/voice_call_screen.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class IncomingCallCoordinator extends StatefulWidget {
  const IncomingCallCoordinator({super.key});

  @override
  State<IncomingCallCoordinator> createState() =>
      _IncomingCallCoordinatorState();
}

class _IncomingCallCoordinatorState extends State<IncomingCallCoordinator> {
  SocketService? _socketService;
  StreamSubscription<Map<String, dynamic>>? _callSignalSub;
  final Set<String> _handledOffers = <String>{};
  bool _isPresentingCall = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final socketService = context.read<SocketService>();
    if (identical(_socketService, socketService)) {
      return;
    }

    unawaited(_callSignalSub?.cancel());
    _socketService = socketService;
    _callSignalSub = socketService.onCallSignal.listen(_handleSignalEvent);
  }

  Future<void> _handleSignalEvent(Map<String, dynamic> signal) async {
    if (!mounted) return;
    final type = signal['type']?.toString();
    if (type != 'offer') return;

    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final conversationId = signal['conversationId']?.toString();
    final callId = signal['callId']?.toString();
    final senderUserId = _extractUserId(signal, [
      'senderUserId',
      'senderId',
      'fromUserId',
    ]);
    final targetUserId = _extractUserId(signal, ['targetUserId', 'toUserId']);

    if (conversationId == null || conversationId.isEmpty) return;
    if (callId == null || callId.isEmpty) return;
    if (senderUserId == null || senderUserId.isEmpty) return;
    if (targetUserId != null &&
        targetUserId.isNotEmpty &&
        targetUserId != currentUserId) {
      return;
    }

    final dedupeKey = '$conversationId:$callId';
    if (_handledOffers.contains(dedupeKey)) return;
    _handledOffers.add(dedupeKey);

    if (_isPresentingCall) {
      _socketService?.endCall(
        conversationId: conversationId,
        callId: callId,
        targetUserId: senderUserId,
        senderUserId: currentUserId,
        reason: 'busy',
      );
      return;
    }

    final display = _resolveIncomingCallerDisplay(
      currentUserId: currentUserId,
      conversationId: conversationId,
      senderUserId: senderUserId,
    );
    final audioOnly = _resolveAudioOnly(signal);

    _isPresentingCall = true;
    try {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder:
              (_) => audioOnly
                  ? VoiceCallScreen(
                    conversationId: conversationId,
                    currentUserId: currentUserId,
                    targetUserId: senderUserId,
                    targetDisplayName: display.displayName,
                    targetAvatarUrl: display.avatarUrl,
                    isCaller: false,
                    callId: callId,
                  )
                  : VideoCallScreen(
                    conversationId: conversationId,
                    currentUserId: currentUserId,
                    targetUserId: senderUserId,
                    targetDisplayName: display.displayName,
                    targetAvatarUrl: display.avatarUrl,
                    isCaller: false,
                    callId: callId,
                  ),
        ),
      );
    } catch (_) {
      // Ignore route errors; call lifecycle is still managed by signaling.
    } finally {
      _isPresentingCall = false;
    }
  }

  ({String displayName, String? avatarUrl}) _resolveIncomingCallerDisplay({
    required String currentUserId,
    required String conversationId,
    required String senderUserId,
  }) {
    final chatProvider = context.read<ChatProvider>();
    final Conversation? conversation = chatProvider.conversations
        .cast<Conversation?>()
        .firstWhere(
          (conv) => conv?.id == conversationId,
          orElse: () => null,
        );

    ConversationMember? senderMember;
    if (conversation != null) {
      for (final member in conversation.members) {
        if (member.userId == senderUserId) {
          senderMember = member;
          break;
        }
      }
    }

    final displayName =
        senderMember?.nickname ??
        senderMember?.user?.displayName ??
        (conversation?.members
                .where((member) => member.userId != currentUserId)
                .firstOrNull
                ?.user
                ?.displayName ??
            senderUserId);
    final avatarUrl =
        senderMember?.user?.avatarUrl ??
        conversation?.members
            .where((member) => member.userId != currentUserId)
            .firstOrNull
            ?.user
            ?.avatarUrl;

    return (displayName: displayName, avatarUrl: avatarUrl);
  }

  bool _resolveAudioOnly(Map<String, dynamic> signal) {
    final explicit = signal['audioOnly'];
    if (explicit is bool) {
      return explicit;
    }
    if (explicit is String) {
      final normalized = explicit.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
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

  String? _extractUserId(Map<String, dynamic> signal, List<String> keys) {
    for (final key in keys) {
      final value = signal[key]?.toString();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  @override
  void dispose() {
    unawaited(_callSignalSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}