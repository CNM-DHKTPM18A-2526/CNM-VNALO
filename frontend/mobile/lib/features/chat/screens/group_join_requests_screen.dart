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
    final requests = await context.read<ChatProvider>().getJoinRequests(widget.conversation.id);
    if (mounted) {
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Yêu cầu tham gia', 
          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDarkMode ? null : AppColors.appBarGradient,
            color: isDarkMode ? DarkColors.appBarBg : null,
          ),
        ),
      ),
      body: _isLoading
        ? const Center(child: CupertinoActivityIndicator())
        : _requests.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                // Note: req contains conversationId, userId, requestedAt, etc.
                // We might need to fetch user profiles for these IDs if they aren't included.
                return _buildRequestItem(req);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.person_badge_plus, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Không có yêu cầu nào', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildRequestItem(dynamic req) {
    final String userId = req['userId'] ?? '';
    final String requestedAt = req['requestedAt'] ?? '';
    // For now, assuming we might need to resolve the user info.
    // In a real app, the API should return the user object.
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
           const AvatarWidget(name: '?', size: 48), // Placeholder if profile not returned
           const SizedBox(width: 12),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('ID: $userId', style: const TextStyle(fontWeight: FontWeight.bold)),
                 Text('Yêu cầu lúc: $requestedAt', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
               ],
             ),
           ),
           Row(
             children: [
               IconButton(
                 icon: const Icon(Icons.check_circle, color: Colors.green),
                 onPressed: () => _approveRequest(userId),
               ),
               IconButton(
                 icon: const Icon(Icons.cancel, color: Colors.red),
                 onPressed: () => _rejectRequest(userId),
               ),
             ],
           ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(String userId) async {
    await context.read<ChatProvider>().approveJoinRequest(widget.conversation.id, userId);
    _loadRequests();
  }

  Future<void> _rejectRequest(String userId) async {
    await context.read<ChatProvider>().rejectJoinRequest(widget.conversation.id, userId);
    _loadRequests();
  }
}
