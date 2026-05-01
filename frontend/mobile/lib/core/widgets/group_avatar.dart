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
  final double size;

  const GroupAvatar({
    super.key,
    required this.members,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return AvatarWidget(name: 'G', size: size);
    }

    if (members.length == 1) {
      return AvatarWidget(
        imageUrl: members[0].imageUrl,
        name: members[0].name,
        size: size,
      );
    }

    final displayMembers = members.take(4).toList();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: _buildAvatarPositions(displayMembers),
      ),
    );
  }

  List<Widget> _buildAvatarPositions(List<({String? imageUrl, String name})> items) {
    // Border width cho từng avatar con — đủ để tạo gap thị giác
    const double border = 1.0;

    if (items.length == 2) {
      // 2 thành viên: đường chéo trên-trái / dưới-phải
      // Mỗi avatar chiếm 62% kích thước, offset 5% vào phía trong
      final childSize = size * 0.62;
      final offset = size * 0.05;
      return [
        Positioned(
          top: offset,
          left: offset,
          child: AvatarWidget(
            imageUrl: items[0].imageUrl,
            name: items[0].name,
            size: childSize,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: offset,
          right: offset,
          child: AvatarWidget(
            imageUrl: items[1].imageUrl,
            name: items[1].name,
            size: childSize,
            borderWidth: border,
          ),
        ),
      ];
    }

    if (items.length == 3) {
      // 3 thành viên: 1 ở trên giữa, 2 ở hàng dưới
      // Mỗi avatar ~54% size
      final childSize = size * 0.54;
      final topCenter = (size - childSize) / 2; // Căn giữa theo trục X
      return [
        Positioned(
          top: 0,
          left: topCenter,
          child: AvatarWidget(
            imageUrl: items[0].imageUrl,
            name: items[0].name,
            size: childSize,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: AvatarWidget(
            imageUrl: items[1].imageUrl,
            name: items[1].name,
            size: childSize,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: AvatarWidget(
            imageUrl: items[2].imageUrl,
            name: items[2].name,
            size: childSize,
            borderWidth: border,
          ),
        ),
      ];
    }

    // 4 thành viên trở lên: grid 2×2
    // Mỗi avatar chiếm đúng 50% kích thước, không gap thêm (border tạo khoảng cách)
    // Dùng size * 0.50 để lấp đầy, border 1.0px tạo viền trắng mỏng
    final childSize = size * 0.50;
    return [
      // Trên-trái
      Positioned(
        top: 0,
        left: 0,
        child: AvatarWidget(
          imageUrl: items[0].imageUrl,
          name: items[0].name,
          size: childSize,
          borderWidth: border,
        ),
      ),
      // Trên-phải
      Positioned(
        top: 0,
        right: 0,
        child: AvatarWidget(
          imageUrl: items[1].imageUrl,
          name: items[1].name,
          size: childSize,
          borderWidth: border,
        ),
      ),
      // Dưới-trái
      Positioned(
        bottom: 0,
        left: 0,
        child: AvatarWidget(
          imageUrl: items[2].imageUrl,
          name: items[2].name,
          size: childSize,
          borderWidth: border,
        ),
      ),
      // Dưới-phải
      Positioned(
        bottom: 0,
        right: 0,
        child: AvatarWidget(
          imageUrl: items[3].imageUrl,
          name: items[3].name,
          size: childSize,
          borderWidth: border,
        ),
      ),
    ];
  }
}
