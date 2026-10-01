/// Which channels are hidden from the feed, and until when.
///
/// Pure state with no I/O or clock; callers pass the time. Persistence and
/// expiry timers live in `MutedChannelsNotifier`.
///
/// A channel can be known by its chat id, the `-100` form, the bare
/// supergroup id or its username, so a mute is stored under all of them.
class MuteRegistry {
  /// Alias id to when the mute lifts; null means indefinitely.
  final Map<String, DateTime?> _entries;

  MuteRegistry([Map<String, DateTime?>? entries]) : _entries = {...?entries};

  /// Every id currently recorded, expired ones included. For persistence.
  Map<String, DateTime?> get entries => Map.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  /// Every id a channel might be known by.
  static Set<String> aliasesOf(
    String channelId, {
    int? chatId,
    String? username,
  }) => {
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
      _hasIndefiniteMute(
        aliasesOf(channelId, chatId: chatId, username: username),
      );

  /// When the mute lifts, or null if it is indefinite or not muted. Ask
  /// [isMuted] to tell those apart.
  DateTime? mutedUntil(
    String channelId, {
    int? chatId,
    String? username,
    required DateTime now,
  }) {
    DateTime? soonest;
    for (final alias in aliasesOf(
      channelId,
      chatId: chatId,
      username: username,
    )) {
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
    for (final alias in aliasesOf(
      channelId,
      chatId: chatId,
      username: username,
    )) {
      _entries[alias] = until;
    }
  }

  void unmute(String channelId, {int? chatId, String? username}) {
    for (final alias in aliasesOf(
      channelId,
      chatId: chatId,
      username: username,
    )) {
      _entries.remove(alias);
    }
  }

  /// Drops expired mutes. Returns true if anything changed.
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

  /// When the next timed mute lifts, or null if none is timed.
  DateTime? nextExpiry(DateTime now) {
    DateTime? soonest;
    for (final until in _entries.values) {
      if (until == null || !until.isAfter(now)) continue;
      if (soonest == null || until.isBefore(soonest)) soonest = until;
    }
    return soonest;
  }

  /// Ids that count as muted at [now], for the feed filter.
  Set<String> activeIds(DateTime now) => {
    for (final entry in _entries.entries)
      if (entry.value == null || entry.value!.isAfter(now)) entry.key,
  };

  MuteRegistry copy() => MuteRegistry(_entries);

  /// Restores from disk. A plain list of ids (the older format) is read as
  /// indefinite mutes.
  factory MuteRegistry.fromJson(Object? decoded) {
    if (decoded is List) {
      return MuteRegistry({for (final id in decoded) id.toString(): null});
    }

    if (decoded is Map) {
      final entries = <String, DateTime?>{};
      for (final entry in decoded.entries) {
        final raw = entry.value;
        entries[entry.key.toString()] = raw is String
            ? DateTime.tryParse(raw)
            : null;
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

/// How long a mute lasts, matching Telegram's options.
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
