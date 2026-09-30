import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/router.dart';
import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// The mark Android's launch screen shows, and where it shows it.
///
/// `android/app/src/main/res/drawable-nodpi/splash_mark.png` is cut from the
/// same artwork to the same numbers: [source] of [BrandAssets.markStatic],
/// [height] logical pixels tall, centred on black. Change one and the other
/// has to follow, or the mark jumps at the handover.
abstract final class LaunchMark {
  /// The ribbon's visible bounds inside the 276 × 429 artwork.
  static const Rect source = Rect.fromLTRB(8, 71, 268, 358);

  /// How tall the ribbon is on screen.
  static const double height = 110;

  static double get width => height * source.width / source.height;

  /// A point inside the front panel, as a fraction of the ribbon's bounds.
  ///
  /// The zoom is centred here. The front panel is solid, so once it has grown
  /// past the edges of the screen it covers all of it; a centre anywhere else
  /// would open onto the gap between the two panels.
  static const Offset anchor = Offset(0.35, 0.54);

  static ui.Image? _image;

  /// The decoded artwork, or null if it could not be had.
  static ui.Image? get image => _image;

  /// Decodes the artwork. Awaited before the first frame, so that frame can
  /// draw the mark Android's launch screen is showing.
  static Future<void> load() async {
    try {
      final data = await rootBundle.load(BrandAssets.markStatic);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _image = (await codec.getNextFrame()).image;
    } catch (e) {
      debugPrint('[Launch] Could not decode the mark: $e');
    }
  }
}

/// Carries Android's launch screen into the app, then opens the app through
/// the mark.
///
/// Android 12 and later hold a launch screen of their own until the first
/// frame: [LaunchMark] on black. This covers the app from that first frame
/// with exactly that picture, so the handover cannot be seen. While the app
/// works out where to go, a sheen passes over the ribbon now and then. When
/// the first screen has something on it, the ribbon dips, then grows towards
/// the reader, and as it grows it stops being a picture and becomes a window:
/// the black is cut away in the ribbon's shape, the screen beneath shows
/// through, and by the time the ribbon is larger than the screen there is no
/// black left.
///
/// "Something on it" is the feed's first posts for a signed-in reader, with a
/// short limit so a slow feed shows its own loading state rather than keeping
/// the mark up. Anywhere else — the sign-in screen, a guest, a link that
/// opened a post — opens as soon as the router has left the splash.
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

  GoRouterDelegate? _delegate;
  Timer? _sheenDelay;
  Timer? _patience;
  ProviderSubscription<AsyncValue<List<Post>>>? _feed;
  bool _revealing = false;
  bool _done = false;

  /// The platform's reduce-motion setting, as of the last build.
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _delegate = ref.read(routerProvider).routerDelegate..addListener(_check);

    // Not straight away: a launch that is already decided opens before the
    // sheen would have begun, and a sheen cut off halfway looks like a glitch.
    _sheenDelay = Timer(const Duration(milliseconds: 300), () {
      if (!_revealing) _sheen.repeat();
    });

    _reveal.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _sheen.stop();
      setState(() => _done = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _delegate?.removeListener(_check);
    _sheenDelay?.cancel();
    _patience?.cancel();
    _feed?.close();
    _sheen.dispose();
    _reveal.dispose();
    super.dispose();
  }

  /// Opens the app once the router has decided where it is going.
  void _check() {
    if (_revealing || !mounted) return;
    final configuration = _delegate?.currentConfiguration;
    if (configuration == null || configuration.isEmpty) return;

    final path = configuration.uri.path;
    if (path == SplashScreen.route) return;

    final waitsForFeed =
        path == ShellTab.home.path && !ref.read(isGuestModeProvider);
    if (!waitsForFeed) return _open();

    _feed ??= ref.listenManual(feedPostsProvider, (_, next) {
      if (next.value?.isNotEmpty ?? false) _open();
    }, fireImmediately: true);
    _patience ??= Timer(LaunchReveal.feedPatience, _open);
  }

  /// Starts the reveal. No `setState`: this can run from the router's own
  /// notification, in the middle of a build, and everything that changes from
  /// here on follows the animation instead.
  void _open() {
    if (_revealing || !mounted) return;
    _revealing = true;
    _sheenDelay?.cancel();
    _patience?.cancel();
    _feed?.close();
    _feed = null;
    _delegate?.removeListener(_check);

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
                    mark: LaunchMark.image,
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
  final ui.Image? mark;
  final Animation<double> sheen;
  final Animation<double> reveal;
  final bool reduceMotion;

  _LaunchPainter({
    required this.mark,
    required this.sheen,
    required this.reveal,
    required this.reduceMotion,
  }) : super(repaint: Listenable.merge([sheen, reveal]));

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
    final home = Rect.fromCenter(
      center: bounds.center,
      width: LaunchMark.width,
      height: LaunchMark.height,
    );
    final t = reveal.value;

    if (reduceMotion) {
      final opacity = 1 - t;
      canvas.drawRect(bounds, Paint()..color = _black(opacity));
      _drawMark(canvas, home, opacity);
      return;
    }

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
    final rect = Rect.fromLTRB(
      anchor.dx + (home.left - anchor.dx) * scale,
      anchor.dy + (home.top - anchor.dy) * scale,
      anchor.dx + (home.right - anchor.dx) * scale,
      anchor.dy + (home.bottom - anchor.dy) * scale,
    );

    // The black, with the ribbon cut out of it once the zoom has begun.
    canvas.saveLayer(bounds, _plain);
    canvas.drawRect(bounds, Paint()..color = _black(veilOpacity));
    final image = mark;
    if (zooming && image != null) {
      canvas.drawImageRect(
        image,
        LaunchMark.source,
        rect,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..filterQuality = FilterQuality.low,
      );
    }
    canvas.restore();

    if (markOpacity > 0) {
      _drawMark(canvas, rect, markOpacity);
      if (!zooming && t == 0) _drawSheen(canvas, rect);
    }
  }

  void _drawMark(Canvas canvas, Rect rect, double opacity) {
    final image = mark;
    if (image == null || opacity <= 0) return;
    canvas.drawImageRect(
      image,
      LaunchMark.source,
      rect,
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, opacity)
        ..filterQuality = FilterQuality.low,
    );
  }

  /// A band of light across the ribbon, kept to the ribbon's own shape.
  void _drawSheen(Canvas canvas, Rect rect) {
    final image = mark;
    if (image == null || sheen.value == 0) return;

    // The sweep takes the first part of each cycle; the rest is a pause.
    const sweep = 0.55;
    final phase = sheen.value / sweep;
    if (phase >= 1) return;
    final travel = Curves.easeInOut.transform(phase);

    final band = rect.width * 0.45;
    final x = ui.lerpDouble(rect.left - band, rect.right + band, travel)!;
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.38),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(x - band, rect.top, band * 2, rect.height));

    canvas.saveLayer(rect, _plain);
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.drawImageRect(
      image,
      LaunchMark.source,
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  static Color _black(double opacity) => Color.fromRGBO(0, 0, 0, opacity);

  @override
  bool shouldRepaint(_LaunchPainter oldDelegate) =>
      oldDelegate.mark != mark || oldDelegate.reduceMotion != reduceMotion;
}
