import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:vnalo_mobile/core/utils/avatar_utils.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedImage = AvatarResolver.resolveUrl(imageUrl);
    final initials = AvatarUtils.getInitials(name);
    final initialsBg = AvatarUtils.getColor(name);
    final auth = context.watch<AuthProvider>();
    final token = auth.accessToken;

    return Stack(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: ClipOval(
            child: resolvedImage == null
                ? _initialsAvatar(initials, initialsBg)
                : CachedNetworkImage(
                    imageUrl: resolvedImage,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    httpHeaders: token != null
                        ? {'Authorization': 'Bearer $token'}
                        : const {},
                    placeholder: (_, __) =>
                        _initialsAvatar(initials, initialsBg),
                    errorWidget: (_, url, error) {
                      debugPrint('[AvatarWidget] Error loading $url: $error');
                      return _initialsAvatar(initials, initialsBg);
                    },
                  ),
          ),
        ),
        if (showOnline)
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

  Widget _initialsAvatar(String initials, Color bg) {
    return Container(
      color: bg.withValues(alpha: 0.95),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
