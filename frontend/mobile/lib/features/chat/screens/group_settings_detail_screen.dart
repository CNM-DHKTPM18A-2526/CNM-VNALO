import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';

class GroupSettingsDetailScreen extends StatefulWidget {
  final String conversationId;
  final JoinMode currentJoinMode;
  final int currentMemberLimit;

  const GroupSettingsDetailScreen({
    super.key,
    required this.conversationId,
    required this.currentJoinMode,
    required this.currentMemberLimit,
  });

  @override
  State<GroupSettingsDetailScreen> createState() =>
      _GroupSettingsDetailScreenState();
}

class _GroupSettingsDetailScreenState extends State<GroupSettingsDetailScreen> {
  late JoinMode _joinMode;
  late int _memberLimit;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _joinMode = widget.currentJoinMode;
    _memberLimit = widget.currentMemberLimit;
  }

  String _joinModeLabel(JoinMode mode) {
    switch (mode) {
      case JoinMode.OPEN:
        return 'Mọi người';
      case JoinMode.APPROVAL:
        return 'Cần phê duyệt';
      case JoinMode.INVITE_ONLY:
        return 'Chỉ mời';
    }
  }

  String _joinModeDescription(JoinMode mode) {
    switch (mode) {
      case JoinMode.OPEN:
        return 'Bất kỳ ai cũng có thể tham gia nhóm';
      case JoinMode.APPROVAL:
        return 'Người tham gia cần được trưởng/phó nhóm phê duyệt';
      case JoinMode.INVITE_ONLY:
        return 'Chỉ trưởng/phó nhóm mới có thể mời thành viên';
    }
  }

  Future<void> _changeGroupName() async {
    final common = CommonTexts.of(context, listen: false);
    final controller = TextEditingController();

    final newName = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(common.changeGroupNameAction),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Tên nhóm',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: Text(common.cancel),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(common.save),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() => _isUpdating = true);
      try {
        await context.read<ChatProvider>().updateGroupInfo(
          widget.conversationId,
          title: newName,
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể đổi tên nhóm: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _changeGroupPhoto() async {
    final picker = ImagePicker();

    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Đổi ảnh nhóm'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Chụp ảnh mới'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Chọn từ thư viện'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null && mounted) {
      setState(() => _isUpdating = true);
      try {
        await context.read<ChatProvider>().updateGroupAvatarFile(
          widget.conversationId,
          io.File(pickedFile.path),
        );
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể cập nhật ảnh nhóm: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _changeJoinMode() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Chế độ tham gia nhóm'),
        message: Text(_joinModeDescription(_joinMode)),
        actions: JoinMode.values.map((mode) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _applyJoinMode(mode);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_joinModeLabel(mode)),
                if (mode == _joinMode) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  Future<void> _applyJoinMode(JoinMode mode) async {
    if (mode == _joinMode) return;
    setState(() {
      _joinMode = mode;
      _isUpdating = true;
    });
    try {
      await context.read<ChatProvider>().updateGroupInfo(
        widget.conversationId,
        joinMode: mode.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật chế độ: $e')),
        );
        setState(() => _joinMode = widget.currentJoinMode);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _changeMemberLimit() async {
    final controller = TextEditingController(text: _memberLimit.toString());

    final newLimit = await showCupertinoDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Giới hạn thành viên'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '10 - 500',
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              Navigator.pop(context, parsed);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newLimit != null && newLimit >= 10 && newLimit <= 500 && mounted) {
      setState(() {
        _memberLimit = newLimit;
        _isUpdating = true;
      });
      try {
        // memberLimit is not yet in updateGroupInfo; log for now.
        // Backend needs this field added.
        debugPrint('Member limit update requested: $newLimit');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể cập nhật giới hạn: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    } else if (newLimit != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Giới hạn phải từ 10 đến 500')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final common = CommonTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: Text(
          common.groupSettingsHeader,
          style:
              const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration:
                    const BoxDecoration(gradient: AppColors.appBarGradient)),
      ),
      body: Stack(
        children: [
          Container(
            color: isDarkMode ? DarkColors.surface : Colors.white,
            child: ListView(
              children: [
                ListTile(
                  leading: Icon(Icons.edit_outlined,
                      color: isDarkMode ? DarkColors.primary : AppColors.primary),
                  title: Text(common.changeGroupNameAction),
                  trailing: Icon(Icons.chevron_right,
                      size: 20,
                      color: isDarkMode
                          ? DarkColors.textHint
                          : Colors.grey.shade400),
                  onTap: _isUpdating ? null : _changeGroupName,
                ),
                Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 56,
                    color: isDarkMode ? DarkColors.divider : AppColors.itemDivider),
                ListTile(
                  leading: Icon(Icons.image_outlined,
                      color: isDarkMode ? DarkColors.primary : AppColors.primary),
                  title: Text(common.changeGroupPhotoAction),
                  trailing: Icon(Icons.chevron_right,
                      size: 20,
                      color: isDarkMode
                          ? DarkColors.textHint
                          : Colors.grey.shade400),
                  onTap: _isUpdating ? null : _changeGroupPhoto,
                ),
                Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 56,
                    color: isDarkMode ? DarkColors.divider : AppColors.itemDivider),
                ListTile(
                  leading: Icon(Icons.lock_outline,
                      color: isDarkMode ? DarkColors.primary : AppColors.primary),
                  title: Text(common.joinModeLabel),
                  subtitle: Text(
                    _joinModeLabel(_joinMode),
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      size: 20,
                      color: isDarkMode
                          ? DarkColors.textHint
                          : Colors.grey.shade400),
                  onTap: _isUpdating ? null : _changeJoinMode,
                ),
                Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 56,
                    color: isDarkMode ? DarkColors.divider : AppColors.itemDivider),
                ListTile(
                  leading: Icon(Icons.people_outline,
                      color: isDarkMode ? DarkColors.primary : AppColors.primary),
                  title: Text(common.memberLimitLabel),
                  subtitle: Text(
                    '$_memberLimit thành viên',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      size: 20,
                      color: isDarkMode
                          ? DarkColors.textHint
                          : Colors.grey.shade400),
                  onTap: _isUpdating ? null : _changeMemberLimit,
                ),
              ],
            ),
          ),
          if (_isUpdating)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
