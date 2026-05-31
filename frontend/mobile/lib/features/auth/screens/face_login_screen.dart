import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/services/face_auth_service.dart';
import 'package:vnalo_mobile/navigation/main_shell.dart';
import 'package:vnalo_mobile/core/utils/device_info_util.dart';
import 'package:vnalo_mobile/features/auth/widgets/bank_face_scanner.dart';

class FaceLoginScreen extends StatefulWidget {
  final String? initialPhone;

  const FaceLoginScreen({super.key, this.initialPhone});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  final _identifierController = TextEditingController();
  final _faceService = FaceAuthService();

  bool _isLoading = false;
  bool _isScanning = false;
  bool _serviceAvailable = true;
  String? _errorMsg;

  Future<void> checkService() async {
    try {
      final available = await _faceService.isServiceAvailable();
      if (mounted) {
        setState(() => _serviceAvailable = available);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _serviceAvailable = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    checkService();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập số điện thoại hoặc email');
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMsg = null;
    });
  }

  Future<void> _captureAndVerify(File imageFile) async {
    final identifier = _identifierController.text.trim();

    setState(() {
      _isScanning = false;
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // Backend now enforces liveness check internally during /face/verify.
      // We no longer call /face/liveness-check here to avoid uploading the image twice.

      final userId = await _faceService.lookupUserId(identifier);

      final verifyResult = await _faceService.verifyFace(
        imageFile,
        userId,
      );

      if (!mounted) return;

      if (!verifyResult.verified || verifyResult.verificationToken == null) {
        setState(() {
          _isLoading = false;
          _errorMsg = verifyResult.decision == 'SPOOF_DETECTED'
              ? 'Phát hiện ảnh giả mạo. Vui lòng sử dụng khuôn mặt thật.'
              : 'Khuôn mặt không khớp với tài khoản. Vui lòng thử lại.';
        });
        return;
      }

      final auth = context.read<AuthProvider>();
      final info = await DeviceInfoUtil.getDeviceInfo();
      final success = await auth.loginWithFace(
        verificationToken: verifyResult.verificationToken!,
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
          if (e is TimeoutException) {
            _errorMsg = 'Quá thời gian chờ máy chủ. Vui lòng thử lại.';
          } else {
            _errorMsg = e is ApiException ? e.message : 'Đã xảy ra lỗi. Vui lòng thử lại.';
          }
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
      appBar: _isScanning ? null : AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: appBarFg),
        title: Text(
          'Đăng nhập khuôn mặt',
          style: TextStyle(color: appBarFg, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isScanning ? BankFaceScanner(
        onCapture: _captureAndVerify,
        onCancel: () => setState(() => _isScanning = false),
      ) : SafeArea(
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
                  subtitle: 'Nhập số điện thoại hoặc email đã đăng ký và chụp ảnh khuôn mặt để đăng nhập nhanh.',
                  bgColor: primaryColor.withValues(alpha: 0.08),
                  isDark: isDarkMode,
                ),
                const SizedBox(height: 24),
                Text(
                  'Số điện thoại hoặc Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _identifierController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Nhập số điện thoại hoặc email',
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
                  'Bạn cần đã đăng ký khuôn mặt trước đó trong mục Cài đặt.',
                  style: TextStyle(fontSize: 12, color: hintColor),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.red.shade900.withValues(alpha: 0.2) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: isDarkMode ? Colors.red.shade200 : Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: TextStyle(color: isDarkMode ? Colors.red.shade200 : Colors.red.shade700, fontSize: 13),
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
                      onPressed: _startScanning,
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
