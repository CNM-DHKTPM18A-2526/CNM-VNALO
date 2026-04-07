import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/constants/api_endpoints.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_login_approval_screen.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

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

  _ParsedQrPayload _parsePayload(String rawValue) {
    final trimmed = rawValue.trim();

    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map<String, dynamic>) {
        final type = parsed['type']?.toString().toUpperCase();
        if (type == 'VNALO_WEB_LOGIN') {
          final token = parsed['token']?.toString().trim();
          if (token != null && token.isNotEmpty) {
            return _ParsedQrPayload.login(token);
          }
        }

        final userId = parsed['userId']?.toString().trim();
        final token = parsed['token']?.toString().trim();
        final nonce = parsed['nonce']?.toString().trim();
        if (userId != null && userId.isNotEmpty && token != null && token.isNotEmpty && nonce != null && nonce.isNotEmpty) {
          return _ParsedQrPayload.friend(
            userId: userId,
            token: token,
            nonce: nonce,
          );
        }

        if (type == 'VNALO_GROUP_INVITE') {
          final conversationId =
              parsed['conversationId']?.toString().trim() ??
              parsed['groupId']?.toString().trim();
          if (conversationId != null && conversationId.isNotEmpty) {
            return _ParsedQrPayload.group(conversationId);
          }
        }
      }
    } catch (_) {
      // Ignore non-JSON payload.
    }

    if (trimmed.startsWith('VNALO_WEB_LOGIN:')) {
      final token = trimmed.substring('VNALO_WEB_LOGIN:'.length).trim();
      if (token.isNotEmpty) {
        return _ParsedQrPayload.login(token);
      }
    }

    if (trimmed.startsWith('VNALO_GROUP_INVITE:')) {
      final id = trimmed.substring('VNALO_GROUP_INVITE:'.length).trim();
      if (id.isNotEmpty) {
        return _ParsedQrPayload.group(id);
      }
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final fromQuery = uri.queryParameters['conversationId'];
      if (fromQuery != null && fromQuery.isNotEmpty) {
        return _ParsedQrPayload.group(fromQuery);
      }

      final segments = uri.pathSegments;
      final conversationIndex = segments.indexOf('conversations');
      if (conversationIndex >= 0 && segments.length > conversationIndex + 1) {
        final id = segments[conversationIndex + 1];
        if (id.isNotEmpty) {
          return _ParsedQrPayload.group(id);
        }
      }
    }

    return const _ParsedQrPayload.unsupported();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    final payload = _parsePayload(rawValue);
    if (payload.type == _QrPayloadType.unsupported) {
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

    try {
      switch (payload.type) {
        case _QrPayloadType.login:
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QrLoginApprovalScreen(initialToken: payload.token),
            ),
          );
          break;
        case _QrPayloadType.friend:
          await _handleFriendQr(payload);
          break;
        case _QrPayloadType.group:
          await _handleGroupQr(payload);
          break;
        case _QrPayloadType.unsupported:
          break;
      }
    } finally {
      _handling = false;
      if (mounted) {
        await _controller.start();
      }
    }
  }

  Future<void> _handleFriendQr(_ParsedQrPayload payload) async {
    if (!mounted || payload.userId == null || payload.token == null || payload.nonce == null) {
      return;
    }

    try {
      final result = await context.read<FriendService>().scanFriendQr(
        userId: payload.userId!,
        token: payload.token!,
        nonce: payload.nonce!,
      );

      if (!mounted) {
        return;
      }

      final message = result['message']?.toString() ?? 'Da xu ly QR ket ban.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khong the xu ly QR ket ban: $e')),
      );
    }
  }

  Future<void> _handleGroupQr(_ParsedQrPayload payload) async {
    if (!mounted || payload.conversationId == null) {
      return;
    }

    try {
      final response = await context.read<ApiService>().post(
        ApiEndpoints.messageBaseUrl,
        '/conversations/${payload.conversationId}/join',
      );
      if (!mounted) {
        return;
      }
      final status =
          response['status']?.toString() ??
          (response['data'] is Map<String, dynamic>
              ? (response['data']['status']?.toString() ?? 'REQUESTED')
              : 'REQUESTED');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nhom: $status')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khong the tham gia nhom: $e')),
      );
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
                  width: 268,
                  height: 268,
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
            bottom: 148,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Quét mọi mã QR',
                    style: TextStyle(color: textColor, fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đưa mã vào giữa khung để nhận diện nhanh',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
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

enum _QrPayloadType { login, friend, group, unsupported }

class _ParsedQrPayload {
  final _QrPayloadType type;
  final String? token;
  final String? userId;
  final String? nonce;
  final String? conversationId;

  const _ParsedQrPayload._({
    required this.type,
    this.token,
    this.userId,
    this.nonce,
    this.conversationId,
  });

  const _ParsedQrPayload.unsupported() : this._(type: _QrPayloadType.unsupported);

  factory _ParsedQrPayload.login(String token) {
    return _ParsedQrPayload._(type: _QrPayloadType.login, token: token);
  }

  factory _ParsedQrPayload.friend({
    required String userId,
    required String token,
    required String nonce,
  }) {
    return _ParsedQrPayload._(
      type: _QrPayloadType.friend,
      userId: userId,
      token: token,
      nonce: nonce,
    );
  }

  factory _ParsedQrPayload.group(String conversationId) {
    return _ParsedQrPayload._(
      type: _QrPayloadType.group,
      conversationId: conversationId,
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 23),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.93),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: Colors.white.withValues(alpha: 0.78), width: 6.5) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: Colors.white.withValues(alpha: 0.78), width: 6.5) : BorderSide.none,
            left: isLeft ? BorderSide(color: Colors.white.withValues(alpha: 0.78), width: 6.5) : BorderSide.none,
            right: !isLeft ? BorderSide(color: Colors.white.withValues(alpha: 0.78), width: 6.5) : BorderSide.none,
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
