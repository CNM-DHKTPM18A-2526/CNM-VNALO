import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/user_service.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
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
  final TextEditingController _queryController = TextEditingController();
  late final TabController _tabController;
  int _searchRequestId = 0;

  // States for search history and current query
  List<User> _recentFriends = <User>[];
  bool _loadingRecent = true;

  // New states for hybrid search
  User? _strangerFoundByPhone;
  List<LocalContact> _localContactResults = [];
  List<LocalMessage> _localMessageResults = [];
  bool _isSearching = false;

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

    // 2. Global Phone Search (if 10 digits)
    final phoneRegex = RegExp(r'^\d{10}$');
    Future<User?> phoneTask = Future.value(null);
    if (phoneRegex.hasMatch(q)) {
      phoneTask = userService.getUserByPhone(q).catchError((_) => null);
    }

    final results = await Future.wait([contactsTask, messagesTask, phoneTask]);

    if (!mounted || requestId != _searchRequestId) return;

    setState(() {
      _localContactResults = results[0] as List<LocalContact>;
      _localMessageResults = results[1] as List<LocalMessage>;
      _strangerFoundByPhone = results[2] as User?;
      _isSearching = false;
    });
  }

  // UI Helper for Highlighting
  TextSpan _highlightText(
    String text,
    String query, {
    required TextStyle baseStyle,
    Color highlightColor = const Color(0xFF0091FF),
  }) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(
          TextSpan(text: text.substring(start, indexOfMatch), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(indexOfMatch, indexOfMatch + query.length),
          style: baseStyle.copyWith(
            color: highlightColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = indexOfMatch + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return TextSpan(children: spans);
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
    final startTime = DateTime.now();
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
        debugPrint(
          '[UX] Local hit for navigation. Latency: ${DateTime.now().difference(startTime).inMilliseconds}ms',
        );
      } else {
        // 2. Fallback to API
        debugPrint('[UX] Local miss. Falling back to API...');
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
      debugPrint('[UX] Navigation failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở cuộc trò chuyện này.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim();
    final scaffoldBg =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : const Color(0xFFF4F5F7);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF0091FF), Color(0xFF007AFF)],
            ),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Color(0xFF757575),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Tìm kiếm',
                            hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
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
                            Icons.cancel,
                            color: Color(0xFF757575),
                            size: 18,
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
    return Column(
      children: [
        Container(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0091FF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0091FF),
            tabs: const [Tab(text: 'Của tôi'), Tab(text: 'Khám phá')],
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
                          style: const TextStyle(fontSize: 12),
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
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Text(
          'Không tìm thấy liên hệ hay tin nhắn phù hợp',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    return ListView(
      children: [
        if (_strangerFoundByPhone != null) _buildStrangerSection(),
        if (_localContactResults.isNotEmpty) _buildContactSection(query),
        if (_localMessageResults.isNotEmpty) _buildMessageSection(query),
      ],
    );
  }

  Widget _buildStrangerSection() {
    final user = _strangerFoundByPhone!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Tìm bạn qua số điện thoại (1)', showEdit: false),
        ListTile(
          tileColor: Colors.white,
          leading: AvatarWidget(
            imageUrl: user.avatarUrl,
            name: user.displayName,
            size: 48,
          ),
          title: Text(
            user.displayName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.grey, fontSize: 13),
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
          trailing: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE3F2FD),
              foregroundColor: const Color(0xFF0091FF),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Kết bạn',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildContactSection(String query) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Liên hệ (${_localContactResults.length})'),
        ..._localContactResults.map(
          (contact) => ListTile(
            tileColor: Colors.white,
            leading: AvatarWidget(
              imageUrl: contact.avatarUrl,
              name: contact.displayName,
              size: 48,
            ),
            title: RichText(
              text: _highlightText(
                contact.displayName,
                query,
                baseStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            trailing: const Icon(
              Icons.phone_outlined,
              color: Color(0xFF0091FF),
              size: 22,
            ),
            onTap: () => _handleLocalContactTap(contact),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageSection(String query) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Tin nhắn (${_localMessageResults.length}+)'),
        ..._localMessageResults.map(
          (msg) => ListTile(
            tileColor: Colors.white,
            leading: const AvatarWidget(
              imageUrl: null,
              name: 'Group',
              size: 48,
            ),
            title: const Text(
              'Cuộc hội thoại',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: RichText(
              text: _highlightText(
                msg.content,
                query,
                baseStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            trailing: Text(
              DateFormat('dd/MM/yy').format(msg.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            onTap: () => _handleLocalMessageTap(msg),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, {bool showEdit = true}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (showEdit)
            const Text(
              'Sửa',
              style: TextStyle(color: Color(0xFF0091FF), fontSize: 13),
            ),
        ],
      ),
    );
  }
}
