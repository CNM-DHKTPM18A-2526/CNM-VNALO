import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:vnalo_mobile/core/utils/avatar_utils.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

class AvatarWidget extends StatefulWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnline;
  final bool isOnline;
  final DateTime? lastSeen;
  final int cacheVersion;
  final double? borderWidth;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.showOnline = false,
    this.isOnline = false,
    this.lastSeen,
    this.cacheVersion = 0,
    this.borderWidth,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheVersion != widget.cacheVersion) {
      _resolve();
    }
  }

  void _resolve() {
    final resolved = AvatarResolver.resolveUrl(widget.imageUrl);
    setState(() {
      _resolvedUrl = _appendCacheVersion(resolved, widget.cacheVersion);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeUrl = _resolvedUrl;
    final initials = AvatarUtils.getInitials(widget.name);
    final initialsBg = AvatarUtils.getColor(widget.name);
    final auth = context.watch<AuthProvider>();
    final token = auth.accessToken;

    return Stack(
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: widget.borderWidth != null && widget.borderWidth! > 0
                ? Border.all(
                    color: Colors.white,
                    width: widget.borderWidth!,
                  )
                : null,
          ),
          child: ClipOval(
            child: activeUrl == null
                ? _initialsAvatar(initials, initialsBg)
                : CachedNetworkImage(
                    imageUrl: activeUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    httpHeaders: (token != null && AvatarResolver.isInternalUrl(activeUrl))
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
        if (widget.showOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: widget.size * 0.25,
              height: widget.size * 0.25,
              decoration: BoxDecoration(
                color: widget.isOnline ? AppColors.online : Colors.grey.shade500,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode ? DarkColors.surface : Colors.white,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String? _appendCacheVersion(String? url, int version) {
    if (url == null || url.isEmpty || version <= 0) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final params = Map<String, String>.from(uri.queryParameters);
    params['av'] = version.toString();
    return uri.replace(queryParameters: params).toString();
  }

  Widget _initialsAvatar(String initials, Color bg) {
    return Container(
      color: bg.withValues(alpha: 0.95),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: widget.size * 0.36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
