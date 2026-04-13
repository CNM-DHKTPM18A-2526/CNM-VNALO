import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/contacts/screens/send_request_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
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

    final db = context.read<LocalDatabase>();
    final contactsTask = db.searchContacts(q);
    final messagesTask = db.searchMessages(q);

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
      _localContactResults = results[0] as List<LocalContact>;
      _localMessageResults = results[1] as List<LocalMessageSearchResult>;
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
    final effectiveHighlightColor = highlightColor ?? _primaryColor;
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

      LocalConversation? localConv = await db.getLocalConversationById(msg.conversationId);
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
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : LightColors.scaffold;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        forceMaterialTransparency: !isDarkMode,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
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
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 15, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: common.searchHint,
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
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
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
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
            dividerColor: isDarkMode ? DarkColors.divider : AppColors.sectionDivider,
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_mineCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
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
              style: const TextStyle(color: Colors.grey),
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
        style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : Colors.grey)
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
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                isVi 
                  ? 'Không tìm thấy liên hệ, tin nhắn\ncó chứa nội dung bạn đang tìm kiếm'
                  : 'No contacts or messages found matching your search',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        if (_strangerFoundByPhone != null) _buildStrangerSection(),
        if (_friendResults.isNotEmpty) _buildFriendSection(query),
        if (conversationMatches.isNotEmpty) _buildConversationSection(query, conversationMatches),
        if (_localContactResults.isNotEmpty) _buildContactSection(query),
        if (_localMessageResults.isNotEmpty) _buildMessageSection(query),
      ],
    );
  }

  Widget _buildFriendSection(String query) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(isVi ? 'Bạn bè (${_friendResults.length})' : 'Friends (${_friendResults.length})', showEdit: false),
        Container(
          color: surfaceColor,
          child: Column(
            children: List.generate(_friendResults.length, (index) {
              final user = _friendResults[index];
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
                    trailing: OutlinedButton(
                      onPressed: _isCancelling ? null : () => _handleUnfriend(user),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDarkMode ? DarkColors.surfaceLight : Colors.grey.shade100,
                        side: BorderSide.none,
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        isVi ? 'Bạn bè' : 'Friends',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () => _openChat(user),
                  ),
                  if (index < _friendResults.length - 1)
                    Divider(height: 1, thickness: 0.5, indent: 84, color: dividerColor),
                ],
              );
            }),
          ),
        ),
        const Divider(height: 8, thickness: 8, color: Colors.transparent),
      ],
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

  Widget _buildConversationSection(String query, List<Conversation> conversations) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          isVi ? 'Doan chat (${conversations.length})' : 'Conversations (${conversations.length})',
          showEdit: false,
        ),
        Container(
          color: surfaceColor,
          child: Column(
            children: List.generate(conversations.length, (index) {
              final conv = conversations[index];
              final displayName = conv.getDisplayName(currentUserId);
              final avatarUrl = conv.getDisplayAvatarUrl(currentUserId);
              final preview = conv.lastMessage?.content?.trim();
              final subtitle = (preview == null || preview.isEmpty)
                  ? (isVi ? 'Mo cuoc tro chuyen' : 'Open conversation')
                  : preview;

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
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(conversation: conv),
                        ),
                      );
                    },
                  ),
                  if (index < conversations.length - 1)
                    Divider(height: 1, thickness: 0.5, indent: 84, color: dividerColor),
                ],
              );
            }),
          ),
        ),
        const Divider(height: 8, thickness: 8, color: Colors.transparent),
      ],
    );
  }

  Widget _buildStrangerSection() {
    final user = _strangerFoundByPhone!;
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    final status = _effectiveFriendshipStatus(user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(isVi ? 'Tìm bạn qua số điện thoại (1)' : 'Search by phone (1)', showEdit: false),
        Container(
          color: surfaceColor,
          child: ListTile(
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
            trailing: _isCancelling
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
          ),
        ),
        const Divider(height: 8, thickness: 8, color: Colors.transparent),
      ],
    );
  }

  Widget _buildContactSection(String query) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    final friendMap = <String, User>{
      for (final f in _recentFriends) f.id: f,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(isVi ? 'Liên hệ (${_localContactResults.length})' : 'Contacts (${_localContactResults.length})', showEdit: false),
        Container(
          color: surfaceColor,
          child: Column(
            children: List.generate(_localContactResults.length, (index) {
              final contact = _localContactResults[index];
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
                    trailing: Icon(
                      Icons.phone_outlined,
                      color: _primaryColor,
                      size: 24,
                    ),
                    onTap: () => _handleLocalContactTap(contact),
                  ),
                  if (index < _localContactResults.length - 1)
                    Divider(height: 1, thickness: 0.5, indent: 84, color: dividerColor),
                ],
              );
            }),
          ),
        ),
        const Divider(height: 8, thickness: 8, color: Colors.transparent),
      ],
    );
  }

  Widget _buildMessageSection(String query) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(isVi ? 'Tin nhắn (${_localMessageResults.length})' : 'Messages (${_localMessageResults.length})', showEdit: false),
        _buildFilterChips(),
        Container(
          color: surfaceColor,
          child: Column(
            children: List.generate(_localMessageResults.length, (index) {
              final result = _localMessageResults[index];
              return _buildMessageTile(
                result,
                query,
                index == _localMessageResults.length - 1,
              );
            }),
          ),
        ),
        const Divider(height: 8, thickness: 8, color: Colors.transparent),
      ],
    );
  }

  Widget _buildMessageTile(LocalMessageSearchResult result, String query, bool isLast) {
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final common = CommonTexts.of(context);
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final hydrated = _findConversation(result.message.conversationId);
    final displayName = hydrated?.getDisplayName(currentUserId) ??
      result.conversationName ??
      (common.language == AppLanguage.vi ? 'Cuộc hội thoại' : 'Conversation');
    final avatarUrl = hydrated?.getDisplayAvatarUrl(currentUserId) ?? result.conversationAvatar;
    
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
                result.message.content,
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
      child: ColoredBox(
        color: isDarkMode ? DarkColors.surface : Colors.white,
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
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedFilterKey = f['key']!);
              },
              selectedColor: isDarkMode ? const Color(0xFF003D80) : const Color(0xFFE3F2FD),
                backgroundColor: isDarkMode
                  ? DarkColors.surfaceLight.withValues(alpha: 0.72)
                  : const Color(0xFFF1F5F9),
              labelStyle: TextStyle(
                color: isSelected
                    ? _primaryColor
                    : (isDarkMode ? DarkColors.textSecondary : Colors.grey),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? _primaryColor
                      : (isDarkMode ? DarkColors.divider : Colors.grey.shade300),
                ),
              ),
            ),
          );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {bool showEdit = true}) {
    final isVi = CommonTexts.of(context).language == AppLanguage.vi;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? DarkColors.textHint : LightColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (showEdit)
            GestureDetector(
              onTap: () {},
              child: Text(
                isVi ? 'SỬA' : 'EDIT',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
