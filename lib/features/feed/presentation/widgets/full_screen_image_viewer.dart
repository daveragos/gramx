import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';

/// Full-screen multi-image gallery viewer modal with immersive system UI hiding,
/// unconstrained zoom, swipe page view, and bottom counter pill.
class FullScreenImageViewer extends StatefulWidget {
  final List<String> items;
  final int initialIndex;
  final String tag;

  /// The post these images belong to, so the viewer carries its identity and
  /// actions instead of leaving the reader on a bare black screen.
  final Post? post;

  const FullScreenImageViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
    required this.tag,
    this.post,
  });

  static void show(
    BuildContext context, {
    required List<String> items,
    int initialIndex = 0,
    required String tag,
    Post? post,
  }) {
    if (items.isEmpty) return;
    // Root navigator: a branch's own navigator sits *under* the shell's bottom
    // bar, so the viewer opened with the tab bar still painted over the photo.
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            items: items,
            initialIndex: initialIndex,
            tag: tag,
            post: post,
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
  bool _showChrome = true;

  /// Whether the current page is scaled past 1:1, which changes what a drag
  /// means — panning the picture rather than closing the viewer.
  bool _isZoomed = false;

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

  void _syncZoomState(int index) {
    final scale = _getController(index).value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  TransformationController _getController(int index) {
    return _transformControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  /// Media always arrives from TDLib as a local file, never as a URL this app
  /// would fetch itself — see the note in `link_preview_card.dart`.
  Widget _buildImage(String pathOrUrl) {
    final file = File(pathOrUrl);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.contain);
    }
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaViewerChrome(
      post: widget.post,
      showChrome: _showChrome,
      pageIndicator: MediaPageDots(
        count: widget.items.length,
        index: _currentIndex,
      ),
      child: DragToDismiss(
        // A zoomed image pans instead; dismissing from under the reader's
        // finger while they are inspecting a detail would be maddening.
        enabled: !_isZoomed,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.items.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final transformController = _getController(index);

            return GestureDetector(
              // A single tap clears the furniture so the picture can be
              // looked at on its own.
              onTap: () => setState(() => _showChrome = !_showChrome),
              onDoubleTap: () {
                if (transformController.value != Matrix4.identity()) {
                  transformController.value = Matrix4.identity();
                } else {
                  transformController.value = Matrix4.identity()
                    ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
                }
                _syncZoomState(index);
              },
              child: Center(
                child: Hero(
                  tag: index == widget.initialIndex
                      ? widget.tag
                      : '${widget.tag}_$index',
                  child: InteractiveViewer(
                    transformationController: transformController,
                    clipBehavior: Clip.none,
                    minScale: 0.8,
                    maxScale: 5.0,
                    onInteractionEnd: (_) => _syncZoomState(index),
                    child: _buildImage(item),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
