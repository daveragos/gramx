import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Plays an animated image on the clock rather than on the decoder.
///
/// An animated `Image` decodes each frame only once the previous one is on
/// screen, then waits for the next vsync to show it. When the app is busy —
/// starting up, signing in, pulling in the first channels, which are exactly
/// when the mark is on screen — that came to about two vsyncs a frame, and the
/// gramX mark's 1.4 s drawing took three seconds: slow motion. This decodes a
/// few frames ahead instead, which the phone manages faster than the
/// animation plays, and on each vsync shows the frame the clock says is due,
/// dropping any it is late for. A short stall costs a frame, never the pace.
///
/// A long one — the screen hidden, the app in the background — is not caught
/// up frame by frame: past [maxLag] the clock moves to wherever the animation
/// is, so it carries on from there instead of decoding its way through the
/// time it was away. Something that has to finish on time sets [maxLag] high
/// and skips instead.
///
/// Loops for as long as it runs, unless [stopAt] is set: then it stops on that
/// frame, keeps it on screen, and calls [onStopped].
class MarkPlayer {
  final String asset;
  final TickerProvider vsync;

  /// Receives each frame to show, and owns it from then on.
  final void Function(ui.Image image) onFrame;

  /// The frame to end on, counted from 0, or null to loop.
  final int? stopAt;

  /// Called once [stopAt] has been shown, or if the image cannot be played at
  /// all — whoever is waiting on the animation is not left waiting.
  final VoidCallback? onStopped;

  /// How far behind the clock playback may fall before the clock is moved to
  /// it, rather than frames being skipped to catch up.
  final Duration maxLag;

  MarkPlayer({
    required this.asset,
    required this.vsync,
    required this.onFrame,
    this.stopAt,
    this.onStopped,
    this.maxLag = const Duration(milliseconds: 250),
  });

  /// Frames decoded ahead of the one on screen.
  static const int _lookahead = 3;

  final ListQueue<({ui.Image image, int index, Duration at})> _queue =
      ListQueue();
  ui.Codec? _codec;
  Ticker? _ticker;
  int _decoded = 0;
  Duration _nextAt = Duration.zero;

  /// How much later than its own timeline the animation is being shown, from
  /// every time the clock was moved. See [maxLag].
  Duration _offset = Duration.zero;
  bool _decoding = false;
  bool _stopped = false;

  Future<void> start() async {
    try {
      final data = await rootBundle.load(asset);
      _codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('[MarkPlayer] Could not play $asset: $e');
      _finish();
      return;
    }
    if (_stopped) return;
    await _fill();
    if (_stopped) return;
    _ticker = vsync.createTicker(_tick)..start();
  }

  Future<void> _fill() async {
    final codec = _codec;
    if (_decoding || codec == null) return;
    _decoding = true;
    try {
      final last = stopAt;
      while (!_stopped &&
          _queue.length < _lookahead &&
          (last == null || _decoded <= last)) {
        // A codec wraps round to the first frame after the last, which is
        // the loop.
        final frame = await codec.getNextFrame();
        if (_stopped) {
          frame.image.dispose();
          break;
        }
        _queue.add((image: frame.image, index: _decoded, at: _nextAt));
        _nextAt += frame.duration;
        _decoded++;
      }
    } catch (e) {
      debugPrint('[MarkPlayer] $asset stopped playing: $e');
      _finish();
    } finally {
      _decoding = false;
    }
  }

  void _tick(Duration elapsed) {
    if (_queue.isNotEmpty && elapsed - _offset - _queue.first.at > maxLag) {
      _offset = elapsed - _queue.first.at;
    }
    final now = elapsed - _offset;

    ({ui.Image image, int index, Duration at})? due;
    while (_queue.isNotEmpty && _queue.first.at <= now) {
      // Late for this one: the next is due as well, so it is skipped.
      due?.image.dispose();
      due = _queue.removeFirst();
    }
    if (due != null) {
      onFrame(due.image);
      final last = stopAt;
      if (last != null && due.index >= last) {
        _finish();
        return;
      }
    }
    _fill();
  }

  void _finish() {
    if (_stopped) return;
    stop();
    onStopped?.call();
  }

  /// Stops playing and lets go of everything not yet shown. The frame on
  /// screen belongs to whoever [onFrame] gave it to.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _ticker?.dispose();
    _ticker = null;
    for (final frame in _queue) {
      frame.image.dispose();
    }
    _queue.clear();
    _codec?.dispose();
    _codec = null;
  }
}
