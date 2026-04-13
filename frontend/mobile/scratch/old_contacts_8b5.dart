import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<User> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      _friends = await context.read<FriendService>().getFriends();
    } catch (_) {
      _friends = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg =
        isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint =
        isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.8);
    final searchBg =
        isDarkMode ? const Color(0xFF2B2B2B) : Colors.white.withValues(alpha: 0.25);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        title: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: searchBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: searchHint),
              const SizedBox(width: 8),
              Text(
                'T├¼m kiß║┐m',
                style: TextStyle(color: searchHint, fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_outlined, color: searchHint),
            onPressed: () {
              // TODO: Add friend
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text('Lß╗¥i mß╗¥i kß║┐t bß║ín'),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Bß║ín b├¿ (${_friends.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ..._friends.map(
                  (user) => ListTile(
                    leading: AvatarWidget(
                      imageUrl: user.avatarUrl,
                      name: user.displayName,
                      size: 44,
                      showOnline: user.isOnline,
                    ),
                    title: Text(user.displayName),
                    subtitle: Text(user.phone ?? ''),
                  ),
                ),
              ],
            ),
    );
  }
}
