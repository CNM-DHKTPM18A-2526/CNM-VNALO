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
import 'package:vnalo_mobile/features/contacts/providers/contact_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _sent = [];
  bool _loadingSent = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<ContactProvider>().fetchIncomingRequests(),
      _loadSent()
    ]);
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
      
      // Update global provider
      context.read<ContactProvider>().onFriendshipUpdated();
      
      // Create direct conversation with the new friend
      final friendUserId = request['fromUserId']?.toString() ?? '';
      Conversation? conversation;
      if (friendUserId.isNotEmpty) {
        try {
          conversation = await context.read<ChatService>().getOrCreateDirect(friendUserId);
          if (context.mounted) {
            context.read<ChatProvider>().loadInbox();
          }
        } catch (_) {
          // Conversation creation is non-critical; user can open chat later.
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
      
      // Update global provider
      context.read<ContactProvider>().fetchIncomingRequests();

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
    final contactProvider = context.watch<ContactProvider>();
    final incoming = contactProvider.incomingRequestsRaw;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        forceMaterialTransparency: !isDarkMode,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode 
          ? null 
          : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
        title: Text(
          common.friendRequests, 
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600
          )
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white), 
            onPressed: () {}
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              labelColor: isDarkMode ? DarkColors.primary : AppColors.primary,
              unselectedLabelColor: isDarkMode ? DarkColors.textHint : LightColors.textHint,
              indicatorColor: isDarkMode ? DarkColors.primary : AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(text: '${common.receivedTab}  ${incoming.length}'),
                Tab(text: common.sentTab),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: AppColors.sectionDivider),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIncomingTab(isDarkMode, contactProvider),
                _buildSentTab(isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingTab(bool isDarkMode, ContactProvider provider) {
    final common = CommonTexts.of(context);
    if (provider.isLoading && provider.incomingRequestsRaw.isEmpty) {
        return const Center(child: CircularProgressIndicator());
    }
    
    final incoming = provider.incomingRequestsRaw;
    
    if (incoming.isEmpty) {
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
      onRefresh: () => provider.fetchIncomingRequests(),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(common.olderHeader, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          ...incoming.map((req) => _buildIncomingItem(req, isDarkMode)),
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
        color: isDarkMode ? DarkColors.surface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? DarkColors.divider : AppColors.itemDivider,
          ),
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
                      child: ElevatedButton(
                        onPressed: () => _reject(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                          foregroundColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        child: Text(common.rejectAction, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _accept(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? DarkColors.primary : AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        child: Text(common.acceptAction, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
            trailing: OutlinedButton(
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
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                minimumSize: const Size(0, 36),
              ),
              child: Text(common.cancelAction, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}
