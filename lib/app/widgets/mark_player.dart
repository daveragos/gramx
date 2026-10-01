import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Plays an animated image by wall-clock time, unlike an animated `Image`,
/// which slows down when the app is busy. Decodes a few frames ahead and drops
/// late ones. Loops unless [stopAt] is set.
class MarkPlayer {
  final String asset;
  final TickerProvider vsync;

  /// Receives each frame to show, and owns it from then on.
  final void Function(ui.Image image) onFrame;

  /// The frame to end on, counted from 0, or null to loop.
  final int? stopAt;

  /// Called once [stopAt] has been shown, or if the image cannot be played.
  final VoidCallback? onStopped;

  /// How far playback may fall behind before the clock is moved instead of
  /// skipping frames.
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

  /// Total shift applied to the clock. See [maxLag].
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
        // The codec wraps to the first frame after the last.
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
      // Skip frames that are already late.
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

  /// Stops and disposes frames not yet shown.
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
