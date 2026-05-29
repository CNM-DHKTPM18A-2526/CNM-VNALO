import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';

class AlbumPrivacySheet extends StatefulWidget {
  final String currentPrivacy;
  final List<String> includedFriendIds;
  final List<String> excludedFriendIds;
  final Function(String privacy, List<String> includedIds, List<String> excludedIds) onPrivacyChanged;

  const AlbumPrivacySheet({
    super.key,
    required this.currentPrivacy,
    this.includedFriendIds = const [],
    this.excludedFriendIds = const [],
    required this.onPrivacyChanged,
  });

  @override
  State<AlbumPrivacySheet> createState() => _AlbumPrivacySheetState();
}

class _AlbumPrivacySheetState extends State<AlbumPrivacySheet> {
  late String _selectedPrivacy;
  late List<String> _includedIds;
  late List<String> _excludedIds;
  List<User> _friends = [];
  bool _isLoadingFriends = false;
  
  // States for sub-screen
  bool _showSelectionList = false;
  bool _isSelectingForInclude = false; // true = SOME_FRIENDS, false = EXCEPT

  final List<Map<String, dynamic>> _privacyOptions = [
    {
      'value': 'FRIENDS',
      'title': 'Bạn bè VNALO',
      'subtitle': 'Tất cả bạn bè trên VNALO',
      'icon': Icons.group_outlined,
      'iconColor': const Color(0xFF607D8B),
    },
    {
      'value': 'PRIVATE',
      'title': 'Chỉ mình tôi',
      'subtitle': 'Chỉ mình bạn được xem',
      'icon': Icons.lock_outline,
      'iconColor': const Color(0xFF607D8B),
    },
    {
      'value': 'SOME_FRIENDS',
      'title': 'Một số bạn bè',
      'subtitle': 'Chọn những bạn bè được xem',
      'icon': Icons.person_add_outlined,
      'iconColor': const Color(0xFF607D8B),
    },
    {
      'value': 'FRIENDS_EXCEPT',
      'title': 'Bạn bè ngoại trừ...',
      'subtitle': 'Chọn những bạn bè không được xem',
      'icon': Icons.person_remove_outlined,
      'iconColor': const Color(0xFF607D8B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedPrivacy = widget.currentPrivacy.isEmpty ? 'FRIENDS' : widget.currentPrivacy;
    _includedIds = List.from(widget.includedFriendIds);
    _excludedIds = List.from(widget.excludedFriendIds);
  }

  Future<void> _loadFriends() async {
    if (_friends.isNotEmpty) return;
    setState(() => _isLoadingFriends = true);
    try {
      final apiService = context.read<ApiService>();
      final friendService = FriendService(apiService);
      final friends = await friendService.getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint('[AlbumPrivacySheet] loadFriends error: $e');
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  void _onPrivacySelected(String privacy) {
    setState(() {
      _selectedPrivacy = privacy;
      if (privacy == 'FRIENDS_EXCEPT') {
        _showSelectionList = true;
        _isSelectingForInclude = false;
        _loadFriends();
      } else if (privacy == 'SOME_FRIENDS') {
        _showSelectionList = true;
        _isSelectingForInclude = true;
        _loadFriends();
      } else {
        _showSelectionList = false;
        _includedIds.clear();
        _excludedIds.clear();
      }
    });
  }

  void _toggleFriend(String friendId) {
    setState(() {
      if (_isSelectingForInclude) {
        if (_includedIds.contains(friendId)) {
          _includedIds.remove(friendId);
        } else {
          _includedIds.add(friendId);
        }
      } else {
        if (_excludedIds.contains(friendId)) {
          _excludedIds.remove(friendId);
        } else {
          _excludedIds.add(friendId);
        }
      }
    });
  }

  void _save() {
    widget.onPrivacyChanged(_selectedPrivacy, _includedIds, _excludedIds);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      // Full screen minus status bar
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Ai xem được bài đăng này?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),

          Divider(
            color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
            height: 1,
          ),

          // Privacy options list
          Expanded(
            child: _showSelectionList
                ? _buildSelectionList(isDarkMode)
                : _buildPrivacyList(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _privacyOptions.length,
      itemBuilder: (context, index) {
        final option = _privacyOptions[index];
        final isSelected = _selectedPrivacy == option['value'];

        String subtitle = option['subtitle'] as String;
        if (isSelected && option['value'] == 'FRIENDS_EXCEPT' && _excludedIds.isNotEmpty) {
          subtitle = '${_excludedIds.length} người bị loại trừ';
        } else if (isSelected && option['value'] == 'SOME_FRIENDS' && _includedIds.isNotEmpty) {
          subtitle = '${_includedIds.length} người được chọn';
        }

        return InkWell(
          onTap: () {
            if (isSelected && (option['value'] == 'FRIENDS_EXCEPT' || option['value'] == 'SOME_FRIENDS')) {
              // Clicked again on selected option -> open list
              setState(() {
                _showSelectionList = true;
                _isSelectingForInclude = option['value'] == 'SOME_FRIENDS';
                _loadFriends();
              });
            } else {
              _onPrivacySelected(option['value'] as String);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (option['iconColor'] as Color).withOpacity(isDarkMode ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    option['icon'] as IconData,
                    color: option['iconColor'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option['title'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Radio button
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDarkMode ? Colors.white24 : Colors.grey.shade400),
                      width: isSelected ? 0 : 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionList(bool isDarkMode) {
    final titleText = _isSelectingForInclude 
        ? 'Chọn bạn bè được xem' 
        : 'Chọn bạn bè không được xem';
    
    final emptyText = _friends.isEmpty ? 'Chưa có bạn bè nào' : '';
    final currentList = _isSelectingForInclude ? _includedIds : _excludedIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button + header
        InkWell(
          onTap: () => setState(() {
            _showSelectionList = false;
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.arrow_back_ios, size: 18, color: isDarkMode ? Colors.white70 : Colors.black54),
                const SizedBox(width: 4),
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(color: isDarkMode ? Colors.white12 : Colors.grey.shade200, height: 1),

        if (_isLoadingFriends)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_friends.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off_outlined, size: 56, color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    emptyText,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 4),
              itemCount: _friends.length,
              separatorBuilder: (_, __) => Divider(
                color: isDarkMode ? Colors.white12 : Colors.grey.shade100,
                height: 1,
                indent: 70,
              ),
              itemBuilder: (context, index) {
                final friend = _friends[index];
                final isSelectedUser = currentList.contains(friend.id);
                return InkWell(
                  onTap: () => _toggleFriend(friend.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: friend.avatarUrl != null
                              ? NetworkImage(friend.avatarUrl!)
                              : null,
                          backgroundColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                          child: friend.avatarUrl == null
                              ? Text(
                                  friend.displayName.isNotEmpty
                                      ? friend.displayName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white70 : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            friend.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        // Checkbox
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelectedUser
                                  ? AppColors.primary
                                  : (isDarkMode ? Colors.white24 : Colors.grey.shade400),
                              width: isSelectedUser ? 0 : 2,
                            ),
                            color: isSelectedUser ? AppColors.primary : Colors.transparent,
                          ),
                          child: isSelectedUser
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Confirm button
        SafeArea(
          bottom: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: isDarkMode ? DarkColors.surface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  currentList.isEmpty 
                    ? 'Xong' 
                    : 'Xong (${currentList.length} người được chọn)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
