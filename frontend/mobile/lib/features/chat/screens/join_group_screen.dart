import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final result = await context.read<ChatProvider>().requestJoinGroup(id);
      final status = result['status'];

      if (!mounted) return;
      
      if (status == 'JOINED' || status == 'ALREADY_MEMBER') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tham gia nhóm thành công')),
        );
        // Try to find the conversation object in provider to navigate
        final chatProvider = context.read<ChatProvider>();
        final conv = chatProvider.conversations.firstWhere((c) => c.id == id, orElse: () => throw 'Conversation not found');
        
        Navigator.pop(context); // Close join screen
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: conv)));
      } else if (status == 'PENDING_APPROVAL') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yêu cầu tham gia đã được gửi, vui lòng chờ duyệt')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: const Text(
          'Tham gia nhóm',
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập mã nhóm hoặc link tham gia để vào trò chuyện cùng mọi người.',
              style: TextStyle(fontSize: 15, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                hintText: 'Mã nhóm hoặc Link',
                filled: true,
                fillColor: isDarkMode ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chức năng quét mã QR sắp ra mắt'))),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Tham gia ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Column(
              children: [
                Icon(Icons.shield_outlined, color: Colors.grey.shade400, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Tham gia nhóm an toàn và bảo mật.\nBạn có thể rời nhóm bất cứ lúc nào.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
