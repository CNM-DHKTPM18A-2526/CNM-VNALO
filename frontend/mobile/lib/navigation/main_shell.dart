import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/contacts/providers/contact_provider.dart';
import 'package:vnalo_mobile/features/contacts/screens/friend_options_screen.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_list_screen.dart';
import 'package:vnalo_mobile/features/contacts/screens/contacts_screen.dart';
import 'package:vnalo_mobile/features/discover/screens/discover_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/profile_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/home_wall_screen.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_recall_message_selector.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_action_confirmation_sheet.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_conversation_disambiguation_sheet.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/group_settings_screen.dart';
import 'package:vnalo_mobile/features/call/screens/voice_call_screen.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
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
      if (!mounted) return;
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

  Future<void> _dismissSoftKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    } catch (_) {}
  }

  Future<void> _handleNavigateTo(Map<String, dynamic>? params) async {
    if (!mounted) return;
    final page = (params?['page'] ?? '').toString().trim().toLowerCase();

    if (page.isEmpty) {
      _showErrorSnackBar('Lệnh NAVIGATE_TO thiếu tham số `page`.');
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
    return AiCommandRouting.normalizeSystemAction(command);
  }

  Map<String, dynamic>? _normalizeAiParams(AiCommand aiCmd) {
    final normalized = AiCommandRouting.normalizeParams(aiCmd.params);
    if (normalized != null || aiCmd.params == null) {
      return normalized;
    }

    _logAiFlow(
      'AI_PARAMS_MALFORMED',
      aiCommand: aiCmd,
      extra: {'rawType': aiCmd.params.runtimeType.toString()},
    );
    return null;
  }

  Future<void> _handleAiSystemAction(AiCommand aiCmd) async {
    if (!mounted) return;
    final chatProvider = context.read<ChatProvider>();
    final command = _normalizeAiSystemAction(aiCmd.command);
    final params = _normalizeAiParams(aiCmd);

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
      case 'COMPOSE_MESSAGE':
      case 'START_CALL':
        final targetName = AiCommandRouting.extractTargetName(params);
        if (targetName.isEmpty) {
          _logAiFlow(
            'AI_RESOLUTION_FAILED',
            aiCommand: aiCmd,
            extra: {'reason': 'missing_target_name'},
          );
          _showErrorSnackBar(
            'Trợ lý AI chưa xác định được người nhận hoặc cuộc trò chuyện đích.',
          );
          return;
        }
        final conversationMatches = chatProvider.findConversationMatchesByName(
          targetName,
        );

        if (conversationMatches.isEmpty) {
          _logAiFlow(
            'AI_RESOLUTION_FAILED',
            aiCommand: aiCmd,
            extra: {'targetName': targetName},
          );
          _showErrorSnackBar('Không tìm thấy "$targetName" trong danh bạ.');
          return;
        }

        Conversation? selectedConversation;
        if (conversationMatches.length > 1) {
          _logAiFlow(
            'AI_RESOLUTION_AMBIGUOUS',
            aiCommand: aiCmd,
            extra: {
              'targetName': targetName,
              'matchCount': conversationMatches.length,
            },
          );
          selectedConversation = await _showConversationDisambiguationSheet(
            matches: conversationMatches,
            currentUserId: chatProvider.currentUserId ?? '',
            targetName: targetName,
          );
          if (selectedConversation == null) {
            _logAiFlow('AI_COMMAND_CANCELLED', aiCommand: aiCmd);
            return;
          }
        }

        final conversation = selectedConversation ?? conversationMatches.first;
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

        final rawPrefilled = AiCommandRouting.extractPrefilledText(
          command,
          params,
        );
        final prefilledText = rawPrefilled;

        if (command == 'OPEN_CHAT' || command == 'COMPOSE_MESSAGE') {
          if (command == 'COMPOSE_MESSAGE' &&
              (prefilledText == null || prefilledText.isEmpty)) {
            _logAiFlow(
              'AI_SEND_MSG_BLOCKED',
              aiCommand: aiCmd,
              extra: {'reason': 'empty_content'},
            );
            _showErrorSnackBar(
              'Trợ lý AI không thể soạn tin nhắn vì nội dung trống.',
            );
            return;
          }

          final isAlreadyActiveConversation =
              chatProvider.activeConversationId == conversation.id;
          final hasPendingAiNavigation =
              _activeAiConversationId == conversation.id;

          if (command == 'OPEN_CHAT' &&
              AiCommandRouting.shouldBlockOpenChat(
                isAlreadyActiveConversation: isAlreadyActiveConversation,
                hasPendingAiNavigation: hasPendingAiNavigation,
              )) {
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

          if (command == 'COMPOSE_MESSAGE' &&
              AiCommandRouting.shouldBlockCompose(
                hasPendingAiNavigation: hasPendingAiNavigation,
              )) {
            _logAiFlow(
              'AI_NAV_GUARD_BLOCKED',
              aiCommand: aiCmd,
              extra: {
                'reason': 'compose_navigation_already_pending',
                'conversationId': conversation.id,
              },
            );
            return;
          }

          var shouldSendImmediately = false;
          if (command == 'COMPOSE_MESSAGE') {
            if (!mounted) return;
            final composeDecision = await AiActionConfirmationSheet.showForResult(
              context,
              icon: Icons.edit_note_rounded,
              title: 'Xác nhận hỗ trợ nhắn tin',
              description:
                  'Bạn có thể mở cuộc trò chuyện để kiểm tra lại hoặc gửi ngay sau khi đã xác nhận đúng người nhận.',
              confirmLabel: 'Mở và điền sẵn',
              alternateLabel: 'Gửi ngay',
              primaryDetail: peerName,
              secondaryDetail: prefilledText,
              primaryDetailLabel: 'Người nhận',
              secondaryDetailLabel: 'Tin nhắn',
            );
            if (composeDecision == AiActionConfirmationResult.cancelled) {
              _logAiFlow('AI_COMMAND_CANCELLED', aiCommand: aiCmd);
              return;
            }
            if (!mounted) return;
            shouldSendImmediately =
                composeDecision == AiActionConfirmationResult.alternate;

            if (isAlreadyActiveConversation) {
              if (shouldSendImmediately) {
                chatProvider.sendMessage(
                  conversationId: conversation.id,
                  content: prefilledText!,
                );
                _logAiFlow(
                  'AI_MESSAGE_SENT_IMMEDIATELY',
                  aiCommand: aiCmd,
                  extra: {'conversationId': conversation.id},
                );
              } else {
                chatProvider.injectAiComposeDraft(
                  conversationId: conversation.id,
                  text: prefilledText!,
                );
                _logAiFlow(
                  'AI_COMPOSE_DRAFT_INJECTED',
                  aiCommand: aiCmd,
                  extra: {'conversationId': conversation.id},
                );
              }
              setState(() => _currentIndex = 0);
              return;
            }
          }

          if (!mounted) return;
          await _dismissSoftKeyboard();
          if (!mounted) return;
          final navigator = Navigator.of(context);
          _activeAiConversationId = conversation.id;
          _logAiFlow(
            'AI_NAVIGATE_CHAT',
            aiCommand: aiCmd,
            extra: {
              'conversationId': conversation.id,
              'prefilled': prefilledText?.isNotEmpty == true,
            },
          );

          try {
            if (command == 'COMPOSE_MESSAGE' &&
                shouldSendImmediately &&
                prefilledText != null) {
              chatProvider.sendMessage(
                conversationId: conversation.id,
                content: prefilledText,
              );
              _logAiFlow(
                'AI_MESSAGE_SENT_IMMEDIATELY',
                aiCommand: aiCmd,
                extra: {'conversationId': conversation.id},
              );
            }
            await navigator.push(
              MaterialPageRoute(
                builder:
                    (_) => ChatDetailScreen(
                      conversation: conversation,
                      prefilledText:
                          shouldSendImmediately ? null : prefilledText,
                    ),
              ),
            );
          } finally {
            if (mounted && _activeAiConversationId == conversation.id) {
              _activeAiConversationId = null;
            }
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

          final callType = params?['callType']?.toString().toLowerCase();
          final isVideo = callType == 'video';
          final callTypeName = isVideo ? 'video' : 'thoại';

          if (!mounted) return;
          final confirmed = await AiActionConfirmationSheet.show(
            context,
            icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            title: 'Xác nhận gọi $callTypeName',
            description: 'Trợ lý sẽ bắt đầu cuộc gọi tới liên hệ đã chọn.',
            confirmLabel: 'Bắt đầu gọi',
            primaryDetail: 'Người nhận: $peerName',
          );
          if (!confirmed) {
            _logAiFlow('AI_COMMAND_CANCELLED', aiCommand: aiCmd);
            return;
          }
          if (!mounted) return;
          await _dismissSoftKeyboard();
          if (!mounted) return;

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
          final lastMsg = AiRecallMessageSelector.selectLatestRecallableMessage(
            messages: chatProvider.messages,
            currentUserId: chatProvider.currentUserId,
          );

          if (lastMsg == null) {
            _logAiFlow(
              'AI_RECALL_FAILED',
              aiCommand: aiCmd,
              extra: {'reason': 'no_self_message'},
            );
            _showErrorSnackBar('Không tìm thấy tin nhắn của bạn để thu hồi.');
            return;
          }

          final confirmed = await AiActionConfirmationSheet.show(
            context,
            icon: Icons.undo_rounded,
            title: 'Xác nhận thu hồi tin nhắn',
            description:
                'Trợ lý sẽ thu hồi tin nhắn mới nhất của bạn trong cuộc trò chuyện hiện tại.',
            confirmLabel: 'Thu hồi',
            secondaryDetail: lastMsg.content,
            destructive: true,
          );
          if (!confirmed) {
            _logAiFlow('AI_COMMAND_CANCELLED', aiCommand: aiCmd);
            return;
          }
          if (!mounted) return;

          chatProvider.recallMessage(
            lastMsg.id,
            chatProvider.activeConversationId!,
          );
        } else {
          _logAiFlow(
            'AI_RECALL_FAILED',
            aiCommand: aiCmd,
            extra: {'reason': 'no_active_conversation_or_messages'},
          );
          _showErrorSnackBar('Không có tin nhắn để thu hồi.');
        }
        break;

      case 'CREATE_GROUP':
        await _handleAiCreateGroup(aiCmd, params);
        break;
      case 'MUTE_CONVERSATION':
      case 'UNMUTE_CONVERSATION':
        await _handleAiMuteConversation(
          aiCmd,
          params,
          muted: command == 'MUTE_CONVERSATION',
        );
        break;
      case 'PIN_MESSAGE':
      case 'UNPIN_MESSAGE':
        await _handleAiPinMessage(aiCmd, params, pin: command == 'PIN_MESSAGE');
        break;
      case 'OPEN_PROFILE':
        await _handleAiOpenProfile(aiCmd, params);
        break;
      case 'OPEN_GROUP_SETTINGS':
        await _handleAiOpenGroupSettings(aiCmd, params);
        break;
      case 'SEND_FRIEND_REQUEST':
      case 'BLOCK_USER':
      case 'UNBLOCK_USER':
        await _handleAiContactAction(aiCmd, params, command: command);
        break;
      case 'CHANGE_GROUP_NAME':
      case 'ADD_GROUP_MEMBER':
      case 'REMOVE_GROUP_MEMBER':
      case 'TRANSFER_GROUP_OWNER':
      case 'LEAVE_GROUP':
      case 'DISBAND_GROUP':
        await _handleAiGroupAdminAction(aiCmd, params, command: command);
        break;

      default:
        _logAiFlow(
          'AI_UNKNOWN_COMMAND',
          aiCommand: aiCmd,
          extra: {'command': command},
        );
    }
  }

  Future<Conversation?> _showConversationDisambiguationSheet({
    required List<Conversation> matches,
    required String currentUserId,
    required String targetName,
  }) async {
    return AiConversationDisambiguationSheet.show(
      context,
      matches: matches,
      currentUserId: currentUserId,
      targetName: targetName,
    );
  }

  Conversation? _conversationById(ChatProvider chatProvider, String? id) {
    if (id == null || id.trim().isEmpty) return null;
    return chatProvider.conversations
        .where((conversation) => conversation.id == id.trim())
        .firstOrNull;
  }

  Future<Conversation?> _resolveAiConversation(
    AiCommand aiCmd,
    Map<String, dynamic>? params, {
    bool requireGroup = false,
  }) async {
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = chatProvider.currentUserId ?? '';
    final explicitId = (params?['conversationId'] ?? params?['id'])?.toString();
    final byId = _conversationById(chatProvider, explicitId);
    if (byId != null) {
      if (requireGroup && byId.type.name != 'GROUP') {
        _showErrorSnackBar('Cuộc trò chuyện đã chọn không phải nhóm.');
        return null;
      }
      return byId;
    }

    final targetName =
        AiCommandRouting.extractConversationName(params) ??
        AiCommandRouting.extractTargetName(params);
    if (targetName.isNotEmpty) {
      final matches = chatProvider.findConversationMatchesByName(targetName);
      final filtered =
          requireGroup
              ? matches
                  .where((conversation) => conversation.type.name == 'GROUP')
                  .toList()
              : matches;
      if (filtered.isEmpty) {
        _showErrorSnackBar('Không tìm thấy cuộc trò chuyện "$targetName".');
        return null;
      }
      if (filtered.length > 1) {
        return _showConversationDisambiguationSheet(
          matches: filtered,
          currentUserId: currentUserId,
          targetName: targetName,
        );
      }
      return filtered.first;
    }

    final active = _conversationById(
      chatProvider,
      chatProvider.activeConversationId,
    );
    if (active != null && (!requireGroup || active.type.name == 'GROUP')) {
      return active;
    }

    _showErrorSnackBar(
      requireGroup
          ? 'Trợ lý chưa xác định được nhóm cần thao tác.'
          : 'Trợ lý chưa xác định được cuộc trò chuyện cần thao tác.',
    );
    return null;
  }

  List<User> _findUsersByName(Iterable<User> users, String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return const <User>[];
    final exact =
        users
            .where(
              (user) => user.displayName.trim().toLowerCase() == normalized,
            )
            .toList();
    if (exact.isNotEmpty) return exact;
    return users
        .where(
          (user) => user.displayName.trim().toLowerCase().contains(normalized),
        )
        .toList();
  }

  Future<User?> _resolveAiFriend(
    AiCommand aiCmd,
    Map<String, dynamic>? params, {
    String? fallbackName,
  }) async {
    final contactProvider = context.read<ContactProvider>();
    if (contactProvider.friends.isEmpty) {
      await contactProvider.fetchFriends();
    }

    final explicitId = (params?['userId'] ?? params?['friendId'])?.toString();
    if (explicitId != null && explicitId.trim().isNotEmpty) {
      final match =
          contactProvider.friends
              .where((user) => user.id == explicitId.trim())
              .firstOrNull;
      if (match != null) return match;
    }

    final name = fallbackName ?? AiCommandRouting.extractTargetName(params);
    final matches = _findUsersByName(contactProvider.friends, name);
    if (matches.isEmpty) {
      _showErrorSnackBar('Không tìm thấy "$name" trong danh bạ.');
      return null;
    }
    if (matches.length > 1) {
      _showErrorSnackBar(
        'Có nhiều người tên "$name". Hãy nói rõ họ tên hoặc mở danh bạ để chọn.',
      );
      return null;
    }
    return matches.first;
  }

  List<User> _resolveGroupMembersByName(
    Conversation conversation,
    List<String> names,
  ) {
    final members =
        conversation.members
            .where((member) => member.user != null)
            .map((member) => member.user!)
            .toList();
    final resolved = <User>[];
    for (final name in names) {
      final matches = _findUsersByName(members, name);
      if (matches.length != 1) {
        throw StateError(
          matches.isEmpty
              ? 'Không tìm thấy thành viên "$name" trong nhóm.'
              : 'Có nhiều thành viên tên "$name". Hãy nói rõ hơn.',
        );
      }
      resolved.add(matches.first);
    }
    return resolved;
  }

  Message? _latestActionableMessage(ChatProvider chatProvider) {
    final currentUserId = chatProvider.currentUserId;
    for (final message in chatProvider.messages.reversed) {
      if (message.isSystemMessage || message.isRecalled) continue;
      if (currentUserId != null && message.senderId == currentUserId) {
        return message;
      }
    }
    return null;
  }

  Future<bool> _confirmAiAction({
    required IconData icon,
    required String title,
    required String description,
    required String confirmLabel,
    String? primaryDetail,
    String? secondaryDetail,
    String? primaryDetailLabel,
    String? secondaryDetailLabel,
    bool destructive = false,
  }) {
    return AiActionConfirmationSheet.show(
      context,
      icon: icon,
      title: title,
      description: description,
      confirmLabel: confirmLabel,
      primaryDetail: primaryDetail,
      secondaryDetail: secondaryDetail,
      primaryDetailLabel: primaryDetailLabel,
      secondaryDetailLabel: secondaryDetailLabel,
      destructive: destructive,
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _handleAiCreateGroup(
    AiCommand aiCmd,
    Map<String, dynamic>? params,
  ) async {
    final groupName = AiCommandRouting.extractGroupName(params);
    final memberNames = AiCommandRouting.extractMemberNames(params);
    if (groupName.isEmpty || memberNames.isEmpty) {
      _showErrorSnackBar('Trợ lý cần tên nhóm và ít nhất một thành viên.');
      return;
    }

    final contactProvider = context.read<ContactProvider>();
    if (contactProvider.friends.isEmpty) {
      await contactProvider.fetchFriends();
    }
    final selectedUsers = <User>[];
    for (final name in memberNames) {
      final matches = _findUsersByName(contactProvider.friends, name);
      if (matches.length != 1) {
        _showErrorSnackBar(
          matches.isEmpty
              ? 'Không tìm thấy "$name" trong danh bạ.'
              : 'Có nhiều người tên "$name". Hãy nói rõ họ tên.',
        );
        return;
      }
      selectedUsers.add(matches.first);
    }

    final confirmed = await _confirmAiAction(
      icon: Icons.group_add_rounded,
      title: 'Xác nhận tạo nhóm',
      description: 'Trợ lý sẽ tạo nhóm mới với các thành viên đã chọn.',
      confirmLabel: 'Tạo nhóm',
      primaryDetail: groupName,
      primaryDetailLabel: 'Tên nhóm',
      secondaryDetail: selectedUsers.map((user) => user.displayName).join(', '),
      secondaryDetailLabel: 'Thành viên',
    );
    if (!confirmed || !mounted) return;

    final conversation = await context
        .read<ChatProvider>()
        .createGroupConversation(
          title: groupName,
          memberIds: selectedUsers.map((user) => user.id).toList(),
        );
    if (conversation != null && mounted) {
      _showSuccessSnackBar('Đã tạo nhóm "$groupName".');
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversation: conversation),
        ),
      );
    }
  }

  Future<void> _handleAiMuteConversation(
    AiCommand aiCmd,
    Map<String, dynamic>? params, {
    required bool muted,
  }) async {
    final currentUserId = context.read<ChatProvider>().currentUserId ?? '';
    final conversation = await _resolveAiConversation(aiCmd, params);
    if (conversation == null) return;
    final confirmed = await _confirmAiAction(
      icon:
          muted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
      title: muted ? 'Tắt thông báo' : 'Bật thông báo',
      description:
          muted
              ? 'Trợ lý sẽ tắt thông báo cho cuộc trò chuyện này.'
              : 'Trợ lý sẽ bật lại thông báo cho cuộc trò chuyện này.',
      confirmLabel: muted ? 'Tắt thông báo' : 'Bật thông báo',
      primaryDetail: conversation.getDisplayName(currentUserId),
    );
    if (!confirmed || !mounted) return;
    await context.read<ChatProvider>().updateConversationSettings(
      conversationId: conversation.id,
      isMuted: muted,
    );
    _showSuccessSnackBar(muted ? 'Đã tắt thông báo.' : 'Đã bật thông báo.');
  }

  Future<void> _handleAiPinMessage(
    AiCommand aiCmd,
    Map<String, dynamic>? params, {
    required bool pin,
  }) async {
    final chatProvider = context.read<ChatProvider>();
    final messageId = (params?['messageId'] ?? params?['id'])?.toString();
    Message? message;
    if (messageId != null && messageId.trim().isNotEmpty) {
      message =
          chatProvider.messages
              .where((item) => item.id == messageId.trim())
              .firstOrNull;
    }
    message ??= _latestActionableMessage(chatProvider);
    if (message == null) {
      _showErrorSnackBar('Không tìm thấy tin nhắn phù hợp để ghim/bỏ ghim.');
      return;
    }
    final confirmed = await _confirmAiAction(
      icon: pin ? Icons.push_pin_rounded : Icons.push_pin_outlined,
      title: pin ? 'Xác nhận ghim tin nhắn' : 'Xác nhận bỏ ghim tin nhắn',
      description:
          pin
              ? 'Trợ lý sẽ ghim tin nhắn trong cuộc trò chuyện hiện tại.'
              : 'Trợ lý sẽ bỏ ghim tin nhắn trong cuộc trò chuyện hiện tại.',
      confirmLabel: pin ? 'Ghim' : 'Bỏ ghim',
      secondaryDetail: message.content,
      secondaryDetailLabel: 'Tin nhắn',
    );
    if (!confirmed || !mounted) return;
    if (pin) {
      chatProvider.pinMessage(message.id);
    } else {
      chatProvider.unpinMessage(message.id);
    }
  }

  Future<void> _handleAiOpenProfile(
    AiCommand aiCmd,
    Map<String, dynamic>? params,
  ) async {
    final user = await _resolveAiFriend(aiCmd, params);
    if (user == null || !mounted) return;
    Conversation? direct;
    final chatProvider = context.read<ChatProvider>();
    final matches = chatProvider.findConversationMatchesByName(
      user.displayName,
    );
    direct =
        matches
            .where((conversation) => conversation.type.name == 'DIRECT')
            .firstOrNull;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => FriendOptionsScreen(
              friendName: user.displayName,
              friendAvatarUrl: user.avatarUrl,
              friendUserId: user.id,
              conversation: direct,
            ),
      ),
    );
  }

  Future<void> _handleAiOpenGroupSettings(
    AiCommand aiCmd,
    Map<String, dynamic>? params,
  ) async {
    final conversation = await _resolveAiConversation(
      aiCmd,
      params,
      requireGroup: true,
    );
    if (conversation == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupSettingsScreen(conversation: conversation),
      ),
    );
  }

  Future<void> _handleAiContactAction(
    AiCommand aiCmd,
    Map<String, dynamic>? params, {
    required String command,
  }) async {
    final user = await _resolveAiFriend(aiCmd, params);
    if (user == null) return;
    final destructive = command == 'BLOCK_USER';
    final title = switch (command) {
      'SEND_FRIEND_REQUEST' => 'Xác nhận gửi kết bạn',
      'BLOCK_USER' => 'Xác nhận chặn người dùng',
      'UNBLOCK_USER' => 'Xác nhận bỏ chặn người dùng',
      _ => 'Xác nhận thao tác',
    };
    final confirmLabel = switch (command) {
      'SEND_FRIEND_REQUEST' => 'Gửi kết bạn',
      'BLOCK_USER' => 'Chặn',
      'UNBLOCK_USER' => 'Bỏ chặn',
      _ => 'Xác nhận',
    };
    final description = switch (command) {
      'SEND_FRIEND_REQUEST' => 'Trợ lý sẽ gửi lời mời kết bạn đến người này.',
      'BLOCK_USER' => 'Bạn sẽ không nhận tin nhắn/cuộc gọi từ người này.',
      'UNBLOCK_USER' => 'Bạn sẽ cho phép liên hệ lại với người này.',
      _ => 'Trợ lý sẽ thực hiện thao tác đã chọn.',
    };
    final confirmed = await _confirmAiAction(
      icon: destructive ? Icons.block_rounded : Icons.person_add_alt_1_rounded,
      title: title,
      description: description,
      confirmLabel: confirmLabel,
      primaryDetail: user.displayName,
      primaryDetailLabel: 'Liên hệ',
      destructive: destructive,
    );
    if (!confirmed || !mounted) return;
    final friendService = context.read<FriendService>();
    if (command == 'SEND_FRIEND_REQUEST') {
      await friendService.sendFriendRequest(
        user.id,
        message: AiCommandRouting.extractFriendRequestMessage(params),
      );
      if (!mounted) return;
      context.read<ContactProvider>().onFriendshipUpdated();
      _showSuccessSnackBar('Đã gửi lời mời kết bạn.');
    } else if (command == 'BLOCK_USER') {
      await friendService.blockUser(user.id);
      if (!mounted) return;
      context.read<ContactProvider>().onFriendshipUpdated();
      _showSuccessSnackBar('Đã chặn ${user.displayName}.');
    } else if (command == 'UNBLOCK_USER') {
      await friendService.unblockUser(user.id);
      if (!mounted) return;
      context.read<ContactProvider>().onFriendshipUpdated();
      _showSuccessSnackBar('Đã bỏ chặn ${user.displayName}.');
    }
  }

  Future<void> _handleAiGroupAdminAction(
    AiCommand aiCmd,
    Map<String, dynamic>? params, {
    required String command,
  }) async {
    final chatProvider = context.read<ChatProvider>();
    final conversation = await _resolveAiConversation(
      aiCmd,
      params,
      requireGroup: true,
    );
    if (conversation == null) return;

    Future<void> execute() async {
      switch (command) {
        case 'CHANGE_GROUP_NAME':
          final title = AiCommandRouting.extractNewTitle(params);
          if (title == null) {
            throw StateError('Trợ lý chưa có tên nhóm mới.');
          }
          await chatProvider.updateGroupInfo(conversation.id, title: title);
          break;
        case 'ADD_GROUP_MEMBER':
          final names = AiCommandRouting.extractMemberNames(params);
          if (names.isEmpty) {
            throw StateError('Trợ lý chưa xác định thành viên cần thêm.');
          }
          final contactProvider = context.read<ContactProvider>();
          if (contactProvider.friends.isEmpty) {
            await contactProvider.fetchFriends();
          }
          final users = <User>[];
          for (final name in names) {
            final matches = _findUsersByName(contactProvider.friends, name);
            if (matches.length != 1) {
              throw StateError(
                matches.isEmpty
                    ? 'Không tìm thấy "$name" trong danh bạ.'
                    : 'Có nhiều người tên "$name". Hãy nói rõ hơn.',
              );
            }
            users.add(matches.first);
          }
          await chatProvider.addMembersToGroup(conversation.id, users);
          break;
        case 'REMOVE_GROUP_MEMBER':
          final users = _resolveGroupMembersByName(
            conversation,
            AiCommandRouting.extractMemberNames(params),
          );
          if (users.isEmpty) {
            throw StateError('Trợ lý chưa xác định thành viên cần xóa.');
          }
          for (final user in users) {
            await chatProvider.removeMember(conversation.id, user.id);
          }
          break;
        case 'TRANSFER_GROUP_OWNER':
          final users = _resolveGroupMembersByName(
            conversation,
            AiCommandRouting.extractMemberNames(params),
          );
          if (users.length != 1) {
            throw StateError('Cần chọn đúng một thành viên để chuyển quyền.');
          }
          await chatProvider.transferOwnership(conversation.id, users.first.id);
          break;
        case 'LEAVE_GROUP':
          await chatProvider.leaveGroup(conversation.id);
          break;
        case 'DISBAND_GROUP':
          await chatProvider.disbandGroup(conversation.id);
          break;
      }
    }

    final memberNames = AiCommandRouting.extractMemberNames(params);
    final title = AiCommandRouting.extractNewTitle(params);
    final destructive =
        command == 'REMOVE_GROUP_MEMBER' ||
        command == 'LEAVE_GROUP' ||
        command == 'DISBAND_GROUP';
    final confirmed = await _confirmAiAction(
      icon:
          destructive
              ? Icons.warning_amber_rounded
              : Icons.admin_panel_settings_rounded,
      title: _groupActionTitle(command),
      description: _groupActionDescription(command),
      confirmLabel: _groupActionConfirmLabel(command),
      primaryDetail: conversation.getDisplayName(
        chatProvider.currentUserId ?? '',
      ),
      primaryDetailLabel: 'Nhóm',
      secondaryDetail:
          title ?? (memberNames.isEmpty ? null : memberNames.join(', ')),
      secondaryDetailLabel: title != null ? 'Tên mới' : 'Thành viên',
      destructive: destructive,
    );
    if (!confirmed || !mounted) return;
    try {
      await execute();
      if (mounted) _showSuccessSnackBar('Trợ lý đã thực hiện thao tác nhóm.');
    } catch (error) {
      _showErrorSnackBar(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  String _groupActionTitle(String command) => switch (command) {
    'CHANGE_GROUP_NAME' => 'Xác nhận đổi tên nhóm',
    'ADD_GROUP_MEMBER' => 'Xác nhận thêm thành viên',
    'REMOVE_GROUP_MEMBER' => 'Xác nhận xóa thành viên',
    'TRANSFER_GROUP_OWNER' => 'Xác nhận chuyển quyền nhóm',
    'LEAVE_GROUP' => 'Xác nhận rời nhóm',
    'DISBAND_GROUP' => 'Xác nhận giải tán nhóm',
    _ => 'Xác nhận thao tác nhóm',
  };

  String _groupActionDescription(String command) => switch (command) {
    'CHANGE_GROUP_NAME' => 'Trợ lý sẽ cập nhật tên nhóm sau khi bạn xác nhận.',
    'ADD_GROUP_MEMBER' => 'Trợ lý sẽ thêm thành viên vào nhóm này.',
    'REMOVE_GROUP_MEMBER' => 'Thành viên được chọn sẽ bị mời khỏi nhóm.',
    'TRANSFER_GROUP_OWNER' =>
      'Quyền trưởng nhóm sẽ được chuyển cho thành viên này.',
    'LEAVE_GROUP' => 'Bạn sẽ rời khỏi nhóm này.',
    'DISBAND_GROUP' => 'Nhóm sẽ bị giải tán cho tất cả thành viên.',
    _ => 'Trợ lý sẽ thực hiện thao tác nhóm đã chọn.',
  };

  String _groupActionConfirmLabel(String command) => switch (command) {
    'CHANGE_GROUP_NAME' => 'Đổi tên',
    'ADD_GROUP_MEMBER' => 'Thêm',
    'REMOVE_GROUP_MEMBER' => 'Xóa khỏi nhóm',
    'TRANSFER_GROUP_OWNER' => 'Chuyển quyền',
    'LEAVE_GROUP' => 'Rời nhóm',
    'DISBAND_GROUP' => 'Giải tán',
    _ => 'Xác nhận',
  };

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
          debugPrint(
            'ðŸŽ¨ [MainShell] Rebuilding BottomNavigationBar (pendingFriendCount: ${contactProvider.pendingRequestCount})',
          );
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
