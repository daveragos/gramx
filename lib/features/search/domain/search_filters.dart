import 'package:flutter/foundation.dart';

import 'package:gramx/features/feed/domain/post.dart';

/// How far back a search reaches.
enum SearchDateRange {
  allTime(null),
  day(Duration(days: 1)),
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  year(Duration(days: 365));

  const SearchDateRange(this.span);

  /// How far back from now, or null for no limit.
  final Duration? span;
}

/// What kind of post a search looks for. Telegram filters by attachment;
/// X's "Post activity" has no Telegram counterpart.
enum SearchMediaType { any, photos, videos, links, files, voice, music }

/// The search filters, as X's filter sheet sets them. Telegram applies the
/// folder, date and type; replies and reposts are left out here, since its
/// search has no such option.
@immutable
class SearchFilters {
  /// Search only this chat folder, or every channel followed when null.
  final int? folderId;
  final SearchDateRange date;
  final SearchMediaType type;
  final bool excludeReplies;
  final bool excludeReposts;

  const SearchFilters({
    this.folderId,
    this.date = SearchDateRange.allTime,
    this.type = SearchMediaType.any,
    this.excludeReplies = false,
    this.excludeReposts = false,
  });

  bool get isDefault => this == const SearchFilters();

  SearchFilters copyWith({
    SearchDateRange? date,
    SearchMediaType? type,
    bool? excludeReplies,
    bool? excludeReposts,
  }) => SearchFilters(
    folderId: folderId,
    date: date ?? this.date,
    type: type ?? this.type,
    excludeReplies: excludeReplies ?? this.excludeReplies,
    excludeReposts: excludeReposts ?? this.excludeReposts,
  );

  /// With [folderId] set, or cleared when null.
  SearchFilters withFolder(int? folderId) => SearchFilters(
    folderId: folderId,
    date: date,
    type: type,
    excludeReplies: excludeReplies,
    excludeReposts: excludeReposts,
  );

  /// The earliest send time to search from, in Unix seconds, or 0 for any.
  int minDateFor(DateTime now) {
    final span = date.span;
    if (span == null) return 0;
    return now.subtract(span).millisecondsSinceEpoch ~/ 1000;
  }

  /// Whether [post] passes the filters Telegram's search can't apply.
  bool keeps(Post post) {
    if (excludeReplies && post.replyToMessageId != null) return false;
    if (excludeReposts && isRepost(post)) return false;
    return true;
  }

  /// Whether [post] was forwarded from somewhere else.
  static bool isRepost(Post post) =>
      post.forwardedFromChatId != null ||
      post.forwardedFromTitle != null ||
      post.forwardedFromUsername != null;

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.folderId == folderId &&
      other.date == date &&
      other.type == type &&
      other.excludeReplies == excludeReplies &&
      other.excludeReposts == excludeReposts;

  @override
  int get hashCode =>
      Object.hash(folderId, date, type, excludeReplies, excludeReposts);
}
