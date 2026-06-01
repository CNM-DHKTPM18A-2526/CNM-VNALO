import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/timeline/providers/post_provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? avatarUrl;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.avatarUrl,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Assuming postProvider has loadUserTimeline
      // context.read<PostProvider>().loadUserTimeline(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : Colors.white,
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.white,
        elevation: 0,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 150,
                      color: Colors.grey.shade300,
                      // Cover photo placeholder
                    ),
                    Positioned(
                      bottom: -40,
                      child: AvatarWidget(
                        imageUrl: widget.avatarUrl,
                        name: widget.userName,
                        size: 100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                Text(
                  widget.userName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Tính năng đang được cập nhật.', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
          // Timeline posts will go here
        ],
      ),
    );
  }
}
