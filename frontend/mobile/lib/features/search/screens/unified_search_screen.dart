import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

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

class _SearchResult {
  const _SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.score,
    this.conversation,
    this.user,
    this.avatarUrl,
    this.kind = 'chat',
  });

  final String id;
  final String title;
  final String subtitle;
  final int score;
  final Conversation? conversation;
  final User? user;
  final String? avatarUrl;
  final String kind;
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  late final TabController _tabController;
  final List<String> _searchHistory = <String>[];
  List<User> _friends = <User>[];
  bool _loadingFriends = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == SearchInitialTab.mine ? 0 : 1,
    );
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await context.read<FriendService>().getFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _loadingFriends = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFriends = false);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<_SearchResult> _buildResults(String query) {
    final q = query.trim();
    if (q.isEmpty) return const <_SearchResult>[];

    final currentUserId = context.read<AuthProvider?>()?.user?.id ?? '';
    final conversations = context.read<ChatProvider?>()?.conversations ?? const <Conversation>[];
    final phoneIntent = RegExp(r'\d{8,}').hasMatch(q.replaceAll(RegExp(r'\D'), ''));
    final normalizedQueryPhone = _normalizeVnPhone(q);

    int matchText(String source) {
      final raw = source.toLowerCase();
      final key = q.toLowerCase();
      if (raw == key) return 70;
      if (raw.startsWith(key)) return 50;
      if (raw.contains(key)) return 30;
      return 0;
    }

    final results = <_SearchResult>[];

    for (final c in conversations) {
      final name = c.getDisplayName(currentUserId);
      final member = c.members.where((m) => m.userId != currentUserId).isNotEmpty
          ? c.members.firstWhere((m) => m.userId != currentUserId)
          : null;
      final nickname = member?.nickname ?? '';
      final userName = member?.user?.displayName ?? '';
      final phone = member?.user?.phone;
      final phoneScore = (phoneIntent && normalizedQueryPhone != null && _phoneEquivalentMatch(phone, normalizedQueryPhone))
          ? 120
          : 0;
      final base = matchText(name) + matchText(nickname) + matchText(userName) + phoneScore;
      if (base <= 0) continue;
      final relationBoost = c.type == ConversationType.DIRECT ? 240 : 140;
      final historyBoost = _searchHistory.any((h) => h.toLowerCase() == q.toLowerCase()) ? 90 : 0;
      final sharedGroupBoost = c.type == ConversationType.GROUP ? 110 : 0;
      results.add(
        _SearchResult(
          id: 'c:${c.id}',
          title: name,
          subtitle: c.lastMessage?.content ?? 'Đoạn chat',
          score: base + relationBoost + historyBoost + sharedGroupBoost,
          conversation: c,
          avatarUrl: c.getDisplayAvatarUrl(currentUserId),
          kind: 'chat',
        ),
      );
    }

    for (final f in _friends) {
      final phoneScore = (phoneIntent && normalizedQueryPhone != null && _phoneEquivalentMatch(f.phone, normalizedQueryPhone))
          ? 160
          : 0;
      final base = matchText(f.displayName) + phoneScore;
      if (base <= 0) continue;
      final sharedGroup = conversations.any(
        (c) => c.type == ConversationType.GROUP && c.members.any((m) => m.userId == f.id),
      );
      results.add(
        _SearchResult(
          id: 'u:${f.id}',
          title: f.displayName,
          subtitle: f.phone ?? 'Liên hệ',
          score: base + 250 + (sharedGroup ? 120 : 0),
          user: f,
          avatarUrl: f.avatarUrl,
          kind: 'friend',
        ),
      );
    }

    const oa = ['VNALO Shop OA', 'VNALO Support OA'];
    final mini = _deriveUsedMiniApps().map((e) => e.$1).toList();
    for (final name in oa) {
      final base = matchText(name);
      if (base > 0) {
        results.add(
          _SearchResult(
            id: 'oa:$name',
            title: name,
            subtitle: 'Official Account',
            score: base + 60,
            kind: 'oa',
          ),
        );
      }
    }
    for (final name in mini) {
      final base = matchText(name);
      if (base > 0) {
        results.add(
          _SearchResult(
            id: 'mini:$name',
            title: name,
            subtitle: 'Mini App',
            score: base + 50,
            kind: 'mini',
          ),
        );
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  String? _normalizeVnPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;
    if (digits.startsWith('84')) return digits;
    if (digits.startsWith('0')) return '84${digits.substring(1)}';
    if (digits.length == 9 || digits.length == 10) return '84$digits';
    return digits;
  }

  bool _phoneEquivalentMatch(String? value, String normalizedQuery) {
    if (value == null || value.isEmpty) return false;
    final normalizedValue = _normalizeVnPhone(value);
    if (normalizedValue == null) return false;
    return normalizedValue == normalizedQuery ||
        normalizedValue.endsWith(normalizedQuery) ||
        normalizedQuery.endsWith(normalizedValue);
  }

  Future<void> _handleResultTap(_SearchResult item) async {
    final q = _queryController.text.trim();
    if (q.isNotEmpty && !_searchHistory.contains(q)) {
      setState(() => _searchHistory.insert(0, q));
    }

    if (item.conversation != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: item.conversation!)),
      );
      return;
    }
    if (item.user != null) {
      try {
        final chatService = context.read<ChatService?>();
        if (chatService == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa sẵn sàng mở cuộc trò chuyện ở màn này.')),
          );
          return;
        }
        final conversation = await chatService.getOrCreateDirect(item.user!.id);
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(conversation: conversation, friendUser: item.user),
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được cuộc trò chuyện.')),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã chọn ${item.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim();
    final results = _buildResults(query);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final appBarIconColor = Colors.white.withValues(alpha: 0.95);
    final surfaceColor = isDarkMode ? DarkColors.surface : Colors.white;
    final scaffoldBg = isDarkMode ? Colors.black : AppColors.sectionBackground;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back, color: isDarkMode ? DarkColors.textPrimary : Colors.white),
              ),
              Expanded(
                child: Hero(
                  tag: widget.searchTag,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: isDarkMode ? DarkColors.textHint : const Color(0xFF6B7280),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              autofocus: true,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Tìm kiếm',
                                hintStyle: TextStyle(
                                  color: Colors.white70,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                },
                icon: Icon(Icons.qr_code_scanner, color: appBarIconColor),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: surfaceColor,
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              labelColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              unselectedLabelColor: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade400,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              tabs: const [
                Tab(text: 'Của tôi'),
                Tab(text: 'Khám phá'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                query.isEmpty ? _buildMineDefault() : _buildResultList(results),
                query.isEmpty ? _buildDiscoverDefault() : _buildResultList(results),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMineDefault() {
    final usedMiniApps = _deriveUsedMiniApps();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDarkMode ? DarkColors.surface : Colors.white;

    return ListView(
      children: [
        Container(
          color: surfaceColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Mini App đã sử dụng'),
              if (usedMiniApps.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Text(
                    'Chưa có dữ liệu mini app đã sử dụng',
                    style: TextStyle(color: LightColors.textSecondary),
                  ),
                )
              else
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                    itemCount: usedMiniApps.length,
                    itemBuilder: (context, index) {
                      final item = usedMiniApps[index];
                      return _MiniAppItem(label: item.$1, icon: item.$2);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          color: surfaceColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Liên hệ đã tìm'),
              if (_loadingFriends)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SizedBox(
                  height: 108,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                    itemCount: _friends.length > 7 ? 7 : _friends.length,
                    itemBuilder: (context, index) {
                      final user = _friends[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            AvatarWidget(imageUrl: user.avatarUrl, name: user.displayName, size: 50),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 72,
                              child: Text(
                                user.displayName,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white : LightColors.textPrimary,
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Quản lý lịch sử tìm kiếm',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : LightColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: isDarkMode ? DarkColors.textHint : LightColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverDefault() {
    const discoverItems = [
      ('VNALO Shop', 'Mua sắm trực tuyến', Icons.storefront_outlined),
      ('Mini App', 'Khám phá ứng dụng', Icons.apps_outlined),
      ('Official Account', 'Theo dõi OA', Icons.campaign_outlined),
      ('Tin tức', 'Nội dung thịnh hành', Icons.newspaper_outlined),
    ];
    return ListView.separated(
      itemCount: discoverItems.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.itemDivider),
      itemBuilder: (_, index) {
        final item = discoverItems[index];
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final surfaceColor = isDarkMode ? DarkColors.surface : Colors.white;
        return ListTile(
          tileColor: surfaceColor,
          leading: Icon(item.$3, color: AppColors.primary),
          title: Text(
            item.$1,
            style: TextStyle(color: isDarkMode ? Colors.white : LightColors.textPrimary),
          ),
          subtitle: Text(
            item.$2,
            style: TextStyle(color: isDarkMode ? Colors.white70 : LightColors.textSecondary),
          ),
          trailing: const Icon(Icons.chevron_right, color: LightColors.textHint),
        );
      },
    );
  }

  Widget _buildResultList(List<_SearchResult> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy kết quả phù hợp', style: TextStyle(color: LightColors.textSecondary)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76, color: AppColors.itemDivider),
      itemBuilder: (_, index) {
        final item = items[index];
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final surfaceColor = isDarkMode ? DarkColors.surface : Colors.white;
        return ListTile(
          tileColor: surfaceColor,
          leading: item.kind == 'chat' || item.kind == 'friend'
              ? AvatarWidget(imageUrl: item.avatarUrl, name: item.title, size: 44)
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.kind == 'oa' ? Icons.campaign_outlined : Icons.widgets_outlined,
                    color: AppColors.primary,
                  ),
                ),
          title: Text(
            item.title,
            style: TextStyle(color: isDarkMode ? Colors.white : LightColors.textPrimary),
          ),
          subtitle: Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isDarkMode ? Colors.white70 : LightColors.textSecondary),
          ),
          trailing: const Icon(Icons.chevron_right, color: LightColors.textHint),
          onTap: () => _handleResultTap(item),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDarkMode ? DarkColors.surface : Colors.white;
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : LightColors.textPrimary,
            ),
          ),
          const Spacer(),
          const Text(
            'Sửa',
            style: TextStyle(color: AppColors.primary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<(String, IconData)> _deriveUsedMiniApps() {
    final set = <String>{};
    for (final h in _searchHistory) {
      final lower = h.toLowerCase();
      if (lower.contains('zalopay')) set.add('Zalopay');
      if (lower.contains('document')) set.add('My Documents');
      if (lower.contains('lịch') || lower.contains('lich')) set.add('Lịch Zalo');
      if (lower.contains('nạp') || lower.contains('nap')) set.add('Nạp điện thoại');
    }

    return set.map((name) {
      if (name == 'Zalopay') return (name, Icons.account_balance_wallet_outlined);
      if (name == 'Lịch Zalo') return (name, Icons.calendar_month_outlined);
      if (name == 'Nạp điện thoại') return (name, Icons.sim_card_outlined);
      return (name, Icons.folder_outlined);
    }).toList();
  }
}

class _MiniAppItem extends StatelessWidget {
  const _MiniAppItem({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
