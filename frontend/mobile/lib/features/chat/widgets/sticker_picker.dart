import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StickerPicker extends StatefulWidget {
  final String conversationId;
  final VoidCallback onSelected;

  const StickerPicker({
    super.key,
    required this.conversationId,
    required this.onSelected,
  });

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  List<Map<String, dynamic>> _packs = [];
  List<Map<String, dynamic>> _stickers = [];
  String? _selectedPackId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    setState(() => _isLoading = true);
    try {
      final mediaService = context.read<MediaService>();
      final packs = await mediaService.getStickerPacks();
      setState(() {
        _packs = packs;
        if (packs.isNotEmpty) {
          _selectedPackId = packs.first['stickerPackId'] ?? packs.first['id'];
          _loadStickers(_selectedPackId!);
        }
      });
    } catch (e) {
      debugPrint('Error loading sticker packs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStickers(String packId) async {
    setState(() => _isLoading = true);
    try {
      final mediaService = context.read<MediaService>();
      final stickers = await mediaService.getStickersInPack(packId);
      setState(() {
        _stickers = stickers;
      });
    } catch (e) {
      debugPrint('Error loading stickers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // Pack Selector
          if (_packs.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _packs.length,
                itemBuilder: (context, index) {
                  final pack = _packs[index];
                  final id = pack['stickerPackId'] ?? pack['id'];
                  final isSelected = id == _selectedPackId;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedPackId = id);
                      _loadStickers(id);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? Colors.blue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          pack['name'] ?? 'Pack ${index + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.blue : Colors.grey,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Sticker Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _stickers.isEmpty
                    ? const Center(child: Text('Không có sticker nào'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: _stickers.length,
                        itemBuilder: (context, index) {
                          final sticker = _stickers[index];
                          final id = sticker['stickerId'] ?? sticker['id'];
                          // We expect the backend to return a full URL or we construct it
                          final url = sticker['url'] ?? ''; 

                          return GestureDetector(
                            onTap: () {
                              context.read<ChatProvider>().sendSticker(
                                conversationId: widget.conversationId,
                                stickerId: id.toString(),
                                stickerUrl: url,
                              );
                              widget.onSelected();
                            },
                            child: CachedNetworkImage(
                              imageUrl: url,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade200,
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
