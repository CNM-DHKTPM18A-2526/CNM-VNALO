import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/services/gif_service.dart';

class StickerPicker extends StatefulWidget {
  final String conversationId;
  final VoidCallback onSelected;
  final Function(String) onEmojiSelected;

  const StickerPicker({
    super.key,
    required this.conversationId,
    required this.onSelected,
    required this.onEmojiSelected,
  });

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  List<Map<String, dynamic>> _myPacks = [];
  List<Map<String, dynamic>> _recentStickers = [];
  final Map<String, List<Map<String, dynamic>>> _stickersCache = {};
  bool _isLoadingRecent = false;
  List<String> _recentEmojis = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load packs, recent stickers, and emoji history in one pass.
    if (!mounted) return;
    await Future.wait([
      _loadMyPacks(),
      _loadRecentStickers(),
      _loadRecentEmojis(),
    ]);
  }

  Future<void> _loadMyPacks() async {
    // Fetch purchased packs, then prefetch stickers per pack.
    if (!mounted) return;
    try {
      final mediaService = context.read<MediaService>();
      final packs = await mediaService.getMyPacks();
      if (mounted) {
        setState(() { _myPacks = packs; });
        for (var pack in packs) {
          final id = pack['stickerPackId'] ?? pack['id'];
          _loadStickersForPack(id.toString());
        }
      }
    } catch (e) {
      debugPrint('Error loading sticker packs: $e');
    }
  }

  Future<void> _loadRecentStickers() async {
    if (!mounted) return;
    setState(() => _isLoadingRecent = true);
    try {
      final mediaService = context.read<MediaService>();
      final recent = await mediaService.getRecentStickers();
      if (mounted) setState(() => _recentStickers = recent);
    } catch (e) {
      debugPrint('Error loading recent stickers: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRecent = false);
    }
  }

  Future<void> _loadStickersForPack(String packId) async {
    // Cache sticker lists by pack id to keep tab switching snappy.
    try {
      final mediaService = context.read<MediaService>();
      final stickers = await mediaService.getStickersInPack(packId);
      if (mounted) {
        setState(() { _stickersCache[packId] = stickers; });
      }
    } catch (e) {
      debugPrint('Error loading stickers for pack $packId: $e');
    }
  }

  Future<void> _loadRecentEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _recentEmojis = prefs.getStringList('recent_emojis') ?? ['😂', '😍', '😭', '👍', '🙏', '🔥', '🥰'];
      });
    }
  }

  Future<void> _saveUsedEmoji(String emoji) async {
    if (emoji == '\b' || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentEmojis.remove(emoji);
      _recentEmojis.insert(0, emoji);
      if (_recentEmojis.length > 21) _recentEmojis = _recentEmojis.sublist(0, 21);
    });
    await prefs.setStringList('recent_emojis', _recentEmojis);
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    int tabCount = 4 + _myPacks.length;

    return Container(
      height: 350,
      key: ValueKey('sticker_picker_${_myPacks.length}'),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        border: Border(top: BorderSide(color: isDarkMode ? DarkColors.divider : Colors.grey.shade300)),
      ),
      child: DefaultTabController(
        length: tabCount,
        initialIndex: 3,
        child: Column(
          children: [
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.surface : Colors.white,
                border: Border(bottom: BorderSide(color: isDarkMode ? DarkColors.divider : Colors.grey.shade100)),
              ),
              child: TabBar(
                isScrollable: true,
                indicator: BoxDecoration(
                  color: isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                tabs: [
                  _buildTabItem(Icons.gif_box, false, isDarkMode, "GIF"),
                  _buildTabItem(Icons.emoji_emotions, true, isDarkMode, ""),
                  _buildTabItem(Icons.sticky_note_2, true, isDarkMode, ""),
                  _buildTabItem(Icons.access_time_filled, false, isDarkMode, ""),
                  ..._myPacks.map((pack) {
                    final url = pack['coverUrl'] ?? pack['thumbnailUrl'] ?? '';
                    return _buildPackTabItem(url, isDarkMode);
                  }),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _GifTabContent(conversationId: widget.conversationId, onSelected: widget.onSelected),
                  _buildEmojiTab(isDarkMode),
                  _TrendingTabContent(onShowStore: () => _showStickerStore(context), buildSmartImage: _buildSmartImage),
                  _buildRecentTab(),
                  ..._myPacks.map((pack) {
                    final id = pack['stickerPackId'] ?? pack['id'];
                    return _buildStickerGrid(id.toString(), pack['name'] ?? 'Sticker Pack');
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, bool colored, bool isDarkMode, String label) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: colored
                  ? Colors.orange
                  : (isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary)
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPackTabItem(String url, bool isDarkMode) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(width: 30, height: 30, child: _buildSmartImage(url, isDarkMode)),
        ),
      ),
    );
  }

  Widget _buildSmartImage(String url, bool isDarkMode) {
    // Reuse a resilient thumbnail loader with placeholder/error fallback.
    if (url.isEmpty) return Icon(Icons.style, size: 24, color: isDarkMode ? DarkColors.textHint : Colors.black38);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: Colors.grey.withValues(alpha: 0.1)),
      errorWidget: (context, error, stackTrace) => Icon(Icons.style, size: 24, color: isDarkMode ? DarkColors.textHint : Colors.black38),
    );
  }

  Widget _buildRecentTab() {
    final common = CommonTexts.of(context);
    
    if (_isLoadingRecent) return const Center(child: CircularProgressIndicator());
    if (_recentStickers.isEmpty) {
      return Center(
        child: Text(
          common.noRecentStickersLabel,
          style: const TextStyle(color: Colors.grey, fontSize: 13)
        )
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: _recentStickers.length,
      itemBuilder: (context, index) => _stickerItem(_recentStickers[index]),
    );
  }

  Widget _buildEmojiTab(bool isDarkMode) {
    final common = CommonTexts.of(context);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            if (_recentEmojis.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(common.recentEmojiLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _emojiItem(_recentEmojis[index]),
                    childCount: _recentEmojis.length.clamp(0, 14),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(common.commonEmojiLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final List<String> emojis = [
                      '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚',
                      '😋','😛','😜','😝','🤪','🤨','🧐','🤓','😎','🤩','🥳','😏','😒','😞','😔','😟','😕','🙁','☹️','😣',
                      '😖','😫','😩','🥺','😢','😭','😤','😠','😡','🤬','🤯','😳','🥵','🥶','😱','😨','😰','😥','😓','🤗',
                      '🤔','🤭','🤫','🤥','😶','😐','😑','😬','🙄','😯','😦','😧','😮','😲','🥱','😴','🤤','😪','😵','🤐'
                    ];
                    if (index >= emojis.length) return null;
                    return _emojiItem(emojis[index]);
                  },
                  childCount: 80,
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16, bottom: 16,
          child: Material(
            elevation: 4, borderRadius: BorderRadius.circular(24),
            color: isDarkMode ? DarkColors.surfaceLight : Colors.white,
            child: InkWell(
              onTap: () => widget.onEmojiSelected('\b'),
              borderRadius: BorderRadius.circular(24),
              child: Container(padding: const EdgeInsets.all(12), child: Icon(Icons.backspace_outlined, size: 24, color: isDarkMode ? DarkColors.textSecondary : Colors.black54)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emojiItem(String emoji) {
    return GestureDetector(
      onTap: () { _saveUsedEmoji(emoji); widget.onEmojiSelected(emoji); },
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
    );
  }

  Widget _buildStickerGrid(String packId, String packName) {
    final stickers = _stickersCache[packId];
    if (stickers == null) return const Center(child: CircularProgressIndicator());
    final common = CommonTexts.of(context);
    if (stickers.isEmpty) {
        return Center(child: Text(common.stickerPackEmptyNote, style: const TextStyle(color: Colors.grey, fontSize: 13)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(packName.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
            itemCount: stickers.length,
            itemBuilder: (context, index) => _stickerItem(stickers[index]),
          ),
        ),
      ],
    );
  }

  Widget _stickerItem(Map<String, dynamic> sticker) {
    final id = sticker['stickerId'] ?? sticker['id'];
    final url = sticker['url'] ?? sticker['mediaUrl'] ?? '';
    return GestureDetector(
      onTap: () {
        context.read<MediaService>().recordStickerUsage(id.toString());
        context.read<ChatProvider>().sendSticker(conversationId: widget.conversationId, stickerId: id.toString(), stickerUrl: url);
        widget.onSelected();
        _loadRecentStickers();
      },
      child: _buildSmartImage(url, Theme.of(context).brightness == Brightness.dark),
    );
  }

  void _showStickerStore(BuildContext context) async {
    final mediaService = context.read<MediaService>();
    final common = CommonTexts.of(context, listen: false);
    
    final allPacks = await mediaService.getStickerPacks();
    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
          color: isDarkMode ? DarkColors.surface : LightColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.divider : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)
              )
            ),
            Text(common.stickerStoreTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              )
            ),
            Divider(color: isDarkMode ? DarkColors.divider : Colors.grey.shade200),
            Expanded(
              child: ListView.separated(
                itemCount: allPacks.length,
                separatorBuilder: (context, index) => Divider(
                  indent: 70,
                  color: isDarkMode ? DarkColors.divider : Colors.grey.shade100,
                ),
                itemBuilder: (context, index) {
                  final pack = allPacks[index];
                  final id = pack['stickerPackId'] ?? pack['id'];
                  final isInstalled = _myPacks.any((p) => (p['stickerPackId'] ?? p['id']).toString() == id.toString());
                  return ListTile(
                    leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: pack['coverUrl'] ?? pack['thumbnailUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover)),
                    title: Text(pack['name'] ?? '',
                      style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary)
                    ),
                    trailing: isInstalled ? const Icon(Icons.check_circle, color: Colors.green) : ElevatedButton(
                      onPressed: () async {
                        await mediaService.installPack(id.toString());
                        _loadMyPacks();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? DarkColors.primary : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(common.downloadStickerAction),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _GifTabContent extends StatefulWidget {
  final String conversationId;
  final VoidCallback onSelected;
  const _GifTabContent({required this.conversationId, required this.onSelected});
  @override
  State<_GifTabContent> createState() => _GifTabContentState();
}

class _GifTabContentState extends State<_GifTabContent> {
  List<Map<String, dynamic>> _gifs = [];
  bool _isLoading = false;
  final TextEditingController _gifController = TextEditingController();

  @override
  void initState() { super.initState(); _loadTrending(); }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    final gifs = await GifService(context.read<MediaService>()).getTrendingGifs();
    if (mounted) setState(() { _gifs = gifs; _isLoading = false; });
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    final gifs = await GifService(context.read<MediaService>()).searchGifs(query);
    if (mounted) setState(() { _gifs = gifs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _gifController, onSubmitted: _search,
            decoration: InputDecoration(
              hintText: common.searchGifsHint,
              prefixIcon: Icon(Icons.search, color: isDarkMode ? DarkColors.textHint : Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
            ),
          ),
        ),
        Expanded(
          child: _isLoading ? const Center(child: CircularProgressIndicator()) : GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.5),
            itemCount: _gifs.length,
            itemBuilder: (context, index) {
              final gif = _gifs[index];
              return GestureDetector(
                onTap: () {
                  context.read<ChatProvider>().sendGif(conversationId: widget.conversationId, gifUrl: gif['url']);
                  widget.onSelected();
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: gif['url'], fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey.withValues(alpha: 0.1))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendingTabContent extends StatelessWidget {
  final VoidCallback onShowStore;
  final Widget Function(String, bool) buildSmartImage;
  const _TrendingTabContent({required this.onShowStore, required this.buildSmartImage});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.local_fire_department, size: 48, color: Colors.orange.shade400),
        const SizedBox(height: 12),
        Text(common.featureUnderDevelopment, style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onShowStore,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? DarkColors.primary : AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(common.stickerStoreTitle),
        )
      ],
    );
  }
}
