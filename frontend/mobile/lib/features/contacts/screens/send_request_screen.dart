import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
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
  bool _isAlreadySent = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final myName = auth.user?.displayName ?? 'VNALO User';
    final common = CommonTexts.of(context, listen: false);
    
    _messageController = TextEditingController(
      text: common.helloIam(myName),
    );
    final status = widget.targetUser.friendshipStatus?.toUpperCase();
    _isAlreadySent = status == 'PENDING_SENT' || status == 'PENDING';
    
    // Fallback: If status is not clearly pending, check against real sent list
    if (!_isAlreadySent) {
      _verifyStatus();
    }
  }

  Future<void> _verifyStatus() async {
    final isSent = await context.read<FriendService>().checkSentRequest(widget.targetUser.id);
    if (isSent && mounted) {
      setState(() => _isAlreadySent = true);
    }
  }

  Future<void> _handleCancel() async {
    setState(() => _isSending = true);
    final common = CommonTexts.of(context, listen: false);
    try {
      await context.read<FriendService>().cancelRequestByUserId(widget.targetUser.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(common.requestCancelledTo(widget.targetUser.displayName))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${common.cannotCancelRequest}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    setState(() => _isSending = true);
    final common = CommonTexts.of(context, listen: false);
    try {
      await context.read<FriendService>().sendFriendRequest(
            widget.targetUser.id,
            message: _messageController.text.trim(),
          );
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(common.requestSentTo(widget.targetUser.displayName))),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'SOCIAL_003' => common.requestAlreadySent,
        'SOCIAL_002' => common.alreadyFriends,
        'SOCIAL_001' => common.cannotAddSelf,
        'SOCIAL_007' => common.userBlocked,
        'SOCIAL_008' => common.userBlockedYou,
        _ => '${common.errorOccurred}: ${e.message}',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (e.code == 'SOCIAL_003' || e.code == 'SOCIAL_002') {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${common.errorOccurred}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : LightColors.scaffold,
      appBar: AppBar(
        title: Text(common.addFriendTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.white,
        surfaceTintColor: isDarkMode ? DarkColors.appBarBg : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (!_isSending)
            TextButton(
              onPressed: _isAlreadySent ? _handleCancel : _handleSend,
              child: Text(
                _isAlreadySent ? common.cancelAction.toUpperCase() : common.sendAction,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                   Text(
                    common.messageLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    maxLength: 150,
                    decoration: InputDecoration(
                      hintText: common.enterMessageHint,
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
                    onChanged: (v) => setState(() {}),
                    style: const TextStyle(fontSize: 16),
                    readOnly: _isAlreadySent,
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
                  onPressed: _isSending ? null : (_isAlreadySent ? _handleCancel : _handleSend),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isAlreadySent ? Colors.redAccent : AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: _isSending 
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(
                        _isAlreadySent ? common.cancelRequestAction : common.sendRequestAction,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
