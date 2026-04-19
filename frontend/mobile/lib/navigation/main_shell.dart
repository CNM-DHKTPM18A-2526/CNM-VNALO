import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'dart:async';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  StreamSubscription<AiCommand>? _actionSub;
  StreamSubscription<Map<String, dynamic>>? _callErrorSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final aiProvider = context.read<AiAssistantProvider>();
      _actionSub = aiProvider.systemActionStream.listen(_handleAiSystemAction);

      final socketService = context.read<SocketService>();
      _callErrorSub = socketService.onCallError.listen(_handleCallErrorSignal);
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
    _showErrorSnackBar('Lỗi cuộc gọi: $detail');
  }

  String _normalizeAiSystemAction(String command) {
    switch (command.trim().toUpperCase()) {
      case 'MỞ SETTINGS':
      case 'CÀI ĐẶT':
        return 'NAVIGATE_TO_SETTINGS';
      case 'MỞ CHAT':
        return 'NAVIGATE_TO_CHAT';
      default:
        return command.trim().toUpperCase();
    }
  }

  void _handleAiSystemAction(AiCommand aiCmd) {
    final chatProvider = context.read<ChatProvider>();
    final command = _normalizeAiSystemAction(aiCmd.command);
    final params = aiCmd.params as Map<String, dynamic>?;

    debugPrint('AI System Action Triggered: $command with params: $params');

    switch (command) {
      case 'NAVIGATE_TO':
        _handleNavigateTo(params);
        break;
      case 'NAVIGATE_TO_SETTINGS':
        _handleNavigateTo({'page': 'settings'});
        break;
      case 'NAVIGATE_TO_CHAT':
        _handleNavigateTo({'page': 'chat'});
        break;
      case 'NAVIGATE_TO_SCANNER':
        _handleNavigateTo({'page': 'scanner'});
        break;
      case 'NAVIGATE_TO_TIMELINE':
        _handleNavigateTo({'page': 'timeline'});
        break;
        
      case 'OPEN_CHAT':
      case 'SEND_MESSAGE':
      case 'START_CALL':
        final targetName =
            (params?['target'] ?? params?['recipient'] ?? '').toString();
        final conversation = chatProvider.findConversationByName(targetName);
        
        if (conversation == null) {
          debugPrint('AI Resolution Failed: Could not find conversation for "$targetName"');
          _showErrorSnackBar('Không tìm thấy "$targetName" trong danh bạ.');
          return;
        }

        final currentUserId = chatProvider.currentUserId ?? '';
        final isDirect = conversation.type.name == 'DIRECT';
        final peerMember = isDirect
            ? conversation.members.where((m) => m.userId != currentUserId).firstOrNull
            : null;
        final peerUserId = peerMember?.userId ?? '';
        final peerName = conversation.getDisplayName(currentUserId);

        final prefilledText = command == 'SEND_MESSAGE' ? (params?['content'] as String?) : null;

        if (command == 'OPEN_CHAT' || command == 'SEND_MESSAGE') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              conversation: conversation,
              prefilledText: prefilledText,
            ),
          ));
        } else if (command == 'START_CALL') {
          if (!isDirect || peerUserId.isEmpty) {
            _showErrorSnackBar(
              'Tính năng gọi điện hiện chỉ hỗ trợ hội thoại 1-1.',
            );
            return;
          }

          final isVideo = params?['callType'] == 'video';
          final callId = generateCallId(
            conversationId: conversation.id,
            callerUserId: currentUserId,
            audioOnly: !isVideo,
          );
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => isVideo
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
          ));
        }
        break;

      case 'RECALL_MESSAGE':
        if (chatProvider.activeConversationId != null && chatProvider.messages.isNotEmpty) {
          try {
            final lastMsg = chatProvider.messages.firstWhere(
              (m) => m.senderId == chatProvider.currentUserId,
            );
            chatProvider.recallMessage(lastMsg.id, chatProvider.activeConversationId!);
          } catch (_) {
             debugPrint('AI Recall Failed: No recent message found from self');
          }
        }
        break;

      default:
        debugPrint('Unknown AI Command: $command');
    }
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
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          int unreadCount = 0;
          for (var c in chatProvider.conversations) {
            unreadCount += c.unreadCount;
          }

          final common = CommonTexts.of(context);

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: isDarkMode ? DarkColors.textHint : const Color(0xFF9CA3AF),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: [
              BottomNavigationBarItem(
                icon: unreadCount > 0 
                  ? Badge(
                      label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
                      backgroundColor: AppColors.unreadBadge,
                      child: const Icon(Icons.chat_bubble_rounded),
                    )
                  : const Icon(Icons.chat_bubble_rounded),
                label: common.messagesTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.contacts_outlined),
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
