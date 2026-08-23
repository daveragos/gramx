/// Which channels are hidden from the feed, and until when.
///
/// Lives beside the notifier rather than in `domain/` for the same reason
/// `FeedFocusTracker` does: it is policy, not a model.
///
/// Pure state and rules, no I/O and no clock of its own — every question takes
/// the time to answer it at. `MutedChannelsNotifier` owns persistence and the
/// timer that prunes expirations; this owns what "muted" means.
///
/// A channel answers to several ids depending on where it was learned from —
/// the chat id, the `-100`-prefixed form, the bare supergroup id, the username
/// — so a mute is stored against every one of them. Storing only the id that
/// happened to be at hand is why a channel muted from its profile could read as
/// unmuted in the list.
class MuteRegistry {
  /// Alias id → when the mute lifts. A null value means "until I say so".
  final Map<String, DateTime?> _entries;

  MuteRegistry([Map<String, DateTime?>? entries])
      : _entries = {...?entries};

  /// Every id currently recorded, expired ones included. For persistence.
  Map<String, DateTime?> get entries => Map.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  /// Every name a channel might be known by here.
  static Set<String> aliasesOf(
    String channelId, {
    int? chatId,
    String? username,
  }) =>
      {
        if (channelId.isNotEmpty) channelId,
        if (chatId != null) chatId.toString(),
        if (chatId != null) chatId.abs().toString(),
        if (chatId != null) '-100${chatId.abs()}',
        if (username != null && username.isNotEmpty) username,
      };

  /// Whether this channel is muted at [now].
  bool isMuted(
    String channelId, {
    int? chatId,
    String? username,
    required DateTime now,
  }) =>
      mutedUntil(channelId, chatId: chatId, username: username, now: now) !=
          null ||
      _hasIndefiniteMute(aliasesOf(channelId, chatId: chatId, username: username));

  /// When the mute lifts, or null if it is indefinite or not muted. Ask
  /// [isMuted] to tell those apart.
  DateTime? mutedUntil(
    String channelId, {
    int? chatId,
    String? username,
    required DateTime now,
  }) {
    DateTime? soonest;
    for (final alias
        in aliasesOf(channelId, chatId: chatId, username: username)) {
      if (!_entries.containsKey(alias)) continue;
      final until = _entries[alias];
      if (until == null) continue;
      if (!until.isAfter(now)) continue;
      if (soonest == null || until.isBefore(soonest)) soonest = until;
    }
    return soonest;
  }

  bool _hasIndefiniteMute(Set<String> aliases) {
    for (final alias in aliases) {
      if (_entries.containsKey(alias) && _entries[alias] == null) return true;
    }
    return false;
  }

  /// Mutes a channel until [until], or indefinitely when it is null.
  void mute(
    String channelId, {
    int? chatId,
    String? username,
    DateTime? until,
  }) {
    for (final alias
        in aliasesOf(channelId, chatId: chatId, username: username)) {
      _entries[alias] = until;
    }
  }

  void unmute(String channelId, {int? chatId, String? username}) {
    for (final alias
        in aliasesOf(channelId, chatId: chatId, username: username)) {
      _entries.remove(alias);
    }
  }

  /// Drops mutes whose time is up. Returns true if anything changed, so the
  /// caller knows whether to rebuild and re-persist.
  bool pruneExpired(DateTime now) {
    final expired = _entries.entries
        .where((e) => e.value != null && !e.value!.isAfter(now))
        .map((e) => e.key)
        .toList();
    if (expired.isEmpty) return false;
    for (final key in expired) {
      _entries.remove(key);
    }
    return true;
  }

  /// The next moment a mute lifts, so the caller can wake exactly once instead
  /// of polling. Null when nothing is on a timer.
  DateTime? nextExpiry(DateTime now) {
    DateTime? soonest;
    for (final until in _entries.values) {
      if (until == null || !until.isAfter(now)) continue;
      if (soonest == null || until.isBefore(soonest)) soonest = until;
    }
    return soonest;
  }

  /// Ids that count as muted at [now] — what the feed filter matches against.
  Set<String> activeIds(DateTime now) => {
        for (final entry in _entries.entries)
          if (entry.value == null || entry.value!.isAfter(now)) entry.key,
      };

  MuteRegistry copy() => MuteRegistry(_entries);

  /// Restores from disk, tolerating the format that came before.
  ///
  /// Mutes used to be a plain list of ids with no expiry. Reading one as a set
  /// of indefinite mutes keeps everything the reader already muted muted.
  factory MuteRegistry.fromJson(Object? decoded) {
    if (decoded is List) {
      return MuteRegistry({
        for (final id in decoded) id.toString(): null,
      });
    }

    if (decoded is Map) {
      final entries = <String, DateTime?>{};
      for (final entry in decoded.entries) {
        final raw = entry.value;
        entries[entry.key.toString()] =
            raw is String ? DateTime.tryParse(raw) : null;
      }
      return MuteRegistry(entries);
    }

    return MuteRegistry();
  }

  Map<String, String?> toJson() => {
        for (final entry in _entries.entries)
          entry.key: entry.value?.toIso8601String(),
      };
}

/// How long a mute lasts — Telegram's own menu.
enum MuteDuration {
  oneHour(Duration(hours: 1)),
  eightHours(Duration(hours: 8)),
  twoDays(Duration(days: 2)),
  forever(null);

  const MuteDuration(this.length);

  /// Null means indefinite.
  final Duration? length;

  DateTime? expiryFrom(DateTime now) =>
      length == null ? null : now.add(length!);
}
