import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/features/call/screens/group_call_screen.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/main.dart';

class GroupCallPickerScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupCallPickerScreen({super.key, required this.conversation});

  @override
  State<GroupCallPickerScreen> createState() => _GroupCallPickerScreenState();
}

class _GroupCallPickerScreenState extends State<GroupCallPickerScreen> {
  final Set<String> _selectedUserIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<ConversationMember> get _availableMembers {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    return widget.conversation.members
        .where((m) => m.userId != currentUserId && m.leftAt == null)
        .toList();
  }

  List<ConversationMember> get _filteredMembers {
    if (_searchQuery.isEmpty) return _availableMembers;
    final q = _searchQuery.toLowerCase();
    return _availableMembers.where((m) {
      final name = m.nickname ?? m.user?.displayName ?? '';
      return name.toLowerCase().contains(q);
    }).toList();
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _removeUser(String userId) {
    setState(() {
      _selectedUserIds.remove(userId);
    });
  }

  void _startCall() {
    if (_selectedUserIds.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.id ?? '';
    final callId = generateCallId(
      conversationId: widget.conversation.id,
      callerUserId: currentUserId,
      audioOnly: false,
    );

    // Collect member avatar URLs for the call screen header
    final memberAvatarUrls = _availableMembers
        .where((m) => _selectedUserIds.contains(m.userId))
        .map((m) => m.user?.avatarUrl)
        .toList();

    Navigator.of(context).pop();
    Future.delayed(const Duration(milliseconds: 50), () {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => GroupCallScreen(
            conversationId: widget.conversation.id,
            callId: callId,
            conversationName: widget.conversation.title ?? 'Cuộc gọi nhóm',
            conversationAvatarUrl: widget.conversation.avatarUrl,
            audioOnly: false,
            isCaller: true,
            initialSelectedMembers: _selectedUserIds.toList(),
            memberAvatarUrls: memberAvatarUrls,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = _filteredMembers;
    final totalMembers = _availableMembers.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chọn người tham gia',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Tìm tên',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Section header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Thành viên nhóm ($totalMembers)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          // Member list
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy thành viên',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isSelected =
                          _selectedUserIds.contains(member.userId);
                      final userName = member.nickname ??
                          member.user?.displayName ??
                          'Thành viên';
                      final avatarUrl = member.user?.avatarUrl;

                      return InkWell(
                        onTap: () => _toggleUser(member.userId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              AvatarWidget(
                                imageUrl: avatarUrl,
                                name: userName,
                                size: 48,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              // Blue checkmark circle
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 18, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom bar: selected count + avatar chips + start button
          if (_selectedUserIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Đã chọn (N/Total)"
                    Text(
                      'Đã chọn (${_selectedUserIds.length}/$totalMembers)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Selected avatar chips with X
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _selectedUserIds.map((userId) {
                          final member = _availableMembers.firstWhere(
                            (m) => m.userId == userId,
                            orElse: () => _availableMembers.first,
                          );
                          final name = member.nickname ??
                              member.user?.displayName ??
                              'User';
                          final avatarUrl = member.user?.avatarUrl;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                AvatarWidget(
                                  imageUrl: avatarUrl,
                                  name: name,
                                  size: 44,
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeUser(userId),
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade500,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 1.5),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Start call button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _startCall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Bắt đầu gọi nhóm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
