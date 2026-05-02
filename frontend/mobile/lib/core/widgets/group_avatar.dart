import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';

/// GroupAvatar: Hiển thị tối đa 4 avatar thành viên trong một khung tròn bằng với kích thước avatar đơn.
///
/// Quy tắc bố cục (theo UI_Standard_vnalo.md mục 5c):
/// - Toàn bộ khối luôn nằm trong SizedBox(width: size, height: size)
/// - 1 thành viên: avatar đơn full-size
/// - 2 thành viên: 2 avatar ~62% size, lệch chéo trên-trái / dưới-phải
/// - 3 thành viên: 1 ở trên giữa + 2 ở hàng dưới, mỗi cái ~54% size
/// - 4+ thành viên: grid 2×2, mỗi avatar 50% size lấp đầy 4 góc với gap 1.5px
/// - Mỗi avatar con có borderWidth: 1.0 (viền trắng) để tách biệt
class GroupAvatar extends StatelessWidget {
  final List<({String? imageUrl, String name})> members;
  final int? totalMemberCount;
  final double size;

  const GroupAvatar({
    super.key,
    required this.members,
    this.totalMemberCount,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return AvatarWidget(name: 'G', size: size);
    }

    if (members.length == 1 && (totalMemberCount == null || totalMemberCount! <= 1)) {
      return AvatarWidget(
        imageUrl: members[0].imageUrl,
        name: members[0].name,
        size: size,
      );
    }

    final effectiveCount = totalMemberCount ?? members.length;
    final displayMembers = members.take(4).toList();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: _buildAvatarPositions(context, displayMembers, effectiveCount),
      ),
    );
  }

  List<Widget> _buildAvatarPositions(
    BuildContext context,
    List<({String? imageUrl, String name})> items,
    int totalCount,
  ) {
    const double border = 1.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (totalCount == 2) {
      final childSize = size * 0.62;
      final offset = size * 0.05;
      return [
        Positioned(
          top: offset,
          left: offset,
          child: AvatarWidget(
            imageUrl: items.isNotEmpty ? items[0].imageUrl : null,
            name: items.isNotEmpty ? items[0].name : '?',
            size: childSize,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: offset,
          right: offset,
          child: AvatarWidget(
            imageUrl: items.length > 1 ? items[1].imageUrl : null,
            name: items.length > 1 ? items[1].name : '?',
            size: childSize,
            borderWidth: border,
          ),
        ),
      ];
    }

    if (totalCount == 3) {
      final childSize = size * 0.54;
      final topCenter = (size - childSize) / 2;
      return [
        Positioned(
          top: 0,
          left: topCenter,
          child: AvatarWidget(
            imageUrl: items.isNotEmpty ? items[0].imageUrl : null,
            name: items.isNotEmpty ? items[0].name : '?',
            size: childSize,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: AvatarWidget(
            imageUrl: items.length > 1 ? items[1].imageUrl : null,
            name: items.length > 1 ? items[1].name : '?',
            size: childSize,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: AvatarWidget(
            imageUrl: items.length > 2 ? items[2].imageUrl : null,
            name: items.length > 2 ? items[2].name : '?',
            size: childSize,
            borderWidth: border,
          ),
        ),
      ];
    }

    // 4 members or more
    final childSize = size * 0.50;
    final widgets = <Widget>[
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: AvatarWidget(
          imageUrl: items.isNotEmpty ? items[0].imageUrl : null,
          name: items.isNotEmpty ? items[0].name : '?',
          size: childSize,
          borderWidth: border,
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: AvatarWidget(
          imageUrl: items.length > 1 ? items[1].imageUrl : null,
          name: items.length > 1 ? items[1].name : '?',
          size: childSize,
          borderWidth: border,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: AvatarWidget(
          imageUrl: items.length > 2 ? items[2].imageUrl : null,
          name: items.length > 2 ? items[2].name : '?',
          size: childSize,
          borderWidth: border,
        ),
      ),
    ];

    if (totalCount > 4) {
      // Show remaining count in bottom-right
      final remainingCount = totalCount - 3;
      widgets.add(
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: childSize,
            height: childSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
              border: Border.all(color: Colors.white, width: border),
            ),
            alignment: Alignment.center,
            child: Text(
              '$remainingCount',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: childSize * 0.45,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    } else {
      // Bottom-right avatar (4 members case)
      widgets.add(
        Positioned(
          bottom: 0,
          right: 0,
          child: AvatarWidget(
            imageUrl: items.length > 3 ? items[3].imageUrl : null,
            name: items.length > 3 ? items[3].name : '?',
            size: childSize,
            borderWidth: border,
          ),
        ),
      );
    }

    return widgets;
  }
}
