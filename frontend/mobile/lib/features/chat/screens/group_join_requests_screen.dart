import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class GroupJoinRequestsScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupJoinRequestsScreen({super.key, required this.conversation});

  @override
  State<GroupJoinRequestsScreen> createState() => _GroupJoinRequestsScreenState();
}

class _GroupJoinRequestsScreenState extends State<GroupJoinRequestsScreen> {
  bool _isLoading = true;
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await context.read<ChatProvider>().getJoinRequests(widget.conversation.id);
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: Text(
          'Yêu cầu tham gia${_requests.isNotEmpty ? " (${_requests.length})" : ""}',
          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới',
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _requests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.builder(
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final req = _requests[index];
                      return _buildRequestItem(req, isDarkMode);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.person_badge_plus,
            size: 72,
            color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Không có yêu cầu tham gia nào',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Khi có người yêu cầu vào nhóm,\nhọ sẽ hiện ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(dynamic req, bool isDarkMode) {
    // API response may include nested user object or just userId
    final Map<String, dynamic> reqMap = req is Map ? Map<String, dynamic>.from(req) : {};

    // Try to extract user info from nested 'user' object first
    final dynamic userObj = reqMap['user'];
    final String userId = reqMap['userId']?.toString() ?? reqMap['user_id']?.toString() ?? '';
    final String displayName = (userObj is Map)
        ? (userObj['displayName'] ?? userObj['display_name'] ?? userObj['fullName'] ?? 'Người dùng').toString()
        : (reqMap['displayName'] ?? reqMap['display_name'] ?? userId).toString();
    final String? avatarUrl = (userObj is Map)
        ? userObj['avatarUrl']?.toString() ?? userObj['avatar_url']?.toString()
        : reqMap['avatarUrl']?.toString();
    final String requestedAt = reqMap['requestedAt']?.toString() ??
        reqMap['requested_at']?.toString() ??
        reqMap['createdAt']?.toString() ??
        '';

    String timeLabel = '';
    if (requestedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(requestedAt).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          timeLabel = 'Vừa xong';
        } else if (diff.inHours < 1) {
          timeLabel = '${diff.inMinutes} phút trước';
        } else if (diff.inDays < 1) {
          timeLabel = '${diff.inHours} giờ trước';
        } else {
          timeLabel = '${diff.inDays} ngày trước';
        }
      } catch (_) {
        timeLabel = requestedAt;
      }
    }

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.grey.shade500;

    return Container(
      margin: const EdgeInsets.only(top: 1),
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            AvatarWidget(
              imageUrl: avatarUrl,
              name: displayName,
              size: 48,
            ),
            const SizedBox(width: 12),
            // Name + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  if (timeLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Yêu cầu $timeLabel',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ),
                ],
              ),
            ),
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reject
                TextButton(
                  onPressed: () => _rejectRequest(userId),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.red.shade300, width: 1),
                    ),
                  ),
                  child: const Text('Từ chối', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                // Approve
                ElevatedButton(
                  onPressed: () => _approveRequest(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Chấp nhận', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(String userId) async {
    if (userId.isEmpty) return;
    try {
      await context.read<ChatProvider>().approveJoinRequest(widget.conversation.id, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chấp nhận yêu cầu tham gia'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Không thể chấp nhận yêu cầu. Thử lại sau.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String userId) async {
    if (userId.isEmpty) return;
    try {
      await context.read<ChatProvider>().rejectJoinRequest(widget.conversation.id, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối yêu cầu tham gia'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Không thể từ chối yêu cầu. Thử lại sau.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }
}
