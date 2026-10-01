import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/router.dart';
import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/app/widgets/mark_player.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// Where the launch draws the mark, and which frame of the drawing is the
/// finished ribbon.
abstract final class LaunchMark {
  /// The first frame of [BrandAssets.markAnimation] where the ribbon has
  /// finished forming, about 1.4 s in. The animation holds it for a second
  /// before rolling the ribbon away; the launch stops here instead, and opens
  /// the app through this frame.
  static const int formedFrame = 79;

  /// The finished ribbon's bounds inside the 276 × 429 animation canvas.
  static const Rect source = Rect.fromLTRB(8, 68, 268, 348);

  /// How tall the finished ribbon is on screen, centred.
  static const double height = 110;

  static double get width => height * source.width / source.height;

  /// A point inside the front panel, as a fraction of [source].
  ///
  /// The zoom is centred here. The front panel is solid, so once it has grown
  /// past the edges of the screen it covers all of it; a centre anywhere else
  /// would open onto the gap between the two panels.
  static const Offset anchor = Offset(0.34, 0.55);

  /// The longest the drawing may take to reach [formedFrame] before the app
  /// opens without it. The drawing itself takes 1.4 s; this is for a decode
  /// that never comes back, which must not keep the reader out of the app.
  static const Duration drawingLimit = Duration(seconds: 3);
}

/// The launch: the mark draws itself, and the app opens through it.
///
/// Android 12 and later hold a launch screen of their own until the app's
/// first frame; gramX's is plain black, because the drawing starts from
/// nothing and anything shown before it would have to vanish for the drawing
/// to begin. From the first frame this covers the app in the same black and
/// plays [BrandAssets.markAnimation] — a panel unfurling into the ribbon —
/// up to [LaunchMark.formedFrame], where the ribbon is finished.
///
/// When the ribbon is finished and the first screen has something on it, the
/// ribbon dips, then grows towards the reader, and as it grows it stops being
/// a picture and becomes a window: the black is cut away in the ribbon's
/// shape, the screen beneath shows through, and by the time the ribbon is
/// larger than the screen there is no black left. If the app is not ready
/// when the ribbon is, a sheen passes over it now and then while it waits.
///
/// "Something on it" is the feed's first posts for a signed-in reader, with a
/// short limit so a slow feed shows its own loading state rather than keeping
/// the mark up. Anywhere else — the sign-in screen, a guest, a link that
/// opened a post — is ready as soon as the router has left the splash.
///
/// With reduced motion there is no drawing and no zoom: the black fades.
class LaunchReveal extends ConsumerStatefulWidget {
  final Widget child;

  const LaunchReveal({super.key, required this.child});

  /// Longest the mark waits on the feed once the router has reached it.
  static const Duration feedPatience = Duration(milliseconds: 700);

  @override
  ConsumerState<LaunchReveal> createState() => _LaunchRevealState();
}

class _LaunchRevealState extends ConsumerState<LaunchReveal>
    with TickerProviderStateMixin {
  /// One sweep of the sheen and the rest before the next.
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  /// Repaints the cover each time the drawing moves on a frame.
  final ValueNotifier<ui.Image?> _frame = ValueNotifier(null);

  MarkPlayer? _drawing;
  Timer? _drawingLimit;

  GoRouterDelegate? _delegate;
  Timer? _patience;
  ProviderSubscription<AsyncValue<List<Post>>>? _feed;

  bool _started = false;
  bool _formed = false;
  bool _ready = false;
  bool _revealing = false;
  bool _done = false;

  /// The platform's reduce-motion setting, as of the last build.
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _delegate = ref.read(routerProvider).routerDelegate..addListener(_check);

    _reveal.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _sheen.stop();
      _stopDrawing();
      setState(() => _done = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Here rather than in initState: whether to draw at all depends on the
    // reduce-motion setting, which comes from the context.
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _formed = true;
    } else {
      _startDrawing();
    }
  }

  @override
  void dispose() {
    _delegate?.removeListener(_check);
    _patience?.cancel();
    _feed?.close();
    _stopDrawing();
    _frame.value?.dispose();
    _frame.dispose();
    _sheen.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _startDrawing() {
    _drawingLimit = Timer(LaunchMark.drawingLimit, _markFormed);
    _drawing = MarkPlayer(
      asset: BrandAssets.markAnimation,
      vsync: this,
      stopAt: LaunchMark.formedFrame,
      // The app opens when the ribbon is finished, so the drawing keeps to
      // time through start-up's stalls, dropping frames rather than pausing.
      maxLag: const Duration(seconds: 2),
      onFrame: (image) {
        _frame.value?.dispose();
        _frame.value = image;
      },
      onStopped: () {
        _stopDrawing();
        _markFormed();
      },
    )..start();
  }

  void _stopDrawing() {
    _drawingLimit?.cancel();
    _drawing?.stop();
    _drawing = null;
  }

  void _markFormed() {
    if (_formed || !mounted) return;
    _formed = true;
    if (_ready) {
      _open();
    } else {
      _sheen.repeat();
    }
  }

  /// Notes that the app is ready once the router has decided where it is
  /// going and, on the feed, once the feed has something to show.
  void _check() {
    if (_ready || !mounted) return;
    final configuration = _delegate?.currentConfiguration;
    if (configuration == null || configuration.isEmpty) return;

    final path = configuration.uri.path;
    if (path == SplashScreen.route) return;

    final waitsForFeed =
        path == ShellTab.home.path && !ref.read(isGuestModeProvider);
    if (!waitsForFeed) return _markReady();

    _feed ??= ref.listenManual(feedPostsProvider, (_, next) {
      if (next.value?.isNotEmpty ?? false) _markReady();
    }, fireImmediately: true);
    _patience ??= Timer(LaunchReveal.feedPatience, _markReady);
  }

  void _markReady() {
    if (_ready || !mounted) return;
    _ready = true;
    _patience?.cancel();
    _feed?.close();
    _feed = null;
    _delegate?.removeListener(_check);
    if (_formed) _open();
  }

  /// Starts the reveal. No `setState`: this can run from the router's own
  /// notification, in the middle of a build, and everything that changes from
  /// here on follows the animation instead.
  void _open() {
    if (_revealing || !mounted) return;
    _revealing = true;
    _sheen.stop();
    if (_reduceMotion) {
      _reveal.duration = const Duration(milliseconds: 200);
    }
    _reveal.forward();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.of(context).disableAnimations;

    // The app is always the first child, so finishing takes the cover away
    // without rebuilding anything underneath it.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            // Touches reach the app as soon as it starts to show through.
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, child) =>
                  IgnorePointer(ignoring: _reveal.value > 0, child: child),
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _LaunchPainter(
                    frame: _frame,
                    sheen: _sheen,
                    reveal: _reveal,
                    reduceMotion: _reduceMotion,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LaunchPainter extends CustomPainter {
  /// The drawing's current frame: the whole 276 × 429 canvas, of which
  /// [LaunchMark.source] is the finished ribbon.
  final ValueListenable<ui.Image?> frame;
  final Animation<double> sheen;
  final Animation<double> reveal;
  final bool reduceMotion;

  _LaunchPainter({
    required this.frame,
    required this.sheen,
    required this.reveal,
    required this.reduceMotion,
  }) : super(repaint: Listenable.merge([frame, sheen, reveal]));

  /// The share of the reveal spent on the dip, before the zoom.
  static const double _dip = 0.2;

  /// How far the ribbon has shrunk at the bottom of the dip.
  static const double _dipScale = 0.92;

  /// The zoom that covers a 460 × 1000 screen from [LaunchMark.anchor], with
  /// room to spare. Larger screens scale it up.
  static const double _zoomScale = 16;

  static final Paint _plain = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final t = reveal.value;

    if (reduceMotion) {
      canvas.drawRect(bounds, Paint()..color = _black(1 - t));
      return;
    }

    final home = Rect.fromCenter(
      center: bounds.center,
      width: LaunchMark.width,
      height: LaunchMark.height,
    );

    var scale = 1.0;
    var markOpacity = 1.0;
    var veilOpacity = 1.0;
    var zooming = false;
    if (t > 0) {
      if (t < _dip) {
        final dip = Curves.easeOut.transform(t / _dip);
        scale = ui.lerpDouble(1, _dipScale, dip)!;
      } else {
        zooming = true;
        final zoom = (t - _dip) / (1 - _dip);
        final reach =
            _zoomScale *
            math.max(1, math.max(size.width / 460, size.height / 1000));
        scale = ui.lerpDouble(
          _dipScale,
          reach,
          Curves.easeInCubic.transform(zoom),
        )!;
        // The ribbon's own colour goes early: it is becoming a window, and a
        // window is the shape of the thing, not its picture.
        markOpacity = 1 - Curves.easeOut.transform((zoom / 0.35).clamp(0, 1));
        // The last of the black goes at the end, for the soft edge the zoom
        // has stretched across the screen.
        veilOpacity = 1 - ((zoom - 0.7) / 0.3).clamp(0.0, 1.0);
      }
    }

    final anchor = Offset(
      home.left + home.width * LaunchMark.anchor.dx,
      home.top + home.height * LaunchMark.anchor.dy,
    );
    final ribbon = Rect.fromLTRB(
      anchor.dx + (home.left - anchor.dx) * scale,
      anchor.dy + (home.top - anchor.dy) * scale,
      anchor.dx + (home.right - anchor.dx) * scale,
      anchor.dy + (home.bottom - anchor.dy) * scale,
    );
    // The whole canvas, placed so that its finished ribbon lands on [ribbon].
    final pixel = ribbon.height / LaunchMark.source.height;
    final image = frame.value;
    final canvasRect = image == null
        ? Rect.zero
        : Rect.fromLTWH(
            ribbon.left - LaunchMark.source.left * pixel,
            ribbon.top - LaunchMark.source.top * pixel,
            image.width * pixel,
            image.height * pixel,
          );

    // The black, with the ribbon cut out of it once the zoom has begun.
    canvas.saveLayer(bounds, _plain);
    canvas.drawRect(bounds, Paint()..color = _black(veilOpacity));
    if (zooming && image != null) {
      _drawFrame(
        canvas,
        image,
        canvasRect,
        Paint()..blendMode = BlendMode.dstOut,
      );
    }
    canvas.restore();

    if (image != null && markOpacity > 0) {
      _drawFrame(
        canvas,
        image,
        canvasRect,
        Paint()..color = Color.fromRGBO(0, 0, 0, markOpacity),
      );
      if (t == 0) _drawSheen(canvas, image, canvasRect, ribbon);
    }
  }

  static void _drawFrame(Canvas canvas, ui.Image image, Rect to, Paint paint) {
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      to,
      paint..filterQuality = FilterQuality.low,
    );
  }

  /// A band of light across the ribbon, kept to the ribbon's own shape.
  void _drawSheen(Canvas canvas, ui.Image image, Rect canvasRect, Rect ribbon) {
    if (sheen.value == 0) return;

    // The sweep takes the first part of each cycle; the rest is a pause.
    const sweep = 0.55;
    final phase = sheen.value / sweep;
    if (phase >= 1) return;
    final travel = Curves.easeInOut.transform(phase);

    final band = ribbon.width * 0.45;
    final x = ui.lerpDouble(ribbon.left - band, ribbon.right + band, travel)!;
    final shader =
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.38),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromLTWH(x - band, ribbon.top, band * 2, ribbon.height),
        );

    canvas.saveLayer(ribbon, _plain);
    canvas.drawRect(ribbon, Paint()..shader = shader);
    _drawFrame(canvas, image, canvasRect, Paint()..blendMode = BlendMode.dstIn);
    canvas.restore();
  }

  static Color _black(double opacity) => Color.fromRGBO(0, 0, 0, opacity);

  @override
  bool shouldRepaint(_LaunchPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.reduceMotion != reduceMotion;
}
