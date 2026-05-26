import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/features/contacts/screens/send_request_screen.dart';
import 'package:vnalo_mobile/features/call/screens/voice_call_screen.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

enum SearchInitialTab { mine, discover }

class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({
    super.key,
    this.initialTab = SearchInitialTab.mine,
    this.searchTag = 'search_bar',
  });

  final SearchInitialTab initialTab;
  final String searchTag;

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen>
    with SingleTickerProviderStateMixin {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _primaryColor => isDarkMode ? DarkColors.primary : AppColors.primary;
  final TextEditingController _queryController = TextEditingController();
  late final TabController _tabController;
  int _searchRequestId = 0;

  List<User> _recentFriends = <User>[];
  bool _loadingRecent = true;

  User? _strangerFoundByPhone;
  List<User> _friendResults = [];
  List<LocalContact> _localContactResults = [];
  List<LocalMessageSearchResult> _localMessageResults = [];
  bool _isSearching = false;
  bool _isCancelling = false;
  
  // Results expansion states
  bool _isFriendsExpanded = false;
  bool _isContactsExpanded = false;
  bool _isConversationsExpanded = false;
  bool _isMessagesExpanded = false;
  
  // These filter values will be localized in build/logic
  String _selectedFilterKey = 'all'; // 'all', 'link', 'file'

  int get _mineCount =>
      _localContactResults.length +
      _localMessageResults.length +
      (_strangerFoundByPhone != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == SearchInitialTab.mine ? 0 : 1,
    );
    _loadRecentFriends();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chatProvider = context.read<ChatProvider>();
      if (chatProvider.conversations.isEmpty) {
        chatProvider.loadInbox();
      }
    });
  }

  Future<void> _loadRecentFriends() async {
    try {
      final friends = await context.read<FriendService>().getFriends();
      if (!mounted) return;
      setState(() {
        _recentFriends = friends;
        _loadingRecent = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRecent = false);
    }
  }

  String _digitsOnly(String? value) {
    if (value == null) return '';
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalizePhoneForLookup(String? value) {
    final digits = _digitsOnly(value);
    if (digits.isEmpty) return '';

    if (digits.startsWith('84') && digits.length >= 11) {
      return '0${digits.substring(2)}';
    }
    if (digits.startsWith('0')) {
      return digits;
    }
    if (digits.length == 9) {
      return '0$digits';
    }
    return digits;
  }

  bool _isPhoneLikeQuery(String query) {
    final digits = _digitsOnly(query);
    if (digits.length < 9 || digits.length > 15) return false;
    final nonPhoneChars = query.replaceAll(RegExp(r'[0-9\s\+\-\(\)\.]'), '');
    return nonPhoneChars.isEmpty;
  }

  User? _findFriendByPhoneQuery(String query) {
    final q = _normalizePhoneForLookup(query);
    if (q.isEmpty) return null;

    for (final friend in _recentFriends) {
      final friendPhone = _normalizePhoneForLookup(friend.phone);
      if (friendPhone.isEmpty) continue;
      if (friendPhone.contains(q) || q.contains(friendPhone)) {
        return friend.copyWith(friendshipStatus: 'FRIEND');
      }
    }
    return null;
  }

  List<User> _findFriendsByQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final qPhone = _normalizePhoneForLookup(query);
    final results = <User>[];
    for (final friend in _recentFriends) {
      final nameHit = friend.displayName.toLowerCase().contains(q);
      final friendPhone = _normalizePhoneForLookup(friend.phone);
      final phoneHit = qPhone.isNotEmpty && friendPhone.isNotEmpty && (friendPhone.contains(qPhone) || qPhone.contains(friendPhone));
      if (nameHit || phoneHit) {
        results.add(friend.copyWith(friendshipStatus: 'FRIEND'));
      }
    }
    return results;
  }

  Future<User?> _searchUserByPhoneWithFallback(String query, User? localFriendMatch) async {
    User? remote;
    try {
      remote = await context.read<FriendService>().searchUserByPhone(query);
    } catch (_) {
      remote = null;
    }

    if (remote != null) {
      final isFriend = _recentFriends.any((f) => f.id == remote!.id);
      if (isFriend) {
        return remote.copyWith(friendshipStatus: 'FRIEND');
      }
      return remote;
    }
    return localFriendMatch;
  }

  String _effectiveFriendshipStatus(User user) {
    final status = user.friendshipStatus?.toUpperCase();
    if (status != null && status.isNotEmpty) {
      return status;
    }
    final isFriend = _recentFriends.any((f) => f.id == user.id);
    return isFriend ? 'FRIEND' : 'NONE';
  }

  @override
  void dispose() {
    _queryController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performHybridSearch(String query) async {
    final requestId = ++_searchRequestId;
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _isSearching = false;
        _strangerFoundByPhone = null;
        _friendResults = [];
        _localContactResults = [];
        _localMessageResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id ?? '';
    final db = context.read<LocalDatabase>();
    final contactsTask = db.searchContacts(q, userId);
    final messagesTask = db.searchMessages(q, userId);

    final localFriendMatch = _findFriendByPhoneQuery(q);

    Future<User?> phoneTask = Future.value(null);
    if (_isPhoneLikeQuery(q)) {
      phoneTask = _searchUserByPhoneWithFallback(q, localFriendMatch);
    }

    final results = await Future.wait([contactsTask, messagesTask, phoneTask]);

    if (!mounted || requestId != _searchRequestId) return;

    final phoneUser = results[2] as User?;
    final friendResults = _findFriendsByQuery(q)
      ..removeWhere((u) => u.id == phoneUser?.id);

    setState(() {
      _localMessageResults = (results[1] as List<LocalMessageSearchResult>)
          .where((m) =>
              m.message.messageType != 'SYSTEM' &&
              !m.message.content.contains('CALL_LOG'))
          .toList();
      _strangerFoundByPhone = phoneUser;
      _friendResults = friendResults;
      _isSearching = false;
    });

    if (_strangerFoundByPhone != null &&
        _strangerFoundByPhone!.friendshipStatus?.toUpperCase() != 'PENDING_SENT') {
      _verifyStrangerStatus(_strangerFoundByPhone!.id, requestId);
    }
  }

  Future<void> _verifyStrangerStatus(String userId, int requestId) async {
    final friendService = context.read<FriendService>();

    if (_recentFriends.any((f) => f.id == userId)) {
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          if (_strangerFoundByPhone?.id == userId) {
            _strangerFoundByPhone = _strangerFoundByPhone?.copyWith(friendshipStatus: 'FRIEND');
          }
        });
      }
      return;
    }

    final status = await friendService.getFriendshipStatus(userId);
    if (status != null && mounted && requestId == _searchRequestId) {
      setState(() {
        if (_strangerFoundByPhone?.id == userId) {
          _strangerFoundByPhone = _strangerFoundByPhone?.copyWith(friendshipStatus: status.toUpperCase());
        }
      });
      return;
    }

    final isSent = await friendService.checkSentRequest(userId);
    if (isSent && mounted && requestId == _searchRequestId) {
      setState(() {
        if (_strangerFoundByPhone?.id == userId) {
          _strangerFoundByPhone = _strangerFoundByPhone?.copyWith(
            friendshipStatus: 'PENDING_SENT',
          );
        }
      });
    }
  }

  TextSpan _highlightText(
    String text,
    String query, {
    required TextStyle baseStyle,
    Color? highlightColor,
  }) {
    final effectiveHighlightColor = highlightColor ?? AppColors.primary;
    if (query.isEmpty) return TextSpan(text: text, style: baseStyle);

    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    if (!lowerText.contains(lowerQuery)) {
      return TextSpan(text: text, style: baseStyle);
    }

    final List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      spans.add(
        TextSpan(
          text: text.substring(indexOfMatch, indexOfMatch + query.length),
          style: TextStyle(
            color: effectiveHighlightColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = indexOfMatch + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  Future<void> _handleLocalContactTap(LocalContact contact) async {
    final common = CommonTexts.of(context, listen: false);
    try {
      final chatService = context.read<ChatService>();
      final conversation = await chatService.getOrCreateDirect(contact.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(common.language == AppLanguage.vi ? 'Không mở được cuộc trò chuyện.' : 'Could not open conversation.')),
      );
    }
  }

  Future<void> _handleLocalMessageTap(LocalMessage msg) async {
    final common = CommonTexts.of(context, listen: false);
    try {
      final db = context.read<LocalDatabase>();
      final chatService = context.read<ChatService>();

      final userId = context.read<AuthProvider>().user?.id ?? '';
      LocalConversation? localConv = await db.getLocalConversationById(msg.conversationId, userId);
      Conversation? conv;
      if (localConv != null) {
        conv = Conversation.fromLocal(localConv);
      } else {
        conv = await chatService.getConversationById(msg.conversationId);
        if (conv == null) {
          final inbox = await chatService.getInbox();
          for (final item in inbox) {
            if (item.id == msg.conversationId) {
              conv = item;
              break;
            }
          }
        }
        if (conv == null) {
          throw StateError('Conversation not found');
        }
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversation: conv!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(common.language == AppLanguage.vi ? 'Không thể mở cuộc trò chuyện này.' : 'Cannot open this conversation.')),
      );
    }
  }

  Future<void> _handleStrangerCancel(User user) async {
    final isVi = CommonTexts.of(context, listen: false).language == AppLanguage.vi;
    setState(() => _isCancelling = true);
    try {
      await context.read<FriendService>().cancelRequestByUserId(user.id);
      if (!mounted) return;
      setState(() {
        _strangerFoundByPhone = _strangerFoundByPhone?.copyWith(
          friendshipStatus: 'NONE',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVi ? 'Đã hủy lời mời đến ${user.displayName}' : 'Cancelled request to ${user.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVi ? 'Không thể hủy lời mời: $e' : 'Failed to cancel request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _openChat(User user) async {
    final common = CommonTexts.of(context, listen: false);
    try {
      final conversation = await context.read<ChatService>().getOrCreateDirect(user.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            conversation: conversation,
            friendUser: user,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(common.language == AppLanguage.vi ? 'Không mở được cuộc trò chuyện.' : 'Could not open conversation.')),
      );
    }
  }

  Future<void> _handleUnfriend(User user) async {
    final isVi = CommonTexts.of(context, listen: false).language == AppLanguage.vi;
    setState(() => _isCancelling = true);
    try {
      await context.read<FriendService>().unfriend(user.id);
      if (!mounted) return;

      setState(() {
        _strangerFoundByPhone = _strangerFoundByPhone?.copyWith(friendshipStatus: 'NONE');
        _recentFriends = _recentFriends.where((f) => f.id != user.id).toList();
        _friendResults = _friendResults.where((f) => f.id != user.id).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVi ? 'Đã hủy kết bạn với ${user.displayName}' : 'Unfriended ${user.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVi ? 'Không thể hủy kết bạn: $e' : 'Failed to unfriend: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim();
    final common = CommonTexts.of(context);

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        forceMaterialTransparency: !isDarkMode,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: BoxDecoration(
                  gradient: AppColors.appBarGradient,
                ),
              ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: isDarkMode ? Colors.white : Colors.black.withValues(alpha: 0.3),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: common.searchHint,
                            hintStyle: TextStyle(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.black.withValues(alpha: 0.3),
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _performHybridSearch,
                        ),
                      ),
                      if (query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _queryController.clear();
                            _performHybridSearch('');
                          },
                          child: Icon(
                            Icons.close,
                            color: isDarkMode ? Colors.white : Colors.black.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      body: query.isEmpty ? _buildDefaultView() : _buildResultList(query),
    );
  }

  Widget _buildDefaultView() {
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    return Column(
      children: [
        Container(
          color: isDarkMode ? DarkColors.surface : LightColors.surface,
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            labelColor: _primaryColor,
            unselectedLabelColor: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isVi ? 'Của tôi' : 'Mine'),
                    if (_mineCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${_mineCount > 99 ? '99+' : _mineCount})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(text: isVi ? 'Khám phá' : 'Discover'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMineTab(),
              _buildDiscoverTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMineTab() {
    final common = CommonTexts.of(context);
    final isVi = common.language == AppLanguage.vi;
    return ListView(
      children: [
        _sectionHeader(isVi ? 'Liên hệ vừa tìm' : 'Recent contacts'),
        if (_loadingRecent)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_recentFriends.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isVi ? 'Chưa có lịch sử tìm kiếm' : 'No search history',
              style: TextStyle(color: isDarkMode ? DarkColors.textHint : Colors.grey),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _recentFriends.length,
              itemBuilder: (context, index) {
                final friend = _recentFriends[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      AvatarWidget(imageUrl: friend.avatarUrl, name: friend.displayName, size: 52),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          friend.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDiscoverTab() {
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    return Center(
      child: Text(
        isVi ? 'Khám phá các tính năng mới trên Vnalo' : 'Discover new features on Vnalo',
        style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary)
      )
    );
  }

  Widget _buildResultList(String query) {
    final conversationMatches = _findConversationsByName(query);

    if (_strangerFoundByPhone == null &&
      _friendResults.isEmpty &&
        _localContactResults.isEmpty &&
        _localMessageResults.isEmpty &&
        conversationMatches.isEmpty) {
      if (_isSearching) {
        return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2)));
      }
      final isVi = CommonTexts.of(context).language == AppLanguage.vi;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                isVi 
                  ? 'Không tìm thấy liên hệ, tin nhắn\ncó chứa nội dung bạn đang tìm kiếm'
                  : 'No contacts or messages found matching your search',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF757575), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final displayedIds = <String>{};

    return ListView(
      children: [
        if (_strangerFoundByPhone != null) ...[
          _buildStrangerSection(displayedIds),
          const SizedBox(height: 8),
        ],
        if (_friendResults.isNotEmpty) ...[
          _buildFriendSection(query, displayedIds),
          const SizedBox(height: 8),
        ],
        if (conversationMatches.isNotEmpty) ...[
          _buildConversationSection(query, conversationMatches, displayedIds),
          const SizedBox(height: 8),
        ],
        if (_localContactResults.isNotEmpty) ...[
          _buildContactSection(query, displayedIds),
          const SizedBox(height: 8),
        ],
        if (_localMessageResults.isNotEmpty) ...[
          _buildMessageSection(query, displayedIds),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildFriendSection(String query, Set<String> displayedIds) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;

    final results = _friendResults.where((r) => !displayedIds.contains(r.id)).toList();
    if (results.isEmpty) return const SizedBox.shrink();

    final threshold = 5;
    final showAll = _isFriendsExpanded || results.length <= threshold;
    final displayList = showAll ? results : results.take(threshold).toList();

    return Container(
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(isVi ? 'Bạn bè' : 'Friends', count: results.length.toString(), showEdit: false),
          Column(
            children: List.generate(displayList.length, (index) {
              final user = displayList[index];
              displayedIds.add(user.id);
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: AvatarWidget(imageUrl: user.avatarUrl, name: user.displayName, size: 52),
                    title: RichText(
                      text: _highlightText(
                        user.displayName,
                        query,
                        baseStyle: TextStyle(
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      user.phone ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                      onPressed: () => _handleCallAction(user),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                        shape: const CircleBorder(),
                        fixedSize: const Size(32, 32),
                      ),
                    ),
                    onTap: () => _openChat(user),
                  ),
                  if (index < displayList.length - 1)
                    Divider(height: 1, thickness: 0.5, indent: 84, color: dividerColor),
                ],
              );
            }),
          ),
          if (results.length > threshold && !_isFriendsExpanded)
            GestureDetector(
              onTap: () => setState(() => _isFriendsExpanded = true),
              child: Container(
                width: double.infinity,
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isVi ? 'Xem thêm' : 'See more',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
                    ),
                    Icon(Icons.expand_more, size: 18, color: Colors.black.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Conversation> _findConversationsByName(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final conversations = context.read<ChatProvider>().conversations;

    final results = <Conversation>[];
    for (final conv in conversations) {
      final displayName = conv.getDisplayName(currentUserId).toLowerCase();
      if (displayName.contains(q)) {
        results.add(conv);
      }
    }
    return results;
  }

  Widget _buildConversationSection(String query, List<Conversation> conversations, Set<String> displayedIds) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';

    final results = conversations.where((c) {
      if (c.type == ConversationType.DIRECT && c.members.isNotEmpty) {
        final otherId = c.members.firstWhere((m) => m.userId != currentUserId, orElse: () => c.members.first).userId;
        return !displayedIds.contains(otherId);
      }
      return !displayedIds.contains(c.id);
    }).toList();
    
    if (results.isEmpty) return const SizedBox.shrink();

    const threshold = 5;
    final showAll = _isConversationsExpanded || results.length <= threshold;
    final displayList = showAll ? results : results.take(threshold).toList();

    return Container(
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            isVi ? 'Cuộc trò chuyện' : 'Conversations',
            count: results.length.toString(),
            showEdit: false,
          ),
          Column(
            children: List.generate(displayList.length, (index) {
              final conv = displayList[index];
              displayedIds.add(conv.id);
              final displayName = conv.getDisplayName(currentUserId);
              final avatarUrl = conv.getDisplayAvatarUrl(currentUserId);

              return Column(
                children: [
                  ListTile(
                    leading: AvatarWidget(imageUrl: avatarUrl, name: displayName, size: 52),
                    title: RichText(
                      text: _highlightText(
                        displayName,
                        query,
                        baseStyle: TextStyle(
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                      onPressed: () => _handleCallAction(conv),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE3F2FD),
                        shape: const CircleBorder(),
                        fixedSize: const Size(32, 32),
                      ),
                    ),
                    onTap: () => _openConversation(conv),
                  ),
                  if (index < displayList.length - 1)
                    Divider(height: 1, thickness: 0.5, indent: 84, color: dividerColor),
                ],
              );
            }),
          ),
          if (results.length > threshold && !_isConversationsExpanded)
            GestureDetector(
              onTap: () => setState(() => _isConversationsExpanded = true),
              child: Container(
                width: double.infinity,
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isVi ? 'Xem thêm' : 'See more',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
                    ),
                    Icon(Icons.expand_more, size: 18, color: Colors.black.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openConversation(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversation: conversation),
      ),
    );
  }

  // Handle calling from search results
  Future<void> _handleCallAction(dynamic target) async {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final chatService = context.read<ChatService>();
    
    Conversation? resolvedConv;
    String? peerUserId;
    String? peerDisplayName;
    String? peerAvatarUrl;

    try {
      if (target is Conversation) {
        resolvedConv = target;
        peerUserId = _resolvePeerUserId(currentUserId, target);
        peerDisplayName = target.getDisplayName(currentUserId);
        peerAvatarUrl = target.getDisplayAvatarUrl(currentUserId);
      } else if (target is User) {
        // Find existing or create new direct conversation
        resolvedConv = await chatService.getOrCreateDirect(target.id);
        peerUserId = target.id;
        peerDisplayName = target.displayName;
        peerAvatarUrl = target.avatarUrl;
      }

      if (resolvedConv == null || peerUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể khởi tạo cuộc gọi')),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoiceCallScreen(
              conversationId: resolvedConv!.id,
              callId: generateCallId(
                conversationId: resolvedConv!.id,
                callerUserId: currentUserId,
                audioOnly: true,
              ),
              targetUserId: peerUserId!,
              targetDisplayName: peerDisplayName ?? 'User',
              targetAvatarUrl: peerAvatarUrl,
              isCaller: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Widget _buildStrangerSection(Set<String> displayedIds) {
    if (_strangerFoundByPhone != null) {
      displayedIds.add(_strangerFoundByPhone!.id);
    }
    final user = _strangerFoundByPhone!;
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    final status = _effectiveFriendshipStatus(user);

    return Container(
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(isVi ? 'Tìm bạn qua số điện thoại' : 'Search by phone', count: '1', showEdit: false),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: AvatarWidget(imageUrl: user.avatarUrl, name: user.displayName, size: 52),
            title: Text(
              user.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
                  children: [
                    TextSpan(text: isVi ? 'Số điện thoại: ' : 'Phone: '),
                    _highlightText(
                      user.phone ?? '',
                      _queryController.text,
                      baseStyle: TextStyle(color: _primaryColor),
                    ),
                  ],
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                  onPressed: () => _handleCallAction(user),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE3F2FD),
                    shape: const CircleBorder(),
                    fixedSize: const Size(32, 32),
                  ),
                ),
                const SizedBox(width: 8),
                _isCancelling
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor))
                    : OutlinedButton(
                        onPressed: () async {
                          if (status == 'FRIEND') {
                            _handleUnfriend(user);
                          } else if (status == 'PENDING_SENT' || status == 'PENDING') {
                            _handleStrangerCancel(user);
                          } else {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SendRequestScreen(targetUser: user),
                              ),
                            );
                            if (result == true) {
                              setState(() {
                                final currentStatus = _strangerFoundByPhone?.friendshipStatus;
                                _strangerFoundByPhone = _strangerFoundByPhone?.copyWith(
                                  friendshipStatus: currentStatus == 'PENDING_SENT' ? 'NONE' : 'PENDING_SENT',
                                );
                              });
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: (status == 'PENDING_SENT' || status == 'PENDING' || status == 'FRIEND')
                              ? (isDarkMode ? DarkColors.surfaceLight : Colors.grey.shade100)
                              : (isDarkMode ? DarkColors.primary.withValues(alpha: 0.1) : const Color(0xFFE3F2FD)),
                          side: BorderSide.none,
                          foregroundColor: (status == 'PENDING_SENT' || status == 'PENDING' || status == 'FRIEND')
                              ? Colors.grey
                              : _primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(
                          status == 'FRIEND'
                              ? (isVi ? 'Bạn bè' : 'Friends')
                              : ((status == 'PENDING_SENT' || status == 'PENDING')
                                  ? (isVi ? 'Đã gửi' : 'Sent')
                                  : (isVi ? 'Kết bạn' : 'Add friend')),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(String query, Set<String> displayedIds) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    final friendMap = <String, User>{
      for (final f in _recentFriends) f.id: f,
    };

    final results = _localContactResults.where((r) => !displayedIds.contains(r.id)).toList();
    if (results.isEmpty) return const SizedBox.shrink();

    const threshold = 5;
    final showAll = _isContactsExpanded || results.length <= threshold;
    final displayList = showAll ? results : results.take(threshold).toList();

    return Container(
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(isVi ? 'Liên hệ' : 'Contacts', count: results.length.toString(), showEdit: false),
          Column(
            children: List.generate(displayList.length, (index) {
              final contact = displayList[index];
              displayedIds.add(contact.id);
              final profile = friendMap[contact.id];
              final displayName = profile?.displayName ?? contact.displayName;
              final avatarUrl = profile?.avatarUrl ?? contact.avatarUrl;
              return Column(
                children: [
                  ListTile(
                    leading: AvatarWidget(imageUrl: avatarUrl, name: displayName, size: 52),
                    title: RichText(
                      text: _highlightText(
                        displayName,
                        query,
                        baseStyle: TextStyle(
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                      onPressed: () => _handleCallAction(contact),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE3F2FD),
                        shape: const CircleBorder(),
                        fixedSize: const Size(32, 32),
                      ),
                    ),
                    onTap: () => _handleLocalContactTap(contact),
                  ),
                  if (index < displayList.length - 1)
                    Divider(height: 1, thickness: 0.5, indent: 84, color: dividerColor),
                ],
              );
            }),
          ),
          if (results.length > threshold && !_isContactsExpanded)
            GestureDetector(
              onTap: () => setState(() => _isContactsExpanded = true),
              child: Container(
                width: double.infinity,
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isVi ? 'Xem thêm' : 'See more',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
                    ),
                    Icon(Icons.expand_more, size: 18, color: Colors.black.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageSection(String query, Set<String> displayedIds) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;

    // Grouping: Group all messages by conversationId, and show only the most recent one.
    final groupedResultMap = <String, LocalMessageSearchResult>{};
    for (final result in _localMessageResults) {
      final cid = result.message.conversationId;
      if (!groupedResultMap.containsKey(cid)) {
        groupedResultMap[cid] = result;
      }
    }
    final results = groupedResultMap.values.toList();

    const threshold = 5;
    final showAll = _isMessagesExpanded || results.length <= threshold;
    final displayList = showAll ? results : results.take(threshold).toList();

    return Container(
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(isVi ? 'Tin nhắn' : 'Messages', count: results.length.toString(), showEdit: false),
          _buildFilterChips(),
          Column(
            children: List.generate(displayList.length, (index) {
              final result = displayList[index];
              return _buildMessageTile(
                result,
                query,
                index == displayList.length - 1,
              );
            }),
          ),
          if (results.length > threshold && !_isMessagesExpanded)
            GestureDetector(
              onTap: () => setState(() => _isMessagesExpanded = true),
              child: Container(
                width: double.infinity,
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isVi ? 'Xem thêm' : 'See more',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
                    ),
                    Icon(Icons.expand_more, size: 18, color: Colors.black.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(LocalMessageSearchResult result, String query, bool isLast) {
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final common = CommonTexts.of(context);
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final hydrated = _findConversation(result.message.conversationId);
    
    String displayName = hydrated?.getDisplayName(currentUserId) ?? result.conversationName ?? '';
    String? avatarUrl = hydrated?.getDisplayAvatarUrl(currentUserId) ?? result.conversationAvatar;

    final isVi = common.language == AppLanguage.vi;
    
    // Fix for Direct Chats with no name in the database
    if (displayName.isEmpty || displayName == (isVi ? 'Cuộc hội thoại' : 'Conversation')) {
      if (result.conversationType == 'DIRECT' && hydrated != null) {
        try {
          final otherMember = hydrated.members.firstWhere(
            (m) => m.userId != currentUserId,
            orElse: () => hydrated.members.first,
          );
          displayName = otherMember.nickname ?? otherMember.user?.displayName ?? displayName;
          avatarUrl ??= otherMember.user?.avatarUrl;
        } catch (_) {
          // Fallback to default name already handled below.
        }
      }
      
      if (displayName.isEmpty || displayName == 'Cuộc hội thoại') {
        displayName = (isVi ? 'Cuộc hội thoại' : 'Conversation');
      }
    }
    
    return Column(
      children: [
        ListTile(
          leading: AvatarWidget(imageUrl: avatarUrl, name: displayName, size: 52),
          title: Text(
            displayName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: _highlightText(
                CallLogMessage.tryParse(result.message.content)?.toLocalizedText(isMine: result.message.senderId == currentUserId) ?? result.message.content,
                query,
                baseStyle: TextStyle(
                  color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          trailing: Text(
            DateFormat('dd/MM/yy').format(result.message.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? DarkColors.textHint : LightColors.textHint,
            ),
          ),
          onTap: () => _handleLocalMessageTap(result.message),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 84, bottom: 8),
          child: Row(
            children: [
              Text(
                '1 ${isVi ? 'kết quả phù hợp' : 'match found'}',
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 16),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 0.5, indent: 84, color: dividerColor),
      ],
    );
  }

  Conversation? _findConversation(String conversationId) {
    final conversations = context.read<ChatProvider>().conversations;
    for (final conv in conversations) {
      if (conv.id == conversationId) return conv;
    }
    return null;
  }

  Widget _buildFilterChips() {
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    final filters = [
      {'key': 'all', 'label': isVi ? 'Tất cả' : 'All'},
      {'key': 'link', 'label': 'Link'},
      {'key': 'file', 'label': 'File'},
    ];

    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: filters.map((f) {
              final isSelected = _selectedFilterKey == f['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                  ),
                  label: Text(f['label']!),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilterKey = f['key']!);
                  },
                  selectedColor: isDarkMode ? const Color(0xFF003D80) : const Color(0xFFE3F2FD),
                  backgroundColor: isDarkMode
                      ? DarkColors.surfaceLight.withValues(alpha: 0.42)
                      : const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : (isDarkMode ? DarkColors.textSecondary : Colors.black87),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {bool showEdit = true, String? count}) {
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
              children: [
                TextSpan(text: title.toUpperCase()),
                if (count != null && count != '0') ...[
                  const TextSpan(text: ' ('),
                  TextSpan(text: count),
                  const TextSpan(text: ')'),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (showEdit)
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Text(
                isVi ? 'Chỉnh sửa' : 'Edit',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _resolvePeerUserId(String currentUserId, Conversation conv) {
    if (conv.type != ConversationType.DIRECT) return null;
    try {
      return conv.members
          .firstWhere((m) => m.userId != currentUserId,
              orElse: () => conv.members.first)
          .userId;
    } catch (_) {
      return null;
    }
  }
}
