/// Reaction counts plus which of them are the user's own.
class ReactionState {
  final Map<String, int> reactions;
  final Set<String> chosen;

  const ReactionState({required this.reactions, required this.chosen});

  /// The reaction the user currently has on this post, if any.
  String? get current => chosen.isEmpty ? null : chosen.first;

  @override
  bool operator ==(Object other) =>
      other is ReactionState &&
      _sameCounts(other.reactions) &&
      other.chosen.length == chosen.length &&
      other.chosen.containsAll(chosen);

  bool _sameCounts(Map<String, int> other) {
    if (other.length != reactions.length) return false;
    for (final entry in reactions.entries) {
      if (other[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      reactions.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(chosen),
  );

  @override
  String toString() => 'ReactionState($reactions, chosen: $chosen)';
}

/// Applies the user tapping [emoji], matching Telegram's behaviour. A
/// non-premium account holds one reaction per message, so a new one replaces
/// the old. Tapping the current reaction removes it.
ReactionState applyReactionChoice({
  required Map<String, int> reactions,
  required Set<String> chosen,
  required String emoji,
}) {
  final counts = Map<String, int>.from(reactions);

  void decrement(String key) {
    final next = (counts[key] ?? 1) - 1;
    if (next <= 0) {
      counts.remove(key);
    } else {
      counts[key] = next;
    }
  }

  // Tapping the current reaction clears it.
  if (chosen.contains(emoji)) {
    decrement(emoji);
    return ReactionState(reactions: counts, chosen: const {});
  }

  // Otherwise the previous choice, if any, is replaced.
  for (final previous in chosen) {
    decrement(previous);
  }
  counts[emoji] = (counts[emoji] ?? 0) + 1;

  return ReactionState(reactions: counts, chosen: {emoji});
}
