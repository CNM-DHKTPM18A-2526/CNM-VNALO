import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _searchByPhone() async {
    final phone = _phoneController.text.trim();
    final friendService = context.read<FriendService>();
    if (phone.isEmpty || _isSearching) {
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final user = await friendService.searchUserByPhone(phone);
      if (!mounted) return;

      final shouldSend = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Kết quả tìm kiếm'),
              content: Text('Tìm thấy ${user.displayName}. Gửi lời mời kết bạn?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gửi lời mời')),
              ],
            ),
          ) ??
          false;

      if (shouldSend) {
        await friendService.sendFriendRequest(user.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi lời mời đến ${user.displayName}.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy người dùng hoặc bị giới hạn quyền riêng tư. $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final displayName = auth.user?.displayName ?? 'VNALO';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg,
        title: const Text('Thêm bạn'),
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: BoxDecoration(
              color: const Color(0xFF2B4F82),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, size: 140, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quét mã để thêm bạn Zalo với tôi',
                  style: TextStyle(color: Color(0xFFD4E2FF), fontSize: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF4B5563)),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF0F1116),
                  ),
                  child: const Text('+84', style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 19),
                    decoration: InputDecoration(
                      hintText: 'Nhập số điện thoại',
                      hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                      filled: true,
                      fillColor: const Color(0xFF0F1116),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4B5563)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4B5563)),
                      ),
                    ),
                    onSubmitted: (_) => _searchByPhone(),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF2A2F38),
                  child: IconButton(
                    onPressed: _isSearching ? null : _searchByPhone,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            title: const Text('Quét mã QR', style: TextStyle(color: Colors.white, fontSize: 20)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_page_outlined, color: AppColors.primary),
            title: const Text('Bạn bè có thể quen', style: TextStyle(color: Colors.white, fontSize: 20)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sẽ triển khai ở bước đề xuất bạn bè tiếp theo.')),
              );
            },
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Xem lời mời kết bạn đã gửi tại trang Danh bạ Zalo',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
