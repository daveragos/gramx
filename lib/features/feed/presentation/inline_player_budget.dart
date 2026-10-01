import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Caps how many inline video players run at once, to bound decoder memory
/// and battery use. Players take a slot before initialising and release it
/// when they stop; a player without a slot shows its still preview.
class InlinePlayerBudget {
  /// The visible tile plus its neighbours.
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

  /// Returns a slot. Safe to call twice for the same player, since a widget
  /// can release on going off screen and again on dispose.
  void release() {
    if (_active > 0) _active--;
  }

  void reset() => _active = 0;
}

final inlinePlayerBudgetProvider = Provider<InlinePlayerBudget>(
  (ref) => InlinePlayerBudget(),
);
