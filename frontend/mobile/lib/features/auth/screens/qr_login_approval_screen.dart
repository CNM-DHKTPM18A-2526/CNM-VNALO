import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

class QrLoginApprovalScreen extends StatefulWidget {
  final String? initialToken;

  const QrLoginApprovalScreen({super.key, this.initialToken});

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
  void initState() {
    super.initState();
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPreviewFromToken(widget.initialToken!);
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewFromToken(String token) async {
    if (_isLoadingPreview) {
      return;
    }

    await _scannerController.stop();
    if (!mounted) return;

    final common = CommonTexts.of(context, listen: false);
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
          _error = common.qrExpired;
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
        _error = '${common.cannotReadQrSession}: $e';
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
      final common = CommonTexts.of(context, listen: false);
      setState(() {
        _error = common.invalidLoginQr;
      });
      return;
    }

    await _scannerController.stop();
    if (!mounted) return;

    await _loadPreviewFromToken(token);
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

    final common = CommonTexts.of(context, listen: false);
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
        SnackBar(content: Text(common.loginConfirmedSuccess)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${common.loginConfirmationFailed}: $e';
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
    final common = CommonTexts.of(context);
    final preview = _preview;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : Colors.white;
    final appBarFg = isDarkMode ? Colors.white : const Color(0xFF171717);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: appBarFg,
        title: Text(common.qrLoginHeader),
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
                    Text(
                      common.confirmLoginOnDevice,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _infoRow(common.deviceLabel, preview['webDeviceName']?.toString() ?? common.unknownValue),
                    _infoRow('IP', preview['webIpAddress']?.toString() ?? common.unknownValue),
                    _infoRow(common.locationLabel, preview['webLocation']?.toString() ?? common.unknownValue),
                    _infoRow(common.platformLabel, preview['webPlatform']?.toString() ?? 'WEB'),
                    const SizedBox(height: 16),
                    Text(
                      _cooldownSeconds > 0
                          ? common.waitToApprove(_cooldownSeconds)
                          : common.canApproveNow,
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
                            child: Text(common.scanAgainAction),
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
                                : Text(common.agreeAction),
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
            width: 96,
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
