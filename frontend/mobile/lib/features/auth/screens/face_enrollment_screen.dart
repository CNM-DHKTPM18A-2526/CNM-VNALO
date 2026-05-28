import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/services/face_auth_service.dart' show FaceAuthService, ApiException;

/// Screen to enroll or update the user's face for face authentication.
/// Requires the user to be logged in.
class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

typedef _Step = String;

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  static const _stepIdle = 'idle';
  static const _stepCapturing = 'capturing';
  static const _stepConfirm = 'confirm';
  static const _stepProcessing = 'processing';
  static const _stepSuccess = 'success';
  static const _stepError = 'error';

  final _imagePicker = ImagePicker();
  final _faceService = FaceAuthService();

  _Step _step = _stepIdle;
  File? _capturedImage;
  String? _previewPath;
  String? _errorMsg;
  bool _isAlreadyEnrolled = false;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadEnrollmentStatus();
  }

  Future<void> _loadEnrollmentStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final auth = context.read<AuthProvider>();
      final status = await auth.getFaceEnrollmentStatus();
      if (mounted) {
        setState(() {
          _isAlreadyEnrolled = status['enrolled'] == true;
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _step = _stepCapturing;
      _errorMsg = null;
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );

      if (picked == null) {
        setState(() => _step = _stepIdle);
        return;
      }

      setState(() {
        _capturedImage = File(picked.path);
        _previewPath = picked.path;
        _step = _stepConfirm;
      });
    } catch (e) {
      setState(() {
        _step = _stepError;
        _errorMsg = 'Không thể mở camera. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _confirmEnroll() async {
    if (_capturedImage == null) return;

    setState(() {
      _step = _stepProcessing;
      _errorMsg = null;
    });

    try {
      // Client-side liveness pre-check for UX only
      final liveness = await _faceService.checkLiveness(_capturedImage!);
      if (!liveness.pass) {
        setState(() {
          _step = _stepError;
          _errorMsg = 'Không xác định được khuôn mặt thật. Vui lòng chụp lại với ánh sáng đầy đủ.';
        });
        return;
      }

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.enrollFace(_capturedImage!);

      if (!mounted) return;
      setState(() => _step = _stepSuccess);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _step = _stepError;
          _errorMsg = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _stepError;
          _errorMsg = 'Đăng ký thất bại. Vui lòng thử lại.';
        });
      }
    }
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
      _previewPath = null;
      _step = _stepIdle;
      _errorMsg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : Colors.white;
    final appBarFg = isDarkMode ? Colors.white : const Color(0xFF171717);
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
          _isAlreadyEnrolled ? 'Cập nhật khuôn mặt' : 'Đăng ký khuôn mặt',
          style: TextStyle(color: appBarFg, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loadingStatus
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context, isDarkMode, textColor, hintColor, primaryColor),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isDarkMode,
    Color textColor,
    Color hintColor,
    Color primaryColor,
  ) {
    if (_step == _stepSuccess) {
      return _buildSuccess(textColor, primaryColor);
    }
    if (_step == _stepProcessing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Đang xử lý đăng ký khuôn mặt...', textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info card
        _buildInfoCard(isDarkMode, primaryColor),
        const SizedBox(height: 24),

        // Preview
        if (_step == _stepConfirm && _previewPath != null) ...[
          Text('Xem lại ảnh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_previewPath!),
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Đảm bảo khuôn mặt rõ ràng, đủ ánh sáng.',
              style: TextStyle(fontSize: 12, color: hintColor),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmEnroll,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: Text(
                _isAlreadyEnrolled ? 'Cập nhật khuôn mặt' : 'Xác nhận đăng ký',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _retake,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: isDarkMode ? DarkColors.divider : const Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: Icon(Icons.camera_alt_rounded, color: textColor, size: 20),
              label: Text('Chụp lại', style: TextStyle(color: textColor, fontSize: 15)),
            ),
          ),
        ] else ...[
          // Error msg
          if (_step == _stepError && _errorMsg != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
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
          // Instruction
          Text(
            '1. Đảm bảo có đủ ánh sáng\n2. Nhìn thẳng vào camera\n3. Không đeo kính, khẩu trang',
            style: TextStyle(fontSize: 14, color: hintColor, height: 1.8),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _step == _stepCapturing ? null : _pickImage,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              label: const Text(
                'Mở camera & chụp ảnh',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard(bool isDarkMode, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (_isAlreadyEnrolled ? Colors.orange : primaryColor).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (_isAlreadyEnrolled ? Colors.orange : primaryColor).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isAlreadyEnrolled ? Icons.update_rounded : Icons.face_rounded,
              color: _isAlreadyEnrolled ? Colors.orange : primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAlreadyEnrolled ? 'Cập nhật khuôn mặt' : 'Đăng ký khuôn mặt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isAlreadyEnrolled
                      ? 'Khuôn mặt hiện tại sẽ được thay thế bằng ảnh mới.'
                      : 'Chụp ảnh khuôn mặt để đăng nhập không cần mật khẩu.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF6B7280),
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

  Widget _buildSuccess(Color textColor, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            _isAlreadyEnrolled ? 'Cập nhật thành công!' : 'Đăng ký thành công!',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Bạn có thể đăng nhập bằng khuôn mặt từ lần sau.',
            style: TextStyle(fontSize: 15, color: textColor.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text(
                'Hoàn tất',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
