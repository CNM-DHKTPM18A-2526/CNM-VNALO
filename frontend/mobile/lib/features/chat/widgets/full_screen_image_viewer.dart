import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final bool isLocal;
  final String? accessToken;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.isLocal,
    this.accessToken,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: isLocal
              ? Image.file(
                  File(imageUrl),
                  fit: BoxFit.contain,
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  httpHeaders: (accessToken != null && AvatarResolver.isInternalUrl(imageUrl))
                      ? {'Authorization': 'Bearer $accessToken'}
                      : const {},
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
        ),
      ),
    );
  }
}
