import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// One picture, described the way the viewer needs it rather than as a path.
///
/// A path alone was the bug behind "tapping a loading image shows a broken
/// image icon": signed in, a photo that has not been downloaded yet has no
/// path — the grid hands over TDLib's remote id or the numeric file id,
/// because that is all `MediaItem.url` holds until the bytes land. The viewer
/// then did `File(thatString).existsSync()`, got false, and drew the broken
/// glyph over a picture that was merely still arriving.
///
/// Carrying the [fileId] instead lets the viewer *wait*: it watches the same
/// download the grid watches, shows the blurred [minithumbnail] Telegram ships
/// inside the message meanwhile, and swaps in the real file when it lands.
@immutable
class ViewerImage {
  /// A local path, or an https URL in guest mode. Null when only [fileId] is
  /// known.
  final String? path;

  /// TDLib's file id, when there is one. Watching it both reports progress and
  /// starts the download if nothing else has.
  final int? fileId;

  /// Telegram's inline blur preview, base64. A few hundred bytes that arrive
  /// with the message itself, so there is something to look at immediately.
  final String? minithumbnail;

  const ViewerImage({this.path, this.fileId, this.minithumbnail});

  /// The viewer entry for a photo in a post.
  factory ViewerImage.of(MediaItem item, {String? downloadedPath}) =>
      ViewerImage(
        path: downloadedPath ?? item.localPath ?? item.url,
        fileId: item.fileId,
        minithumbnail: item.minithumbnail,
      );

  /// Whether this is worth opening at all.
  bool get hasSource =>
      (path != null && path!.isNotEmpty) || (fileId != null && fileId != 0);
}

/// Full-screen multi-image gallery viewer with immersive system UI hiding,
/// pinch zoom, swipe page view and a bottom counter pill.
class FullScreenImageViewer extends StatefulWidget {
  final List<ViewerImage> items;
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
    required List<ViewerImage> items,
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
  /// Zoom bounds. The floor is 1: letting a picture shrink below the screen
  /// only ever happened by accident, and it made every pinch feel loose.
  static const double _minScale = 1;
  static const double _maxScale = 8;

  /// Where a double tap lands you. Deep enough to read small text in a
  /// screenshot, shallow enough that one more pinch is not required.
  static const double _doubleTapScale = 2.5;

  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformControllers = {};
  bool _showChrome = true;

  /// Whether the current page is scaled past 1:1, which changes what a drag
  /// means — panning the picture rather than closing the viewer.
  bool _isZoomed = false;

  /// Fingers currently on the screen.
  ///
  /// This is the whole fix for "pinching is a struggle". A `PageView` and an
  /// `InteractiveViewer` are both in the gesture arena, and the page's
  /// horizontal drag recogniser wins on the smallest sideways movement — which
  /// every two-finger pinch has. So a pinch was read as a swipe, the page
  /// flicked instead of zooming, and the reader had to find the one gesture
  /// pure enough not to be stolen.
  ///
  /// A `Listener` sits outside the arena and simply counts pointers, so the
  /// moment a second finger lands the page stops scrolling and the zoom has
  /// the gesture to itself.
  int _pointers = 0;

  /// Where the last double tap landed, so the zoom goes *there* rather than to
  /// the middle of a picture the reader was not looking at.
  Offset? _doubleTapAt;

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

  double _scaleOf(int index) => _getController(index).value.getMaxScaleOnAxis();

  void _syncZoomState(int index) {
    final zoomed = _scaleOf(index) > 1.01;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _setPointers(int count) {
    if (count == _pointers) return;
    setState(() => _pointers = count);
  }

  /// Snaps a picture back into place once the fingers leave.
  ///
  /// `minScale` clamps the zoom but not the pan, so a picture nudged sideways
  /// at 1:1 stays nudged — off-centre, with a black gutter down one side, and
  /// no obvious way back. At rest and unzoomed there is only one right
  /// position, so it takes it.
  void _onInteractionEnd(int index) {
    if (_scaleOf(index) <= 1.01) {
      _getController(index).value = Matrix4.identity();
    }
    _syncZoomState(index);
  }

  void _handleDoubleTap(int index) {
    final controller = _getController(index);

    if (controller.value != Matrix4.identity()) {
      controller.value = Matrix4.identity();
    } else {
      // Keep the tapped point where it is: scaling about the origin would slide
      // whatever the reader aimed at off the screen.
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
    // Either a second finger or an already-zoomed picture means this gesture
    // belongs to the image, not to the gallery.
    final imageOwnsGesture = _pointers > 1 || _isZoomed;

    return MediaViewerChrome(
      post: widget.post,
      showChrome: _showChrome,
      // The picture being *looked at*, not the one the viewer opened on — the
      // button has to follow the page. Resolved through a Consumer because
      // this State has no `ref` of its own, and only the current page's file
      // is watched, so swiping does not subscribe to the whole album.
      localPath: _localPathForCurrentPage,
      pageIndicator: MediaPageDots(
        count: widget.items.length,
        index: _currentIndex,
      ),
      child: DragToDismiss(
        // A zoomed image pans instead; dismissing from under the reader's
        // finger while they are inspecting a detail would be maddening.
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
              // Dropped until the new page reports its own, so the button can
              // never hand out the picture the reader just swiped away from.
              _localPathForCurrentPage = null;
            }),
            itemBuilder: (context, index) {
              final item = widget.items[index];

              return GestureDetector(
                // Opaque so a tap on the black around a portrait photo counts
                // too — the furniture is what the reader is aiming at.
                behavior: HitTestBehavior.opaque,
                // A single tap clears the furniture so the picture can be
                // looked at on its own.
                onTap: () => setState(() => _showChrome = !_showChrome),
                onDoubleTapDown: (details) =>
                    _doubleTapAt = details.localPosition,
                onDoubleTap: () => _handleDoubleTap(index),
                child: InteractiveViewer(
                  transformationController: _getController(index),
                  clipBehavior: Clip.none,
                  // Unbounded, so a zoomed picture can be dragged right to its
                  // own corner. The default pins the child's edges to the
                  // viewport, which is what made panning feel stuck halfway.
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: _minScale,
                  maxScale: _maxScale,
                  trackpadScrollCausesScale: true,
                  // Live, not just at the end: the page has to lock the instant
                  // the scale moves, or the first frames of a pinch still read
                  // as a swipe.
                  onInteractionUpdate: (_) => _syncZoomState(index),
                  onInteractionEnd: (_) => _onInteractionEnd(index),
                  child: Center(
                    child: Hero(
                      tag: index == widget.initialIndex
                          ? widget.tag
                          : '${widget.tag}_$index',
                      child: _ViewerImage(
                        item: item,
                        // Only the page actually on screen reports, so
                        // swiping does not have every page in the album
                        // racing to set the button's target.
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

/// One full-screen picture, from either source and at any stage of arriving.
///
/// The viewer used to do `Image.file(File(pathOrUrl))` on whatever string it
/// was handed, with a comment asserting media "always arrives from TDLib as a
/// local file". Two things broke that. Guest mode carries `t.me` URLs, so
/// `File('https://…')` never existed; and a signed-in photo that has not
/// finished downloading carries a remote id or a bare file id, which is not a
/// path either. Both ended on the broken-image glyph, one of them for a
/// picture that would have arrived a second later.
///
/// So: resolve the URL through the guest cache, watch the file id for a
/// download in flight, and only call something broken when there is genuinely
/// nothing left to wait for.
class _ViewerImage extends ConsumerWidget {
  final ViewerImage item;

  /// Reports the file this page resolved, so the chrome's "open with" can hand
  /// out the exact one on screen. A callback rather than a second resolution
  /// up top: the page already knows, and two answers can disagree.
  final ValueChanged<String?>? onResolved;

  const _ViewerImage({required this.item, this.onResolved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileId = item.fileId;
    FileDownloadProgressState? download;
    if (fileId != null && fileId != 0) {
      // The *progress* provider, not the status one: opening a picture is the
      // request for it, so this both reports and starts the download.
      download = ref.watch(fileDownloadProgressProvider(fileId)).value;
    }

    final resolved =
        download?.localPath ?? resolveMediaPath(ref, rawPath: item.path);

    // Reported after the frame, never during it: `build` must not write state.
    final report = onResolved;
    if (report != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => report(resolved));
    }

    if (resolved != null && resolved.isNotEmpty) {
      final file = File(resolved);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _BrokenImage(),
        );
      }
    }

    // Still coming. The grid showed something a moment ago, so "broken" would
    // be a lie — this is a wait, not a failure.
    final isRemote =
        item.path != null &&
        (item.path!.startsWith('http://') || item.path!.startsWith('https://'));
    if (download != null || isRemote) {
      return _LoadingImage(
        minithumbnail: item.minithumbnail,
        progress: download?.progress ?? 0,
      );
    }

    return const _BrokenImage();
  }
}

/// What a picture looks like while its bytes are on the way: Telegram's own
/// blur preview, if the message carried one, under a progress ring.
class _LoadingImage extends StatelessWidget {
  final String? minithumbnail;
  final double progress;

  const _LoadingImage({required this.minithumbnail, required this.progress});

  @override
  Widget build(BuildContext context) {
    Widget? blur;
    final raw = minithumbnail;
    if (raw != null && raw.isNotEmpty) {
      try {
        blur = Image.memory(base64Decode(raw), fit: BoxFit.contain);
      } catch (_) {
        blur = null;
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ?blur,
        CircularProgressIndicator(
          value: progress > 0 ? progress : null,
          color: Colors.white,
          backgroundColor: Colors.white24,
          strokeWidth: 3,
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
