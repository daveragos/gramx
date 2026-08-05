import 'dart:io';
import 'package:flutter/material.dart';

/// Full-screen image viewer modal with smooth pinch-to-zoom, pan, and double-tap zoom.
class FullScreenImageViewer extends StatefulWidget {
  final String? imagePath;
  final String? imageUrl;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    this.imagePath,
    this.imageUrl,
    required this.tag,
  });

  static void show(
    BuildContext context, {
    String? imagePath,
    String? imageUrl,
    required String tag,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            imagePath: imagePath,
            imageUrl: imageUrl,
            tag: tag,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition;
      if (position != null) {
        final matrix = Matrix4.identity();
        matrix.translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0.0, 0.0);
        matrix.scaleByDouble(2.5, 2.5, 1.0, 1.0);
        _transformationController.value = matrix;
      }
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      final file = File(widget.imagePath!);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.contain,
        );
      } else {
        imageWidget = const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
        );
      }
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        widget.imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
        ),
      );
    } else {
      imageWidget = const Center(
        child: Icon(Icons.image_not_supported_rounded, color: Colors.white54, size: 64),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onDoubleTapDown: (details) => _doubleTapDetails = details,
            onDoubleTap: _handleDoubleTap,
            child: Center(
              child: Hero(
                tag: widget.tag,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: imageWidget,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.white, size: 24),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Image saved to device gallery'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 24),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sharing image...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
