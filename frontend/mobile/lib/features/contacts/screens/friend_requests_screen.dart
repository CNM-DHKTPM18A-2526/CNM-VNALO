import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/contacts/screens/friend_options_screen.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/chat_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _sent = [];
  bool _loadingIncoming = true;
  bool _loadingSent = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadIncoming(), _loadSent()]);
  }

  Future<void> _loadIncoming() async {
    final fs = context.read<FriendService>();
    try {
      final res = await fs.getIncomingRequests();
      if (mounted) setState(() { _incoming = res; _loadingIncoming = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingIncoming = false);
    }
  }

  Future<void> _loadSent() async {
    final fs = context.read<FriendService>();
    try {
      final res = await fs.getSentRequests();
      if (mounted) setState(() { _sent = res; _loadingSent = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSent = false);
    }
  }

  Future<void> _accept(Map<String, dynamic> request) async {
    final id = request['id']?.toString() ?? '';
    final common = CommonTexts.of(context, listen: false);
    if (id.isEmpty) return;
    try {
      await context.read<FriendService>().acceptRequest(id);
      if (!context.mounted) return;
      setState(() => _incoming.removeWhere((r) => r['id']?.toString() == id));

      // Create direct conversation with the new friend
      final friendUserId = request['fromUserId']?.toString() ?? '';
      Conversation? conversation;
      if (friendUserId.isNotEmpty) {
        try {
          conversation = await context.read<ChatService>().getOrCreateDirect(friendUserId);
          // Refresh inbox so the new friend appears in the messages tab
          if (context.mounted) {
            context.read<ChatProvider>().loadInbox();
          }
        } catch (_) {
          // Conversation creation may fail, continue to options screen
        }
      }
      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FriendOptionsScreen(
            friendName: request['fromUserDisplayName'] ?? common.friends,
            friendAvatarUrl: request['fromUserAvatarUrl'],
            friendUserId: friendUserId,
            conversation: conversation,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${common.errorOccurred}: ${e.message}')),
      );
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final id = request['id']?.toString() ?? '';
    final common = CommonTexts.of(context, listen: false);
    if (id.isEmpty) return;
    try {
      await context.read<FriendService>().rejectRequest(id);
      if (!context.mounted) return;
      setState(() => _incoming.removeWhere((r) => r['id']?.toString() == id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(common.requestRejected)),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${common.errorOccurred}: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg,
          title: Text(common.friendRequests, style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
          ],
          bottom: TabBar(
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            tabs: [
              Tab(text: '${common.receivedTab}  ${_incoming.length}'),
              Tab(text: common.sentTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildIncomingTab(isDarkMode),
            _buildSentTab(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingTab(bool isDarkMode) {
    final common = CommonTexts.of(context);
    if (_loadingIncoming) return const Center(child: CircularProgressIndicator());
    if (_incoming.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(common.noFriendRequests, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadIncoming,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(common.olderHeader, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          ..._incoming.map((req) => _buildIncomingItem(req, isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildIncomingItem(Map<String, dynamic> req, bool isDarkMode) {
    final common = CommonTexts.of(context);
    final name = req['fromUserDisplayName'] ?? common.unknownUser;
    final avatar = req['fromUserAvatarUrl'] as String?;
    final message = req['message'] as String? ?? common.friendRequestSubtitle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarWidget(imageUrl: avatar, name: name, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reject(req),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(common.rejectAction, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _accept(req),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDarkMode ? DarkColors.primary : AppColors.primary,
                          side: BorderSide(color: isDarkMode ? DarkColors.primary : AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(common.acceptAction, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentTab(bool isDarkMode) {
    final common = CommonTexts.of(context);
    if (_loadingSent) return const Center(child: CircularProgressIndicator());
    if (_sent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.send_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(common.noSentRequests, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSent,
      child: ListView.builder(
        itemCount: _sent.length,
        itemBuilder: (context, index) {
          final req = _sent[index];
          final name = req['toUserDisplayName'] ?? common.unknownUser;
          final avatar = req['toUserAvatarUrl'] as String?;

          return ListTile(
            leading: AvatarWidget(imageUrl: avatar, name: name, size: 48),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              common.waitingResponse,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            trailing: TextButton(
              onPressed: () async {
                final id = req['id']?.toString() ?? '';
                if (id.isEmpty) return;
                try {
                  await context.read<FriendService>().cancelRequest(id);
                  if (!context.mounted) return;
                  setState(() => _sent.removeWhere((r) => r['id']?.toString() == id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(common.requestCancelled)),
                  );
                } catch (e) {
                if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${common.errorOccurred}: $e')),
                  );
                }
              },
              child: Text(common.cancelAction, style: const TextStyle(color: Colors.redAccent)),
            ),
          );
        },
      ),
    );
  }
}
