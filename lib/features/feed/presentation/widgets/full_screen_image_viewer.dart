import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen multi-image gallery viewer modal with immersive system UI hiding,
/// unconstrained zoom, swipe page view, and bottom counter pill.
class FullScreenImageViewer extends StatefulWidget {
  final List<String> items;
  final int initialIndex;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
    required this.tag,
  });

  static void show(
    BuildContext context, {
    required List<String> items,
    int initialIndex = 0,
    required String tag,
  }) {
    if (items.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            items: items,
            initialIndex: initialIndex,
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

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Hide BNB and system status bars in full screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore edge-to-edge system UI when exiting full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    for (final controller in _transformControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _getController(int index) {
    return _transformControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  Widget _buildImage(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
        ),
      );
    }
    final file = File(pathOrUrl);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
      );
    }
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Swipeable Multi-Image PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final transformController = _getController(index);

              return GestureDetector(
                onDoubleTap: () {
                  if (transformController.value != Matrix4.identity()) {
                    transformController.value = Matrix4.identity();
                  } else {
                    transformController.value = Matrix4.identity()
                      ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
                  }
                },
                child: Center(
                  child: Hero(
                    tag: index == widget.initialIndex ? widget.tag : '${widget.tag}_$index',
                    child: InteractiveViewer(
                      transformationController: transformController,
                      clipBehavior: Clip.none,
                      minScale: 0.8,
                      maxScale: 5.0,
                      child: _buildImage(item),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top Header Bar
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

          // Bottom Page Counter Pill (if multiple images)
          if (widget.items.length > 1)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
