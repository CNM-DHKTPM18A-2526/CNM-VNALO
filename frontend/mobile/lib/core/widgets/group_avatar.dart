import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';

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
      return AvatarWidget(name: 'Group', size: size);
    }
    
    if (members.length == 1) {
      return AvatarWidget(
        imageUrl: members[0].imageUrl,
        name: members[0].name,
        size: size,
      );
    }

    // Logic for composite avatar
    // Zalo style: typically 3-4 avatars in a cluster
    final displayMembers = members.take(4).toList();
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: _buildAvatarPositions(displayMembers),
      ),
    );
  }

  List<Widget> _buildAvatarPositions(List<({String? imageUrl, String name})> items) {
    const double border = 1.5;
    if (items.length == 2) {
      return [
        Positioned(
          top: size * 0.05,
          left: size * 0.05,
          child: AvatarWidget(
            imageUrl: items[0].imageUrl,
            name: items[0].name,
            size: size * 0.62,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: size * 0.05,
          right: size * 0.05,
          child: AvatarWidget(
            imageUrl: items[1].imageUrl,
            name: items[1].name,
            size: size * 0.62,
            borderWidth: border,
          ),
        ),
      ];
    }

    if (items.length == 3) {
      return [
        Positioned(
          top: 0,
          left: size * 0.22,
          child: AvatarWidget(
            imageUrl: items[0].imageUrl,
            name: items[0].name,
            size: size * 0.54,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: size * 0.05,
          left: 0,
          child: AvatarWidget(
            imageUrl: items[1].imageUrl,
            name: items[1].name,
            size: size * 0.54,
            borderWidth: border,
          ),
        ),
        Positioned(
          bottom: size * 0.05,
          right: 0,
          child: AvatarWidget(
            imageUrl: items[2].imageUrl,
            name: items[2].name,
            size: size * 0.54,
            borderWidth: border,
          ),
        ),
      ];
    }

    // 4 or more
    return [
      Positioned(
        top: 0,
        left: 0,
        child: AvatarWidget(
          imageUrl: items[0].imageUrl,
          name: items[0].name,
          size: size * 0.48,
          borderWidth: border,
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: AvatarWidget(
          imageUrl: items[1].imageUrl,
          name: items[1].name,
          size: size * 0.48,
          borderWidth: border,
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: AvatarWidget(
          imageUrl: items[2].imageUrl,
          name: items[2].name,
          size: size * 0.48,
          borderWidth: border,
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: AvatarWidget(
          imageUrl: items[3].imageUrl,
          name: items[3].name,
          size: size * 0.48,
          borderWidth: border,
        ),
      ),
    ];
  }
}
