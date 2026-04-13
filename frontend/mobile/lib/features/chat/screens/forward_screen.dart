import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/forward_provider.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class ForwardScreen extends StatefulWidget {
  const ForwardScreen({super.key});

  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  final TextEditingController _additionalTextController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _additionalTextController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forwardProvider = context.watch<ForwardProvider>();
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final filteredConversations = forwardProvider.getFilteredConversations(currentUserId);

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chia sẻ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              'Đã chọn: ${forwardProvider.selectedCount}',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? DarkColors.textSecondary : Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: forwardProvider.updateSearch,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.white38 : Colors.grey.shade500, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAction(Icons.group_add_outlined, 'Nhóm mới', isDarkMode),
                _buildQuickAction(Icons.history_toggle_off, 'Nhật ký', isDarkMode),
                _buildQuickAction(Icons.ios_share_outlined, 'App khác', isDarkMode),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Recipient List
          Expanded(
            child: ListView(
              children: [
                _buildSectionTitle('Gần đây', isDarkMode),
                ...filteredConversations.map((conv) => _buildRecipientItem(conv, currentUserId, forwardProvider, isDarkMode)),
                
                const SizedBox(height: 16),
                _buildSectionTitle('Nhóm trò chuyện', isDarkMode),
                // (Optional: Further categorize if needed)
                
                const SizedBox(height: 80), // Space for preview/input
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomPanel(context, forwardProvider, isDarkMode),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, bool isDarkMode) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
          ),
          child: Icon(icon, color: isDarkMode ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildRecipientItem(Conversation conv, String currentUserId, ForwardProvider provider, bool isDarkMode) {
    final isSelected = provider.selectedConversationIds.contains(conv.id);
    final name = conv.getDisplayName(currentUserId);
    final avatar = conv.getDisplayAvatarUrl(currentUserId);

    return ListPadding(
      child: InkWell(
        onTap: () => provider.toggleSelection(conv.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              AvatarWidget(name: name, imageUrl: avatar, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, ForwardProvider provider, bool isDarkMode) {
    if (provider.sourceMessages.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        border: Border(top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected Avatars Bar
            if (provider.selectedCount > 0)
              _buildSelectedAvatarsRow(provider, isDarkMode),

            // Message Preview Box
            _buildMessagePreview(provider.sourceMessages, isDarkMode),

            // Text Input & Send Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _additionalTextController,
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn',
                          hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.grey.shade400),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: provider.isSending ? null : () => _handleSend(context, provider),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: provider.isSending
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedAvatarsRow(ForwardProvider provider, bool isDarkMode) {
    final conversations = provider.getFilteredConversations(context.read<AuthProvider>().user?.id ?? '')
        .where((c) => provider.selectedConversationIds.contains(c.id))
        .toList();

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conv = conversations[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              children: [
                AvatarWidget(
                  name: conv.getDisplayName(context.read<AuthProvider>().user?.id ?? ''),
                  imageUrl: conv.getDisplayAvatarUrl(context.read<AuthProvider>().user?.id ?? ''),
                  size: 50,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => provider.removeSelection(conv.id),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 10),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessagePreview(List<Message> messages, bool isDarkMode) {
    final message = messages.first;
    String contentSnippet = '';
    
    if (message.messageType == MessageType.TEXT) {
      contentSnippet = message.content ?? '';
    } else {
      contentSnippet = '[${message.messageType.toString().split('.').last}]';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        contentSnippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Future<void> _handleSend(BuildContext context, ForwardProvider provider) async {
    if (provider.selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn người nhận')),
      );
      return;
    }

    // Trigger send in background
    provider.sendForward(_additionalTextController.text);
    
    // Close screen immediately for instant feel
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang gửi tin nhắn chuyển tiếp...'), duration: Duration(seconds: 1)),
    );
  }
}

class ListPadding extends StatelessWidget {
  final Widget child;
  const ListPadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
