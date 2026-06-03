import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/privacy/providers/block_provider.dart';
import 'package:vnalo_mobile/models/blocked_user_model.dart';

class BlockManagementScreen extends StatefulWidget {
  const BlockManagementScreen({super.key});

  @override
  State<BlockManagementScreen> createState() => _BlockManagementScreenState();
}

class _BlockManagementScreenState extends State<BlockManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BlockProvider>().refresh();
    });
  }

  Future<void> _openDetails(BlockedUser user) async {
    final provider = context.read<BlockProvider>();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
    bool blockMessages = user.blockMessages;
    bool blockCalls = user.blockCalls;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return CupertinoActionSheet(
              title: Text(user.displayName),
              message: const Text('Quản lý quyền chặn cho người dùng này'),
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () {},
                  isDefaultAction: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chặn tin nhắn'),
                      CupertinoSwitch(
                        value: blockMessages,
                        onChanged: (v) {
                          setSheetState(() => blockMessages = v);
                          provider.scheduleUpdateFlags(user.userId, blockMessages: v);
                        },
                      ),
                    ],
                  ),
                ),
                CupertinoActionSheetAction(
                  onPressed: () {},
                  isDefaultAction: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chặn cuộc gọi'),
                      CupertinoSwitch(
                        value: blockCalls,
                        onChanged: (v) {
                          setSheetState(() => blockCalls = v);
                          provider.scheduleUpdateFlags(user.userId, blockCalls: v);
                        },
                      ),
                    ],
                  ),
                ),
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await provider.unblock(user.userId);
                  },
                  child: const Text('Bỏ chặn'),
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<BlockProvider>();

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: const Text(
          'Quản lý chặn',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<BlockProvider>().refresh(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: provider.blockedUsers.length + 1,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            indent: 72,
            color: isDarkMode ? DarkColors.divider : AppColors.itemDivider,
          ),
          itemBuilder: (context, index) {
            if (index == provider.blockedUsers.length) {
              if (provider.hasMore && !provider.isLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.read<BlockProvider>().loadMore();
                });
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: provider.isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          provider.blockedUsers.isEmpty ? 'Chưa chặn ai' : (provider.hasMore ? 'Đang tải...' : 'Hết'),
                          style: TextStyle(color: isDarkMode ? DarkColors.textHint : Colors.grey),
                        ),
                ),
              );
            }

            final u = provider.blockedUsers[index];
            final subtitle = <String>[
              if (u.blockMessages) 'Tin nhắn',
              if (u.blockCalls) 'Cuộc gọi',
            ].join(' · ');

            return ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                backgroundImage: (u.avatarUrl != null && u.avatarUrl!.isNotEmpty) ? NetworkImage(u.avatarUrl!) : null,
                child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                    ? Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?')
                    : null,
              ),
              title: Text(
                u.displayName,
                style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF1A1A1A)),
              ),
              subtitle: subtitle.isEmpty
                  ? null
                  : Text(
                      subtitle,
                      style: TextStyle(color: isDarkMode ? DarkColors.textHint : Colors.grey.shade600),
                    ),
              trailing: Icon(CupertinoIcons.chevron_right, size: 16, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400),
              onTap: () => _openDetails(u),
            );
          },
        ),
      ),
    );
  }
}
