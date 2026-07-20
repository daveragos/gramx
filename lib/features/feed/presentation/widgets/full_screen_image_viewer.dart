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

  static void show(BuildContext context, {String? imagePath, String? imageUrl, required String tag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.9),
        pageBuilder: (context, _, __) {
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
        _transformationController.value = Matrix4.identity()
          ..translate(-position.dx * 1.5, -position.dy * 1.5)
          ..scale(2.5);
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
        errorBuilder: (_, __, ___) => const Center(
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
          // Top bar close button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
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
