import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_login_approval_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractToken(String rawValue) {
    try {
      final parsed = jsonDecode(rawValue);
      if (parsed is Map<String, dynamic>) {
        if (parsed['type']?.toString() == 'VNALO_WEB_LOGIN') {
          final token = parsed['token']?.toString();
          if (token != null && token.isNotEmpty) {
            return token;
          }
        }
      }
    } catch (_) {
      // Ignore non-JSON payload.
    }

    if (rawValue.startsWith('VNALO_WEB_LOGIN:')) {
      final token = rawValue.substring('VNALO_WEB_LOGIN:'.length).trim();
      return token.isEmpty ? null : token;
    }

    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    final token = _extractToken(rawValue);
    if (token == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã QR chưa được hỗ trợ trong luồng này.')),
      );
      return;
    }

    _handling = true;
    await _controller.stop();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrLoginApprovalScreen(initialToken: token),
      ),
    );

    _handling = false;
    if (mounted) {
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Colors.white.withValues(alpha: 0.92);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _roundButton(
                  icon: Icons.close,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: textColor, size: 18),
                      const SizedBox(width: 8),
                      Text('Mã QR của tôi', style: TextStyle(color: textColor, fontSize: 17)),
                    ],
                  ),
                ),
                const Spacer(),
                _roundButton(icon: Icons.more_horiz, onTap: () {}),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(
                    children: const [
                      _ScannerCorner(alignment: Alignment.topLeft),
                      _ScannerCorner(alignment: Alignment.topRight),
                      _ScannerCorner(alignment: Alignment.bottomLeft),
                      _ScannerCorner(alignment: Alignment.bottomRight),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Quét mọi mã QR',
                style: TextStyle(color: textColor, fontSize: 33, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _BottomQuickAction(icon: Icons.photo, label: 'Ảnh có sẵn'),
                _BottomQuickAction(icon: Icons.qr_code_2, label: 'QR chuyển khoản'),
                _BottomQuickAction(icon: Icons.history, label: 'Gần đây'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(25),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.92)),
      ),
    );
  }
}

class _BottomQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BottomQuickAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 22),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.93), fontSize: 15)),
      ],
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  final Alignment alignment;

  const _ScannerCorner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: Colors.white.withValues(alpha: 0.75), width: 6) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: Colors.white.withValues(alpha: 0.75), width: 6) : BorderSide.none,
            left: isLeft ? BorderSide(color: Colors.white.withValues(alpha: 0.75), width: 6) : BorderSide.none,
            right: !isLeft ? BorderSide(color: Colors.white.withValues(alpha: 0.75), width: 6) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isTop && isLeft ? 12 : 0),
            topRight: Radius.circular(isTop && !isLeft ? 12 : 0),
            bottomLeft: Radius.circular(!isTop && isLeft ? 12 : 0),
            bottomRight: Radius.circular(!isTop && !isLeft ? 12 : 0),
          ),
        ),
      ),
    );
  }
}
