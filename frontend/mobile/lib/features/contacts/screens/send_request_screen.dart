import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class SendRequestScreen extends StatefulWidget {
  final User targetUser;

  const SendRequestScreen({super.key, required this.targetUser});

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  late TextEditingController _messageController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final myName = auth.user?.displayName ?? 'VNALO User';
    _messageController = TextEditingController(
      text: 'Xin chào, mình là $myName. Kết bạn với mình nhé!',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    setState(() => _isSending = true);
    try {
      await context.read<FriendService>().sendFriendRequest(
            widget.targetUser.id,
            message: _messageController.text.trim(),
          );
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi lời mời đến ${widget.targetUser.displayName}')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'SOCIAL_003' => 'Bạn đã gửi lời mời kết bạn cho người này rồi.',
        'SOCIAL_002' => 'Hai bạn đã là bạn bè rồi.',
        'SOCIAL_001' => 'Không thể tự kết bạn với chính mình.',
        'SOCIAL_007' => 'Bạn đã chặn người dùng này.',
        'SOCIAL_008' => 'Người dùng này đã chặn bạn.',
        _ => 'Không thể gửi lời mời: ${e.message}',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (e.code == 'SOCIAL_003' || e.code == 'SOCIAL_002') {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Kết bạn', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.white,
        surfaceTintColor: isDarkMode ? DarkColors.appBarBg : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (!_isSending)
            TextButton(
              onPressed: _handleSend,
              child: const Text(
                'GỬI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: isDarkMode ? DarkColors.surface : Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  AvatarWidget(
                    imageUrl: widget.targetUser.avatarUrl,
                    name: widget.targetUser.displayName,
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.targetUser.displayName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (widget.targetUser.phone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.targetUser.phone!,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              color: isDarkMode ? DarkColors.surface : Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    'Lời nhắn',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    maxLength: 150,
                    decoration: InputDecoration(
                      hintText: 'Nhập lời nhắn...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      filled: true,
                      fillColor: isDarkMode ? Colors.black26 : const Color(0xFFF9FAFB),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                   const SizedBox(height: 8),
                   Text(
                    '${_messageController.text.length}/150',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isSending ? null : _handleSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _isSending 
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Gửi lời mời', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
