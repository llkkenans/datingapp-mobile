import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FullscreenImageViewer extends StatelessWidget {
  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white38,
                  size: 48,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
