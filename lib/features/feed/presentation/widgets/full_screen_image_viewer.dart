import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/widgets/minithumbnail.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// One picture for the viewer. Until it downloads, the viewer watches
/// [fileId] and shows [minithumbnail].
@immutable
class ViewerImage {
  /// A local path, or an https URL in guest mode.
  final String? path;

  /// TDLib's file id; watching it also starts the download.
  final int? fileId;

  /// Telegram's inline blur preview (base64), sent with the message.
  final String? minithumbnail;

  /// A smaller size of the same photo, shown while the full one loads.
  final int? previewFileId;

  const ViewerImage({
    this.path,
    this.fileId,
    this.minithumbnail,
    this.previewFileId,
  });

  factory ViewerImage.of(MediaItem item, {String? downloadedPath}) =>
      ViewerImage(
        path: downloadedPath ?? item.localPath ?? item.url,
        fileId: item.fileId,
        minithumbnail: item.minithumbnail,
        previewFileId: item.type == MediaType.photo
            ? item.thumbnailFileId
            : null,
      );

  /// Whether this is worth opening at all.
  bool get hasSource =>
      (path != null && path!.isNotEmpty) || (fileId != null && fileId != 0);
}

/// Full-screen immersive image gallery with pinch zoom and swipe paging.
class FullScreenImageViewer extends StatefulWidget {
  final List<ViewerImage> items;
  final int initialIndex;
  final String tag;

  /// The post these images belong to, for the viewer's header and actions.
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
    required List<ViewerImage> items,
    int initialIndex = 0,
    required String tag,
    Post? post,
  }) {
    if (items.isEmpty) return;
    // Root navigator, so the viewer covers the shell's bottom bar.
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
  /// Zoom bounds. A picture never shrinks below the screen.
  static const double _minScale = 1;
  static const double _maxScale = 8;

  /// Zoom after a double tap, enough to read small text in a screenshot.
  static const double _doubleTapScale = 2.5;

  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformControllers = {};
  bool _showChrome = true;

  /// Whether the current page is zoomed, so a drag pans instead.
  bool _isZoomed = false;

  /// Fingers down, counted outside the gesture arena so paging stops when a
  /// second finger lands; otherwise the `PageView` would steal pinches.
  int _pointers = 0;

  /// Where the last double tap landed, so the zoom centres there.
  Offset? _doubleTapAt;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
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

  double _scaleOf(int index) => _getController(index).value.getMaxScaleOnAxis();

  void _syncZoomState(int index) {
    final zoomed = _scaleOf(index) > 1.01;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _setPointers(int count) {
    // Clamped at zero so a stray cancel can't lock swiping.
    final next = count < 0 ? 0 : count;
    if (next == _pointers) return;
    setState(() => _pointers = next);
  }

  /// Settles the picture on release, since `minScale` doesn't bound the pan.
  void _onInteractionEnd(int index) {
    final controller = _getController(index);
    if (_scaleOf(index) <= 1.01) {
      controller.value = Matrix4.identity();
    } else {
      controller.value = keepCoveringViewport(
        controller.value,
        MediaQuery.sizeOf(context),
      );
    }
    _syncZoomState(index);
  }

  void _handleDoubleTap(int index) {
    final controller = _getController(index);

    if (controller.value != Matrix4.identity()) {
      controller.value = Matrix4.identity();
    } else {
      // Scale about the tapped point so it stays under the finger.
      final at = _doubleTapAt ?? Offset.zero;
      const scale = _doubleTapScale;
      controller.value = Matrix4.identity()
        ..translateByDouble(at.dx * (1 - scale), at.dy * (1 - scale), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _syncZoomState(index);
  }

  /// The downloaded file for the page on screen, or null while it is arriving.
  String? _localPathForCurrentPage;

  void _onCurrentPageResolved(String? path) {
    if (!mounted || path == _localPathForCurrentPage) return;
    setState(() => _localPathForCurrentPage = path);
  }

  @override
  Widget build(BuildContext context) {
    final imageOwnsGesture = _pointers > 1 || _isZoomed;

    return MediaViewerChrome(
      post: widget.post,
      showChrome: _showChrome,
      localPath: _localPathForCurrentPage,
      pageIndicator: MediaPageDots(
        count: widget.items.length,
        index: _currentIndex,
      ),
      child: DragToDismiss(
        enabled: !imageOwnsGesture,
        child: Listener(
          onPointerDown: (_) => _setPointers(_pointers + 1),
          onPointerUp: (_) => _setPointers(_pointers - 1),
          onPointerCancel: (_) => _setPointers(_pointers - 1),
          child: PageView.builder(
            controller: _pageController,
            physics: imageOwnsGesture
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.items.length,
            onPageChanged: (index) => setState(() {
              _currentIndex = index;
              _isZoomed = _scaleOf(index) > 1.01;
              // Cleared until the new page reports its own file.
              _localPathForCurrentPage = null;
            }),
            itemBuilder: (context, index) {
              final item = widget.items[index];

              return GestureDetector(
                // Opaque so taps on the black around the photo count too.
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showChrome = !_showChrome),
                onDoubleTapDown: (details) =>
                    _doubleTapAt = details.localPosition,
                onDoubleTap: () => _handleDoubleTap(index),
                child: InteractiveViewer(
                  transformationController: _getController(index),
                  clipBehavior: Clip.none,
                  // At 1:1 a drag pages or dismisses rather than panning.
                  panEnabled: _isZoomed,
                  // Unbounded; _onInteractionEnd settles it afterwards.
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: _minScale,
                  maxScale: _maxScale,
                  trackpadScrollCausesScale: true,
                  // Live, so paging locks as soon as the scale moves.
                  onInteractionUpdate: (_) => _syncZoomState(index),
                  onInteractionEnd: (_) => _onInteractionEnd(index),
                  child: Center(
                    child: Hero(
                      tag: index == widget.initialIndex
                          ? widget.tag
                          : '${widget.tag}_$index',
                      child: _ViewerImage(
                        item: item,
                        // Only the page on screen reports its file.
                        onResolved: index == _currentIndex
                            ? _onCurrentPageResolved
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// [transform] with its translation clamped so the zoomed picture still
/// covers [viewport]: each axis is limited to `[viewport * (1 - scale), 0]`.
Matrix4 keepCoveringViewport(Matrix4 transform, Size viewport) {
  final scale = transform.getMaxScaleOnAxis();
  final translation = transform.getTranslation();
  final minX = viewport.width * (1 - scale);
  final minY = viewport.height * (1 - scale);
  final x = translation.x.clamp(minX > 0 ? 0.0 : minX, 0.0);
  final y = translation.y.clamp(minY > 0 ? 0.0 : minY, 0.0);
  if (x == translation.x && y == translation.y) return transform;
  return transform.clone()..setTranslationRaw(x, y, translation.z);
}

/// One full-screen picture, from a guest URL or a TDLib download. Shown as
/// broken only when there is nothing left to wait for.
class _ViewerImage extends ConsumerWidget {
  final ViewerImage item;

  /// Reports the resolved file, for the chrome's "open with" action.
  final ValueChanged<String?>? onResolved;

  const _ViewerImage({required this.item, this.onResolved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileId = item.fileId;
    FileDownloadProgressState? download;
    if (fileId != null && fileId != 0) {
      // The progress provider also starts the download.
      download = ref.watch(fileDownloadProgressProvider(fileId)).value;
    }

    final resolved =
        download?.localPath ?? resolveMediaPath(ref, rawPath: item.path);

    // After the frame, since `build` must not write state.
    final report = onResolved;
    if (report != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => report(resolved));
    }

    // The photo's small size, which comes long before the full one.
    final previewId = item.previewFileId;
    final hasPreview =
        previewId != null && previewId != 0 && previewId != fileId;

    if (resolved != null && resolved.isNotEmpty) {
      final file = File(resolved);
      if (file.existsSync()) {
        final full = Image.file(
          file,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          frameBuilder: fadeInFrame,
          errorBuilder: (_, _, _) => const _BrokenImage(),
        );
        // Fades in over the small size if that was showing, rather than
        // over black. One already on screen was fetched while this loaded.
        final preview =
            hasPreview && ref.exists(fileDownloadProgressProvider(previewId))
            ? ref
                  .watch(fileDownloadProgressProvider(previewId))
                  .value
                  ?.localPath
            : null;
        if (preview == null) return full;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(preview),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            full,
          ],
        );
      }
    }

    // Still downloading.
    final isRemote =
        item.path != null &&
        (item.path!.startsWith('http://') || item.path!.startsWith('https://'));
    if (download != null || isRemote) {
      final preview = hasPreview
          ? ref.watch(fileDownloadProgressProvider(previewId)).value?.localPath
          : null;
      return _LoadingImage(
        minithumbnail: item.minithumbnail,
        previewPath: preview,
        progress: download?.progress ?? 0,
      );
    }

    return const _BrokenImage();
  }
}

/// A loading picture: the photo's small size once it's in, sharpening into
/// the full one, and before that Telegram's blur preview. A progress ring
/// shows only while there is nothing of the photo to see.
class _LoadingImage extends StatelessWidget {
  final String? minithumbnail;
  final String? previewPath;
  final double progress;

  const _LoadingImage({
    required this.minithumbnail,
    required this.previewPath,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final blurProvider = Minithumbnail.provider(minithumbnail);
    final blur = blurProvider == null
        ? null
        : Image(
            image: blurProvider,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
    final previewPath = this.previewPath;

    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        ?blur,
        if (previewPath != null)
          Image.file(
            File(previewPath),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            frameBuilder: fadeInFrame,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        else if (blur == null)
          Center(
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              color: Colors.white,
              backgroundColor: Colors.white24,
              strokeWidth: 3,
            ),
          ),
      ],
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
    );
  }
}
