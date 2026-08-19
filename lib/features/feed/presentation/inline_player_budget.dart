import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Caps how many inline video players run at the same time.
///
/// Each GIF tile used to create a `VideoPlayerController`, loop it and play it
/// the moment it was built — for every GIF Flutter built, on screen or not. A
/// GIF-heavy feed spun up a decoder per tile, which is a battery and memory
/// problem on a surface people scroll for minutes.
///
/// Players ask for a slot before initialising and give it back when they stop.
/// Losing the race just means showing the still preview, which is the correct
/// fallback anyway.
class InlinePlayerBudget {
  /// Enough for the tile being read plus its neighbours, few enough that a
  /// fast scroll can't leave a dozen decoders running.
  static const int maxConcurrent = 3;

  int _active = 0;

  int get activeCount => _active;
  bool get hasCapacity => _active < maxConcurrent;

  /// Takes a slot if one is free. Returns false when the budget is spent.
  bool tryAcquire() {
    if (_active >= maxConcurrent) return false;
    _active++;
    return true;
  }

  /// Returns a slot. Safe to call more than once for the same player — a
  /// widget can be disposed after already releasing on going off screen.
  void release() {
    if (_active > 0) _active--;
  }

  void reset() => _active = 0;
}

final inlinePlayerBudgetProvider =
    Provider<InlinePlayerBudget>((ref) => InlinePlayerBudget());
