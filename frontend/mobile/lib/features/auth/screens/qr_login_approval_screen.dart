import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

class QrLoginApprovalScreen extends StatefulWidget {
  const QrLoginApprovalScreen({super.key});

  @override
  State<QrLoginApprovalScreen> createState() => _QrLoginApprovalScreenState();
}

class _QrLoginApprovalScreenState extends State<QrLoginApprovalScreen> {
  final MobileScannerController _scannerController = MobileScannerController();

  String? _token;
  Map<String, dynamic>? _preview;
  bool _isLoadingPreview = false;
  bool _isApproving = false;
  String? _error;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_token != null || _isLoadingPreview) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    final token = _extractToken(rawValue);
    if (token == null) {
      setState(() {
        _error = 'Mã QR không hợp lệ cho đăng nhập web.';
      });
      return;
    }

    await _scannerController.stop();
    if (!mounted) return;

    setState(() {
      _token = token;
      _isLoadingPreview = true;
      _error = null;
    });

    try {
      final preview = await context.read<AuthProvider>().getQrLoginSessionPreview(token);
      if (!mounted) return;

      final status = preview['status']?.toString() ?? 'PENDING';
      if (status == 'EXPIRED') {
        setState(() {
          _error = 'Mã QR đã hết hạn. Vui lòng quét mã mới.';
          _preview = null;
          _token = null;
        });
        await _scannerController.start();
        return;
      }

      setState(() {
        _preview = preview;
        _cooldownSeconds = (preview['cooldownSecondsRemaining'] as num?)?.toInt() ?? 5;
      });
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể đọc phiên đăng nhập QR: $e';
        _token = null;
      });
      await _scannerController.start();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
        });
      }
    }
  }

  String? _extractToken(String rawValue) {
    try {
      final parsed = jsonDecode(rawValue);
      if (parsed is Map<String, dynamic>) {
        final type = parsed['type']?.toString();
        if (type == 'VNALO_WEB_LOGIN') {
          final token = parsed['token']?.toString();
          if (token != null && token.isNotEmpty) {
            return token;
          }
        }
      }
    } catch (_) {
      // Ignore malformed json, fallback below.
    }

    if (rawValue.startsWith('VNALO_WEB_LOGIN:')) {
      final token = rawValue.substring('VNALO_WEB_LOGIN:'.length).trim();
      return token.isEmpty ? null : token;
    }

    return null;
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds -= 1;
      });
    });
  }

  Future<void> _approve() async {
    if (_token == null || _isApproving || _cooldownSeconds > 0) {
      return;
    }

    setState(() {
      _isApproving = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().approveQrLoginSession(
            token: _token!,
            deviceId: 'android-mobile',
            deviceName: 'VNALO Mobile',
            platform: 'ANDROID',
            location: 'Mobile app',
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận đăng nhập web thành công.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Xác nhận đăng nhập thất bại: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isApproving = false;
        });
      }
    }
  }

  Future<void> _scanAgain() async {
    _cooldownTimer?.cancel();
    setState(() {
      _token = null;
      _preview = null;
      _error = null;
      _cooldownSeconds = 0;
      _isLoadingPreview = false;
      _isApproving = false;
    });
    await _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét QR đăng nhập web'),
      ),
      body: Column(
        children: [
          if (preview == null)
            Expanded(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xác nhận đăng nhập trên thiết bị',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _infoRow('Thiết bị', preview['webDeviceName']?.toString() ?? 'Không rõ'),
                    _infoRow('IP', preview['webIpAddress']?.toString() ?? 'Không rõ'),
                    _infoRow('Địa điểm', preview['webLocation']?.toString() ?? 'Không rõ'),
                    _infoRow('Nền tảng', preview['webPlatform']?.toString() ?? 'WEB'),
                    const SizedBox(height: 16),
                    Text(
                      _cooldownSeconds > 0
                          ? 'Vui lòng chờ $_cooldownSeconds giây trước khi đồng ý.'
                          : 'Bạn có thể nhấn Đồng ý để đăng nhập web.',
                      style: TextStyle(
                        color: _cooldownSeconds > 0 ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isApproving ? null : _scanAgain,
                            child: const Text('Quét lại'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_cooldownSeconds > 0 || _isApproving) ? null : _approve,
                            child: _isApproving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Đồng ý'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoadingPreview)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
