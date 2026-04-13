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
  final int cacheVersion;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.showOnline = false,
    this.cacheVersion = 0,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  static final RegExp _publicMediaPattern = RegExp(r'^(.*/media/)public/([^/?]+)(\?.*)?$');
  List<String> _candidates = const [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _refreshCandidates();
  }

  @override
  void didUpdateWidget(covariant AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheVersion != widget.cacheVersion) {
      _refreshCandidates();
    }
  }

  void _refreshCandidates() {
    final resolved = AvatarResolver.resolveUrl(widget.imageUrl);
    final withVersion = _appendCacheVersion(resolved, widget.cacheVersion);
    if (withVersion == null || withVersion.isEmpty) {
      _candidates = const [];
      _index = 0;
      return;
    }

    final fallbacks = <String>{withVersion};
    final match = _publicMediaPattern.firstMatch(withVersion);
    if (match != null) {
      final prefix = match.group(1)!;
      final mediaId = match.group(2)!;
      final query = match.group(3) ?? '';
      fallbacks.add('$prefix$mediaId/save$query');
    }

    _candidates = fallbacks.toList();
    _index = 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeUrl = _candidates.isEmpty ? null : _candidates[_index];
    final initials = AvatarUtils.getInitials(widget.name);
    final initialsBg = AvatarUtils.getColor(widget.name);
    final auth = context.watch<AuthProvider>();
    final token = auth.accessToken;

    return Stack(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipOval(
            child: activeUrl == null
                ? _initialsAvatar(initials, initialsBg)
                : CachedNetworkImage(
                    imageUrl: activeUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    httpHeaders: token != null
                        ? {'Authorization': 'Bearer $token'}
                        : const {},
                    placeholder: (_, __) =>
                        _initialsAvatar(initials, initialsBg),
                    errorWidget: (_, url, error) {
                      if (_index < _candidates.length - 1) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _index += 1);
                          }
                        });
                        return _initialsAvatar(initials, initialsBg);
                      }
                      debugPrint('[AvatarWidget] Error loading $url: $error');
                      return _initialsAvatar(initials, initialsBg);
                    },
                  ),
          ),
        ),
        if (widget.showOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: widget.size * 0.28,
              height: widget.size * 0.28,
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
