import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/services/face_auth_service.dart';
import 'package:vnalo_mobile/navigation/main_shell.dart';
import 'package:vnalo_mobile/core/utils/device_info_util.dart';

class FaceLoginScreen extends StatefulWidget {
  final String? initialPhone;

  const FaceLoginScreen({super.key, this.initialPhone});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  final _userIdController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _faceService = FaceAuthService();

  bool _isLoading = false;
  bool _serviceAvailable = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    void _checkService() async {
      final available = await _faceService.isServiceAvailable();
      if (mounted) setState(() => _serviceAvailable = available);
    }
    _checkService();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _captureAndVerify() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập ID tài khoản');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      final imageFile = File(pickedFile.path);

      final liveness = await _faceService.checkLiveness(imageFile);
      if (!liveness.pass) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Không xác định được khuôn mặt thật. Vui lòng thử lại với ảnh rõ ràng.';
        });
        return;
      }

      final verify = await _faceService.verifyFace(
        imageFile,
        userId,
        livenessScore: liveness.score,
      );

      if (!verify.verified) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Khuôn mặt không khớp với tài khoản. Vui lòng kiểm tra lại ID.';
        });
        return;
      }

      final auth = context.read<AuthProvider>();
      final info = await DeviceInfoUtil.getDeviceInfo();
      final success = await auth.loginWithFace(
        userId: userId,
        deviceId: info.deviceId,
        deviceName: info.deviceName,
        platform: info.platform,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = auth.error ?? 'Đăng nhập khuôn mặt thất bại.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e is ApiException ? e.message : 'Đã xảy ra lỗi. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarFg = isDarkMode ? Colors.white : const Color(0xFF171717);
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : Colors.white;
    final textColor = isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary;
    final hintColor = isDarkMode ? DarkColors.textHint : LightColors.textHint;
    final primaryColor = isDarkMode ? DarkColors.primary : AppColors.primary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: appBarFg),
        title: Text(
          'Đăng nhập khuôn mặt',
          style: TextStyle(color: appBarFg, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_serviceAvailable) ...[
                _buildInfoCard(
                  icon: Icons.cloud_off_rounded,
                  iconColor: Colors.orange,
                  title: 'Dịch vụ không khả dụng',
                  subtitle: 'Xác thực khuôn mặt đang bảo trì. Vui lòng thử lại sau.',
                  bgColor: Colors.orange.shade50,
                  isDark: isDarkMode,
                ),
              ] else ...[
                _buildInfoCard(
                  icon: Icons.face_rounded,
                  iconColor: primaryColor,
                  title: 'Xác thực bằng khuôn mặt',
                  subtitle: 'Nhập ID tài khoản và chụp ảnh khuôn mặt để đăng nhập nhanh.',
                  bgColor: primaryColor.withValues(alpha: 0.08),
                  isDark: isDarkMode,
                ),
                const SizedBox(height: 24),
                Text(
                  'ID Tài khoản',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _userIdController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Nhập ID tài khoản (xem trong Cài đặt > Tài khoản)',
                    hintStyle: TextStyle(color: hintColor, fontSize: 14),
                    filled: true,
                    fillColor: isDarkMode ? DarkColors.surface : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn có thể xem ID tài khoản trong mục Cài đặt > Tài khoản trên app.',
                  style: TextStyle(fontSize: 12, color: hintColor),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_isLoading) ...[
                  Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Đang xác thực khuôn mặt...',
                          style: TextStyle(color: textColor),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _captureAndVerify,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                      label: const Text(
                        'Mở camera & xác thực',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Divider(color: hintColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('hoặc', style: TextStyle(color: hintColor, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: hintColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.science_outlined, color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tính năng đang trong giai đoạn thử nghiệm.',
                            style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? DarkColors.textPrimary : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? DarkColors.textSecondary : const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
