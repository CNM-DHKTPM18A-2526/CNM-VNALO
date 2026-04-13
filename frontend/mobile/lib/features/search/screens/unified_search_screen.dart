import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/contacts/screens/send_request_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/user_service.dart';
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
  final TextEditingController _queryController = TextEditingController();
  late final TabController _tabController;
  int _searchRequestId = 0;

  // States for search history and current query
  List<User> _recentFriends = <User>[];
  bool _loadingRecent = true;

  // New states for hybrid search
  User? _strangerFoundByPhone;
  List<LocalContact> _localContactResults = [];
  List<LocalMessageSearchResult> _localMessageResults = [];
  bool _isSearching = false;
  bool _isCancelling = false;
  String _selectedFilter = 'Tất cả'; // 'Tất cả', 'Link', 'File'

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
        _localContactResults = [];
        _localMessageResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    final db = context.read<LocalDatabase>();
    final userService = context.read<UserService>();

    // 1. Local Search (Contacts & Messages)
    final contactsTask = db.searchContacts(q);
    final messagesTask = db.searchMessages(q);

    // 2. Global Phone Search (flexible: 9-15 digits, opt leading '+')
    final phoneRegex = RegExp(r'^\+?[0-9]{9,15}$');
    Future<User?> phoneTask = Future.value(null);
    if (phoneRegex.hasMatch(q)) {
      phoneTask = userService.getUserByPhone(q).catchError((e) {
        return null;
      });
    }

    final results = await Future.wait([contactsTask, messagesTask, phoneTask]);

    if (!mounted || requestId != _searchRequestId) return;

    setState(() {
      _localContactResults = results[0] as List<LocalContact>;
      _localMessageResults = results[1] as List<LocalMessageSearchResult>;
      _strangerFoundByPhone = results[2] as User?;
      _isSearching = false;
    });

    // Fast check for friendship status if stranger found
    if (_strangerFoundByPhone != null && 
        _strangerFoundByPhone!.friendshipStatus?.toUpperCase() != 'PENDING_SENT') {
      _verifyStrangerStatus(_strangerFoundByPhone!.id, requestId);
    }
  }

  Future<void> _verifyStrangerStatus(String userId, int requestId) async {
    final isSent = await context.read<FriendService>().checkSentRequest(userId);
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

  // UI Helper for Highlighting
  TextSpan _highlightText(
    String text,
    String query, {
    required TextStyle baseStyle,
    Color highlightColor = const Color(0xFF0091FF),
  }) {
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
            color: highlightColor,
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
        const SnackBar(content: Text('Không mở được cuộc trò chuyện.')),
      );
    }
  }

  Future<void> _handleLocalMessageTap(LocalMessage msg) async {
    try {
      final db = context.read<LocalDatabase>();
      final chatService = context.read<ChatService>();

      // 1. Local Lookup First
      LocalConversation? localConv = await db.getLocalConversationById(
        msg.conversationId,
      );

      Conversation? conv;
      if (localConv != null) {
        // Map local model to UI model
        conv = Conversation.fromLocal(localConv);
      } else {
        // 2. Fallback to API
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
          throw StateError('Conversation not found: ${msg.conversationId}');
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
        const SnackBar(content: Text('Không thể mở cuộc trò chuyện này.')),
      );
    }
  }

  Future<void> _handleStrangerCancel(User user) async {
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
        SnackBar(content: Text('Đã hủy lời mời đến ${user.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể hủy lời mời: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim();
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : LightColors.scaffold;
    final isSearching = query.isNotEmpty;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm',
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
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
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

  Widget _buildMineTab() {
    return ListView(
      children: [
        _sectionHeader('Liên hệ vừa tìm'),
        if (_loadingRecent)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_recentFriends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Chưa có lịch sử tìm kiếm',
              style: TextStyle(color: Colors.grey),
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
                      AvatarWidget(
                        imageUrl: friend.avatarUrl,
                        name: friend.displayName,
                        size: 52,
                      ),
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
    return const Center(child: Text('Khám phá các tính năng mới trên Vnalo'));
  }

  Widget _buildResultList(String query) {
    if (_strangerFoundByPhone == null &&
        _localContactResults.isEmpty &&
        _localMessageResults.isEmpty) {
      if (_isSearching) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy liên hệ, tin nhắn\ncó chứa nội dung bạn đang tìm kiếm',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF757575), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.transparent, // Đã có scaffoldBg bao bọc
      child: ListView(
        children: [
          if (_strangerFoundByPhone != null) _buildStrangerSection(),
          if (_localContactResults.isNotEmpty) _buildContactSection(query),
          if (_localMessageResults.isNotEmpty) _buildMessageSection(query),
        ],
      ),
    );
  }

  Widget _buildStrangerSection() {
    final user = _strangerFoundByPhone!;
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Tìm bạn qua số điện thoại (1)', showEdit: false),
        Container(
          color: surfaceColor,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: AvatarWidget(
              imageUrl: user.avatarUrl,
              name: user.displayName,
              size: 52,
            ),
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
                    const TextSpan(text: 'Số điện thoại: '),
                    _highlightText(
                      user.phone ?? '',
                      _queryController.text,
                      baseStyle: const TextStyle(color: Color(0xFF0091FF)),
                    ),
                  ],
                ),
              ),
            ),
            trailing: _isCancelling
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0091FF)),
                  )
                : OutlinedButton(
                    onPressed: () async {
                      if (user.friendshipStatus == 'PENDING_SENT') {
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
                      backgroundColor: user.friendshipStatus == 'PENDING_SENT'
                          ? Colors.grey.shade100
                          : const Color(0xFFE3F2FD),
                      side: BorderSide.none,
                      foregroundColor: user.friendshipStatus == 'PENDING_SENT'
                          ? Colors.grey
                          : const Color(0xFF0091FF),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      (_strangerFoundByPhone?.friendshipStatus?.toUpperCase() == 'PENDING_SENT' || 
                       _strangerFoundByPhone?.friendshipStatus?.toUpperCase() == 'PENDING') 
                          ? 'Đã gửi' 
                          : 'Kết bạn',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Liên hệ (${_localContactResults.length})', showEdit: false),
        Container(
          color: surfaceColor,
          child: Column(
            children: List.generate(_localContactResults.length, (index) {
              final contact = _localContactResults[index];
              return Column(
                children: [
                  ListTile(
                    leading: AvatarWidget(
                      imageUrl: contact.avatarUrl,
                      name: contact.displayName,
                      size: 52,
                    ),
                    title: RichText(
                      text: _highlightText(
                        contact.displayName,
                        query,
                        baseStyle: TextStyle(
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.phone_outlined,
                      color: Color(0xFF0091FF),
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

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['Tất cả', 'Link', 'File'].map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = filter);
              },
              selectedColor: isDarkMode ? const Color(0xFF003D80) : const Color(0xFFE3F2FD),
              backgroundColor: isDarkMode ? DarkColors.surfaceLight : Colors.white,
              labelStyle: TextStyle(
                color: isSelected 
                    ? (isDarkMode ? Colors.lightBlueAccent : const Color(0xFF0091FF))
                    : (isDarkMode ? DarkColors.textSecondary : Colors.grey),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected 
                      ? (isDarkMode ? Colors.lightBlueAccent : const Color(0xFF0091FF))
                      : (isDarkMode ? DarkColors.divider : Colors.grey.shade300),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageSection(String query) {
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Tin nhắn (${_localMessageResults.length})', showEdit: false),
        _buildFilterChips(),
        Container(
          color: surfaceColor,
          child: Column(
            children: List.generate(_localMessageResults.length, (index) {
              final result = _localMessageResults[index];
              return Column(
                children: [
                  ListTile(
                    leading: AvatarWidget(
                      imageUrl: result.conversationAvatar,
                      name: result.conversationName ?? 'Group',
                      size: 52,
                    ),
                    title: Text(
                      result.conversationName ?? 'Cuộc hội thoại',
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
                          result.message.content ?? '',
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
                  if (index < _localMessageResults.length - 1)
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

  Widget _sectionHeader(String title, {bool showEdit = true}) {
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
              onTap: () {}, // TODO: Implement edit
              child: const Text(
                'SỬA',
                style: TextStyle(
                  color: Color(0xFF0091FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultView() {
    return Column(
      children: [
        Container(
          color: isDarkMode ? DarkColors.surface : LightColors.surface,
          child: TabBar(
            controller: _tabController,
            dividerColor: isDarkMode ? DarkColors.divider : AppColors.sectionDivider,
            labelColor: const Color(0xFF0091FF),
            unselectedLabelColor: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
            indicatorColor: const Color(0xFF0091FF),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Của tôi'),
                    if (_mineCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0091FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_mineCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0091FF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(text: 'Khám phá'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildMineTab(), _buildDiscoverTab()],
          ),
        ),
      ],
    );
  }
}
