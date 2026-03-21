import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnline;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.showOnline = false,
  });

  // This widget displays a user's avatar. If an image URL is provided, it shows the image.
  //Otherwise, it shows the first letter of the user's name. It also has an optional online status indicator.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [ // Avatar image or placeholder
        CircleAvatar(
          radius: size / 2,
          backgroundColor: AppColors.primary.withOpacity(0.2),
          backgroundImage:
              imageUrl != null ? CachedNetworkImageProvider(imageUrl!) : null,
          child:
              imageUrl == null // Show first letter of name if no image, otherwise show nothing (image will cover it)
                  ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                  : null,
        ),

        if (showOnline) // Show online status indicator
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
