import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/qr_service.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isSearching = false;
  String? _qrPayload;
  bool _isLoadingQr = false;

  @override
  void initState() {
    super.initState();
    _loadMyQr();
  }

  Future<void> _loadMyQr() async {
    if (_isLoadingQr) {
      return;
    }
    setState(() => _isLoadingQr = true);
    try {
      final payload = await QrService(
        context.read<ApiService>(),
      ).generateFriendQrRawPayload();
      if (!mounted) {
        return;
      }
      setState(() => _qrPayload = payload);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được mã QR của bạn.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingQr = false);
      }
    }
  }

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
        try {
          await friendService.sendFriendRequest(user.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã gửi lời mời đến ${user.displayName}.')),
          );
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
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'USER_001' => 'Không tìm thấy người dùng với số điện thoại này.',
        _ => 'Không tìm thấy người dùng hoặc bị giới hạn quyền riêng tư.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi: $e')),
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
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;
    final sectionBg = isDarkMode ? DarkColors.surface : Colors.white;
    final inputBorder = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg,
        foregroundColor: Colors.white,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        title: const Text('Thêm bạn', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF3F5F85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 188,
                  height: 188,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      _isLoadingQr
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : (_qrPayload == null || _qrPayload!.isEmpty)
                          ? const Icon(Icons.qr_code_2_rounded, size: 146, color: Colors.black87)
                          : Padding(
                            padding: const EdgeInsets.all(10),
                            child: QrImageView(
                              data: _qrPayload!,
                              version: QrVersions.auto,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Quét mã để thêm bạn Zalo với tôi',
                  style: TextStyle(color: Color(0xFFD7E4F7), fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: inputBorder),
                    borderRadius: BorderRadius.circular(10),
                    color: sectionBg,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '+84',
                        style: TextStyle(
                          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                          fontSize: 30 / 2,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: AppColors.iconSubtle),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhập số điện thoại',
                      hintStyle: const TextStyle(color: LightColors.textHint),
                      filled: true,
                      fillColor: sectionBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: inputBorder),
                      ),
                    ),
                    onSubmitted: (_) => _searchByPhone(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDarkMode ? DarkColors.surfaceLight : const Color(0xFFE3E7ED),
                  child: IconButton(
                    onPressed: _isSearching ? null : _searchByPhone,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.arrow_forward,
                            color: isDarkMode ? DarkColors.textPrimary : LightColors.textHint,
                          ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: sectionBg,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  title: const Text('Quét mã QR', style: TextStyle(fontSize: 18)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 64, color: AppColors.itemDivider),
                ListTile(
                  leading: const Icon(Icons.contact_page_outlined, color: AppColors.primary),
                  title: const Text('Bạn bè có thể quen', style: TextStyle(fontSize: 18)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sẽ triển khai ở bước đề xuất bạn bè tiếp theo.')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_qrPayload == null && !_isLoadingQr)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _loadMyQr,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại mã QR'),
              ),
            ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Xem lời mời kết bạn đã gửi tại trang Danh bạ Zalo',
              style: TextStyle(color: LightColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
