import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/my_documents_screen.dart';
import 'package:vnalo_mobile/features/chat/widgets/chat_list_item.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().loadInbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode
        ? DarkColors.textHint
        : Colors.white.withValues(alpha: 0.8);
    final dividerColor = isDarkMode
      ? const Color(0xFF3A3F46)
      : const Color(0xFFE9EDF3);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0068FF), Color(0xFF00A2ED)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
        title: Row(
          children: [
            Icon(Icons.search, size: 24, color: searchHint),
            const SizedBox(width: 8),
            Text(
              'Tìm kiếm',
              style: TextStyle(color: searchHint, fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: searchHint),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.add, color: searchHint),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return RefreshIndicator(
            onRefresh: () => chatProvider.loadInbox(),
            color: AppColors.primary,
            child: ListView.builder(
              itemCount: chatProvider.conversations.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.folder, color: Colors.white, size: 32),
                              const Icon(Icons.cloud, color: Colors.blue, size: 16),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                                ),
                              )
                            ],
                          ),
                        ),
                        title: const Text(
                          'My Documents',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MyDocumentsScreen()),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 80,
                        color: dividerColor,
                      ),
                    ],
                  );
                }

                final conversation = chatProvider.conversations[index - 1];
                return ChatListItem(
                  conversation: conversation,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          conversation: conversation,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
