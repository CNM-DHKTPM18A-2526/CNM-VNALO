import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/contacts/providers/contact_provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_list_screen.dart';
import 'package:vnalo_mobile/features/contacts/screens/contacts_screen.dart';
import 'package:vnalo_mobile/features/discover/screens/discover_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/profile_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/home_wall_screen.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/call/screens/voice_call_screen.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/services/socket_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isCallScreenActive = false;
  String? _activeAiConversationId;
  StreamSubscription<AiCommand>? _actionSub;
  StreamSubscription<Map<String, dynamic>>? _callErrorSub;

  // Static key to access state from outside
  static final GlobalKey<MainShellState> globalKey =
      GlobalKey<MainShellState>();

  // Method to set tab index from outside
  void setTabIndex(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final aiProvider = context.read<AiAssistantProvider>();
      _actionSub = aiProvider.systemActionStream.listen((aiCmd) {
        unawaited(_handleAiSystemAction(aiCmd));
      });

      final socketService = context.read<SocketService>();
      _callErrorSub = socketService.onCallError.listen(_handleCallErrorSignal);

      // Initial fetch for friend request badge
      context.read<ContactProvider>().fetchPendingRequestCount();
    });
  }

  @override
  void dispose() {
    _actionSub?.cancel();
    _callErrorSub?.cancel();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
  }

  Future<void> _handleNavigateTo(Map<String, dynamic>? params) async {
    final page = (params?['page'] ?? '').toString().trim().toLowerCase();

    if (page.isEmpty) {
      _showErrorSnackBar('Lệnh NAVIGATE_TO thiếu tham số page.');
      return;
    }

    switch (page) {
      case 'chat':
        setState(() => _currentIndex = 0);
        break;
      case 'contacts':
        setState(() => _currentIndex = 1);
        break;
      case 'timeline':
        setState(() => _currentIndex = 3);
        break;
      case 'settings':
      case 'profile':
        setState(() => _currentIndex = 4);
        break;
      case 'scanner':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
        break;
      default:
        _showErrorSnackBar('Không hỗ trợ điều hướng AI tới "$page".');
    }
  }

  void _handleCallErrorSignal(Map<String, dynamic> payload) {
    final detail =
        payload['error']?.toString().trim().isNotEmpty == true
            ? payload['error'].toString().trim()
            : 'Lỗi signaling cuộc gọi từ server.';
    _logAiFlow('AI_CALL_ERROR_SIGNAL', extra: {'detail': detail});
    _showErrorSnackBar('Lỗi cuộc gọi: $detail');
  }

  String _normalizeAiSystemAction(String command) {
    switch (command.trim().toUpperCase()) {
      case 'MỞ SETTINGS':
      case 'CÀI ĐẶT':
        return 'NAVIGATE_TO_SETTINGS';
      case 'MỞ DANH BẠ':
        return 'NAVIGATE_TO_CONTACTS';
      case 'MỞ CHAT':
        return 'NAVIGATE_TO_CHAT';
      default:
        return command.trim().toUpperCase();
    }
  }

  Future<void> _handleAiSystemAction(AiCommand aiCmd) async {
    final chatProvider = context.read<ChatProvider>();
    final command = _normalizeAiSystemAction(aiCmd.command);
    final params = aiCmd.params as Map<String, dynamic>?;

    _logAiFlow(
      'AI_COMMAND_RECEIVED',
      aiCommand: aiCmd,
      extra: {'normalizedCommand': command, 'hasParams': params != null},
    );

    switch (command) {
      case 'NAVIGATE_TO':
        await _handleNavigateTo(params);
        break;
      case 'NAVIGATE_TO_SETTINGS':
        await _handleNavigateTo({'page': 'settings'});
        break;
      case 'NAVIGATE_TO_CHAT':
        await _handleNavigateTo({'page': 'chat'});
        break;
      case 'NAVIGATE_TO_CONTACTS':
        await _handleNavigateTo({'page': 'contacts'});
        break;
      case 'NAVIGATE_TO_SCANNER':
        await _handleNavigateTo({'page': 'scanner'});
        break;
      case 'NAVIGATE_TO_TIMELINE':
        await _handleNavigateTo({'page': 'timeline'});
        break;

       case 'OPEN_CHAT':
      case 'SEND_MESSAGE':
      case 'START_CALL':
        final targetName =
            (params?['target'] ?? params?['recipient'] ?? '').toString();
        final conversation = chatProvider.findConversationByName(targetName);

        if (conversation == null) {
          _logAiFlow(
            'AI_RESOLUTION_FAILED',
            aiCommand: aiCmd,
            extra: {'targetName': targetName},
          );
          _showErrorSnackBar('Không tìm thấy "$targetName" trong danh bạ.');
          return;
        }

        final currentUserId = chatProvider.currentUserId ?? '';
        final isDirect = conversation.type.name == 'DIRECT';
        final peerMember =
            isDirect
                ? conversation.members
                    .where((m) => m.userId != currentUserId)
                    .firstOrNull
                : null;
        final peerUserId = peerMember?.userId ?? '';
        final peerName = conversation.getDisplayName(currentUserId);

        final rawPrefilled = params?['content']?.toString().trim();
        final prefilledText =
            (command == 'SEND_MESSAGE' && rawPrefilled != null && rawPrefilled.isNotEmpty)
                ? rawPrefilled
                : null;

        if (command == 'OPEN_CHAT' || command == 'SEND_MESSAGE') {
          final isAlreadyInConversation =
              chatProvider.activeConversationId == conversation.id ||
              _activeAiConversationId == conversation.id;

          if (isAlreadyInConversation) {
            _logAiFlow(
              'AI_NAV_GUARD_BLOCKED',
              aiCommand: aiCmd,
              extra: {
                'reason': 'already_in_target_chat',
                'conversationId': conversation.id,
              },
            );
            setState(() => _currentIndex = 0);
            return;
          }

          if (command == 'SEND_MESSAGE') {
            if (prefilledText == null || prefilledText.isEmpty) {
              _logAiFlow(
                'AI_SEND_MSG_FALLBACK',
                aiCommand: aiCmd,
                extra: {'reason': 'empty_content'},
              );
            } else {
              final confirmed = await _showConfirmationDialog(
                'Xác nhận mở cuộc trò chuyện',
                'Bạn có đồng ý để trợ lý ảo mở phòng chat và chuẩn bị sẵn tin nhắn "$prefilledText" tới "$peerName" không?',
              );
              if (!confirmed) {
                _logAiFlow('AI_COMMAND_CANCELLED', aiCommand: aiCmd);
                return;
              }
            }
          }

          _activeAiConversationId = conversation.id;
          _logAiFlow(
            'AI_NAVIGATE_CHAT',
            aiCommand: aiCmd,
            extra: {
              'conversationId': conversation.id,
              'prefilled': prefilledText?.isNotEmpty == true,
            },
          );

          await Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => ChatDetailScreen(
                    conversation: conversation,
                    prefilledText: prefilledText,
                  ),
            ),
          );
          if (_activeAiConversationId == conversation.id) {
            _activeAiConversationId = null;
          }
        } else if (command == 'START_CALL') {
          if (_isCallScreenActive) {
            _logAiFlow(
              'AI_NAV_GUARD_BLOCKED',
              aiCommand: aiCmd,
              extra: {'reason': 'call_screen_already_active'},
            );
            return;
          }

          if (!isDirect || peerUserId.isEmpty) {
            _showErrorSnackBar(
              'Tính năng gọi điện hiện chỉ hỗ trợ hội thoại 1-1.',
            );
            return;
          }

          final isVideo = params?['callType'] == 'video';
          final callTypeName = isVideo ? 'video' : 'thoại';

          final confirmed = await _showConfirmationDialog(
            'Xác nhận gọi điện',
            'Bạn có đồng ý để trợ lý ảo thực hiện cuộc gọi $callTypeName tới "$peerName" không?',
          );
          if (!confirmed) {
            _logAiFlow('AI_COMMAND_CANCELLED', aiCommand: aiCmd);
            return;
          }

          final callId = generateCallId(
            conversationId: conversation.id,
            callerUserId: currentUserId,
            audioOnly: !isVideo,
          );

          _isCallScreenActive = true;
          _logAiFlow(
            'AI_NAVIGATE_CALL',
            aiCommand: aiCmd,
            extra: {
              'conversationId': conversation.id,
              'callId': callId,
              'callType': isVideo ? 'video' : 'voice',
            },
          );
          try {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) =>
                        isVideo
                            ? VideoCallScreen(
                              conversationId: conversation.id,
                              callId: callId,
                              targetUserId: peerUserId,
                              targetDisplayName: peerName,
                              isCaller: true,
                            )
                            : VoiceCallScreen(
                              conversationId: conversation.id,
                              callId: callId,
                              targetUserId: peerUserId,
                              targetDisplayName: peerName,
                              isCaller: true,
                            ),
              ),
            );
          } finally {
            _isCallScreenActive = false;
            _logAiFlow(
              'AI_CALL_SCREEN_RELEASED',
              aiCommand: aiCmd,
              extra: {'conversationId': conversation.id},
            );
          }
        }
        break;

      case 'RECALL_MESSAGE':
        if (chatProvider.activeConversationId != null &&
            chatProvider.messages.isNotEmpty) {
          try {
            final lastMsg = chatProvider.messages.firstWhere(
              (m) => m.senderId == chatProvider.currentUserId,
            );

            final confirmed = await _showConfirmationDialog(
              'Xác nhận thu hồi tin nhắn',
              'Bạn có đồng ý để trợ lý ảo thu hồi tin nhắn cuối cùng của mình không?',
            );
            if (!confirmed) {
              _logAiFlow('AI_COMMAND_CANCELLED', aiCommand: aiCmd);
              return;
            }

            chatProvider.recallMessage(
              lastMsg.id,
              chatProvider.activeConversationId!,
            );
          } catch (_) {
            _logAiFlow(
              'AI_RECALL_FAILED',
              aiCommand: aiCmd,
              extra: {'reason': 'no_self_message'},
            );
          }
        }
        break;

      default:
        _logAiFlow(
          'AI_UNKNOWN_COMMAND',
          aiCommand: aiCmd,
          extra: {'command': command},
        );
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _logAiFlow(
    String event, {
    AiCommand? aiCommand,
    Map<String, dynamic>? extra,
  }) {
    final payload = <String, dynamic>{
      'ts': DateTime.now().toIso8601String(),
      'scope': 'AI_NAV',
      'event': event,
      'traceId': aiCommand?.traceId ?? 'n/a',
      'commandId': aiCommand?.commandId ?? 'n/a',
      'command': aiCommand?.command,
      'tabIndex': _currentIndex,
      'callScreenActive': _isCallScreenActive,
      'activeAiConversationId': _activeAiConversationId,
      'extra': _sanitize(extra),
    };
    debugPrint('[AI_CMD_FLOW] ${jsonEncode(payload)}');
  }

  Map<String, dynamic> _sanitize(Map<String, dynamic>? input) {
    if (input == null || input.isEmpty) {
      return const {};
    }
    final output = <String, dynamic>{};
    input.forEach((key, value) {
      const sensitiveKeys = {'content', 'prefilledText', 'messageText'};
      if (sensitiveKeys.contains(key)) {
        output[key] = '<redacted>';
        return;
      }
      if (value == null || value is num || value is bool || value is String) {
        output[key] = value;
      } else {
        output[key] = value.toString();
      }
    });
    return output;
  }

  final _screens = const [
    ChatListScreen(),
    ContactsScreen(),
    DiscoverScreen(),
    HomeWallScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      key: globalKey,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Consumer2<ChatProvider, ContactProvider>(
        builder: (context, chatProvider, contactProvider, child) {
          debugPrint('🎨 [MainShell] Rebuilding BottomNavigationBar (pendingFriendCount: ${contactProvider.pendingRequestCount})');
          int unreadCount = 0;
          for (var c in chatProvider.conversations) {
            unreadCount += c.unreadCount;
          }

          final pendingFriendCount = contactProvider.pendingRequestCount;
          final common = CommonTexts.of(context);

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor:
                isDarkMode ? DarkColors.textHint : const Color(0xFF9CA3AF),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: [
              BottomNavigationBarItem(
                icon:
                    unreadCount > 0
                        ? Badge(
                          label: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                          ),
                          backgroundColor: AppColors.unreadBadge,
                          child: const Icon(Icons.chat_bubble_rounded),
                        )
                        : const Icon(Icons.chat_bubble_rounded),
                label: common.messagesTab,
              ),
              BottomNavigationBarItem(
                icon:
                    pendingFriendCount > 0
                        ? Badge(
                          label: Text(
                            pendingFriendCount > 99
                                ? '99+'
                                : pendingFriendCount.toString(),
                          ),
                          backgroundColor: AppColors.unreadBadge,
                          child: const Icon(Icons.contacts_outlined),
                        )
                        : const Icon(Icons.contacts_outlined),
                label: common.contactsTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.grid_view_rounded),
                label: common.discoverTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.feed_outlined),
                label: common.wallTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                label: common.profileTab,
              ),
            ],
          );
        },
      ),
    );
  }
}
