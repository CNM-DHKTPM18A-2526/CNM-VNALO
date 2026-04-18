import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_list_screen.dart';
import 'package:vnalo_mobile/features/contacts/screens/contacts_screen.dart';
import 'package:vnalo_mobile/features/discover/screens/discover_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/profile_screen.dart';
import 'package:vnalo_mobile/features/timeline/screens/home_wall_screen.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'dart:async';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  StreamSubscription<String>? _actionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final aiProvider = context.read<AiAssistantProvider>();
      _actionSub = aiProvider.systemActionStream.listen(_handleAiSystemAction);
    });
  }

  @override
  void dispose() {
    _actionSub?.cancel();
    super.dispose();
  }

  String _normalizeAiSystemAction(String command) {
    switch (command.trim().toUpperCase()) {
      case 'START_CALL':
        return 'NAVIGATE_TO_CHAT';
      // Future mappings can go here
      default:
        return command.trim().toUpperCase();
    }
  }

  void _handleAiSystemAction(String command) {
    final normalizedCommand = _normalizeAiSystemAction(command);
    if (normalizedCommand == 'NAVIGATE_TO_SETTINGS') {
      setState(() => _currentIndex = 4); // Chuyển sang Tab Cá nhân
    } else if (normalizedCommand == 'NAVIGATE_TO_SCANNER') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    } else if (normalizedCommand == 'NAVIGATE_TO_CHAT') {
      setState(() => _currentIndex = 0);
    }
  }

  final _screens = const [
    ChatListScreen(),
    ContactsScreen(),
    DiscoverScreen(),
    HomeWallScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          int unreadCount = 0;
          for (var c in chatProvider.conversations) {
            unreadCount += c.unreadCount;
          }

          final common = CommonTexts.of(context);

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: isDarkMode ? DarkColors.textHint : const Color(0xFF9CA3AF),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: [
              BottomNavigationBarItem(
                icon: unreadCount > 0 
                  ? Badge(
                      label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
                      backgroundColor: AppColors.unreadBadge,
                      child: const Icon(Icons.chat_bubble_rounded),
                    )
                  : const Icon(Icons.chat_bubble_rounded),
                label: common.messagesTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.contacts_outlined),
                label: common.contactsTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.grid_view_rounded),
                label: common.discoverTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.feed_outlined),
                label: common.wallTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                label: common.profileTab,
              ),
            ],
          );
        },
      ),
    );
  }
}
