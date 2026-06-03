import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:intl/intl.dart';

class MediaViewerScreen extends StatefulWidget {
  final String conversationId;
  final String conversationName;

  const MediaViewerScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Message> _allMessages = [];
  List<Message> _images = [];
  List<Message> _files = [];
  List<Message> _links = [];
  List<Message> _voice = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: 0);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      final List<Message> allMsgs = [];

      // Load all types in parallel
      final results = await Future.wait([
        chatProvider.getSharedMedia(widget.conversationId, type: 'IMAGE'),
        chatProvider.getSharedMedia(widget.conversationId, type: 'VIDEO'),
        chatProvider.getSharedMedia(widget.conversationId, type: 'FILE'),
        chatProvider.getSharedMedia(widget.conversationId, type: 'AUDIO'),
      ]);

      // Collect all messages
      for (final list in results) {
        allMsgs.addAll(list);
      }

      // Also try getting all messages to catch links in TEXT messages
      try {
        final allFromApi = await chatProvider.getAllMediaForConversation(widget.conversationId);
        for (var msg in allFromApi) {
          if (!allMsgs.any((m) => m.id == msg.id)) {
            allMsgs.add(msg);
          }
        }
      } catch (e) {
        debugPrint('[MediaViewer] getAllMediaForConversation failed: $e');
      }

      // Sort by createdAt descending (newest first)
      allMsgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Categorize messages
      final images = <Message>[];
      final files = <Message>[];
      final links = <Message>[];
      final voice = <Message>[];

      for (final msg in allMsgs) {
        switch (msg.messageType) {
          case MessageType.IMAGE:
            images.add(msg);
            break;
          case MessageType.VIDEO:
            files.add(msg);
            break;
          case MessageType.FILE:
            files.add(msg);
            break;
          case MessageType.AUDIO:
            voice.add(msg);
            break;
          case MessageType.TEXT:
            // Check if TEXT contains URLs
            if (msg.content != null && _containsUrl(msg.content!)) {
              links.add(msg);
            }
            break;
          default:
            break;
        }
      }

      if (mounted) {
        setState(() {
          _allMessages = allMsgs;
          _images = images;
          _files = files;
          _links = links;
          _voice = voice;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MediaViewer] Error loading media: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _containsUrl(String text) {
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(text);
  }

  String _extractUrl(String text) {
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(text);
    return match?.group(0) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    final bgColor = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;
    final cardColor = isDarkMode ? DarkColors.surface : Colors.white;

    final tabLabels = [
      common.allLabel,
      common.imagesTab,
      common.filesTab,
      common.linksTab,
      common.voiceTab,
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              common.mediaAndDocs,
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.conversationName,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w400),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: cardColor,
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              labelColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
              unselectedLabelColor: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade400,
              indicatorColor: isDarkMode ? DarkColors.primary : AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              tabs: tabLabels.map((label) => Tab(text: label)).toList(),
              onTap: (index) {
                setState(() {});
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _MediaGridView(
                      messages: _allMessages,
                      conversationId: widget.conversationId,
                      emptyMessage: common.noSharedMediaNote,
                      onRefresh: _loadData,
                    ),
                    _MediaGridView(
                      messages: _images,
                      conversationId: widget.conversationId,
                      emptyMessage: common.noImagesNote,
                      onRefresh: _loadData,
                      isImagesTab: true,
                    ),
                    _MediaGridView(
                      messages: _files,
                      conversationId: widget.conversationId,
                      emptyMessage: common.noFilesNote,
                      onRefresh: _loadData,
                    ),
                    _MediaGridView(
                      messages: _links,
                      conversationId: widget.conversationId,
                      emptyMessage: common.noLinksNote,
                      onRefresh: _loadData,
                      isLinksTab: true,
                    ),
                    _MediaGridView(
                      messages: _voice,
                      conversationId: widget.conversationId,
                      emptyMessage: common.noVoiceNotesNote,
                      onRefresh: _loadData,
                      isVoiceTab: true,
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Không thể tải dữ liệu', style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white54 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(_error ?? '', style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white38 : Colors.grey.shade500), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Colors.white12 : Colors.grey.shade200,
              foregroundColor: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaGridView extends StatelessWidget {
  final List<Message> messages;
  final String conversationId;
  final String emptyMessage;
  final VoidCallback onRefresh;
  final bool isImagesTab;
  final bool isLinksTab;
  final bool isVoiceTab;

  const _MediaGridView({
    required this.messages,
    required this.conversationId,
    required this.emptyMessage,
    required this.onRefresh,
    this.isImagesTab = false,
    this.isLinksTab = false,
    this.isVoiceTab = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (messages.isEmpty) {
      return _buildEmptyState(context, isDarkMode);
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        slivers: [
          if (isImagesTab)
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ImageGridItem(
                    message: messages[index],
                    conversationId: conversationId,
                    onTap: () => _openFullScreen(context, index),
                  ),
                  childCount: messages.length,
                ),
              ),
            )
          else if (isLinksTab)
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _LinkListItem(message: messages[index], isDarkMode: isDarkMode),
                  childCount: messages.length,
                ),
              ),
            )
          else if (isVoiceTab)
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _VoiceListItem(message: messages[index], isDarkMode: isDarkMode),
                  childCount: messages.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _FileListItem(message: messages[index], isDarkMode: isDarkMode),
                  childCount: messages.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isImagesTab ? Icons.image_not_supported_outlined : (isLinksTab ? Icons.link_off : Icons.folder_open_outlined),
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(emptyMessage, style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white54 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenMediaViewer(
          messages: messages,
          initialIndex: initialIndex,
          conversationId: conversationId,
        ),
      ),
    );
  }
}

class _ImageGridItem extends StatelessWidget {
  final Message message;
  final String conversationId;
  final VoidCallback onTap;

  const _ImageGridItem({
    required this.message,
    required this.conversationId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl ?? '';
    final resolvedUrl = AvatarResolver.resolveUrl(url) ?? url;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(context, resolvedUrl, isDarkMode),
            if (message.messageType == MessageType.VIDEO)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                ),
              ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDateShort(message.createdAt),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String url, bool isDarkMode) {
    final token = context.read<AuthProvider>().accessToken;
    final headers = (token != null && AvatarResolver.isInternalUrl(url))
        ? {'Authorization': 'Bearer $token'}
        : <String, String>{};

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      httpHeaders: headers,
      placeholder: (context, url) => Container(
        color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
        child: const Center(child: CupertinoActivityIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.withValues(alpha: 0.2),
        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      ),
    );
  }

  String _formatDateShort(DateTime dateTime) {
    return DateFormat('dd/MM').format(dateTime);
  }
}

class _LinkListItem extends StatelessWidget {
  final Message message;
  final bool isDarkMode;

  const _LinkListItem({required this.message, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final url = _extractUrl(message.content ?? '');
    final displayUrl = _formatDisplayUrl(url);
    final domain = _extractDomain(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openUrl(context, url),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.link, color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayUrl,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _extractUrl(String text) {
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(text);
    return match?.group(0) ?? text;
  }

  String _formatDisplayUrl(String url) {
    var display = url.replaceFirst(RegExp(r'^https?:\/\/(www\.)?'), '');
    if (display.length > 50) {
      display = '${display.substring(0, 47)}...';
    }
    return display;
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst(RegExp(r'^www\.'), '');
    } catch (e) {
      return url;
    }
  }

  void _openUrl(BuildContext context, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link: $url'), duration: const Duration(seconds: 3)),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final Message message;
  final bool isDarkMode;

  const _FileListItem({required this.message, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final fileName = message.content ?? 'File';
    final fileSize = _formatFileSize(message.mediaSizeBytes);
    final isVideo = message.messageType == MessageType.VIDEO;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openFile(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getFileColor(message.mediaMimeType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFileIcon(message.mediaMimeType),
                    color: _getFileColor(message.mediaMimeType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isVideo) ...[
                            Icon(Icons.videocam, size: 12, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            fileSize,
                            style: TextStyle(fontSize: 12, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormatter.formatChatDate(message.createdAt),
                            style: TextStyle(fontSize: 12, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.download,
                  size: 20,
                  color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) return Icons.table_chart;
    if (mimeType.contains('zip') || mimeType.contains('archive')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String? mimeType) {
    if (mimeType == null) return Colors.blue;
    if (mimeType.startsWith('video/')) return Colors.red;
    if (mimeType.startsWith('audio/')) return Colors.purple;
    if (mimeType.contains('pdf')) return Colors.red.shade700;
    if (mimeType.contains('word') || mimeType.contains('document')) return Colors.blue.shade700;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) return Colors.green.shade700;
    return Colors.blue;
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _openFile(BuildContext context) {
    if (message.mediaUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File: ${message.content}'), duration: const Duration(seconds: 3)),
      );
    }
  }
}

class _VoiceListItem extends StatelessWidget {
  final Message message;
  final bool isDarkMode;

  const _VoiceListItem({required this.message, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playVoice(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.mic, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tin nhắn thoại',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatter.formatChatDate(message.createdAt),
                        style: TextStyle(fontSize: 12, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.purple, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _playVoice(BuildContext context) {
    if (message.mediaUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phát tin nhắn thoại: ${message.mediaUrl}'), duration: const Duration(seconds: 3)),
      );
    }
  }
}

// Full screen image viewer
class _FullScreenMediaViewer extends StatefulWidget {
  final List<Message> messages;
  final int initialIndex;
  final String conversationId;

  const _FullScreenMediaViewer({
    required this.messages,
    required this.initialIndex,
    required this.conversationId,
  });

  @override
  State<_FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<_FullScreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1}/${widget.messages.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.messages.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          final message = widget.messages[index];
          final url = message.mediaUrl ?? '';
          final resolvedUrl = AvatarResolver.resolveUrl(url) ?? url;
          final token = context.read<AuthProvider>().accessToken;
          final headers = (token != null && AvatarResolver.isInternalUrl(resolvedUrl))
              ? {'Authorization': 'Bearer $token'}
              : <String, String>{};

          return Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: resolvedUrl,
                    httpHeaders: headers,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormatter.formatChatDate(message.createdAt),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        if (message.content != null && message.content!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            message.content!,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
