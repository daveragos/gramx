import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:gramx/features/feed/domain/text_entity.dart';

/// The marks a writer can put on selected text, as Telegram's apps offer them,
/// most used first: a phone's menu shows the first few and folds the rest.
enum TextFormat {
  bold(TextEntityType.bold),
  italic(TextEntityType.italic),
  link(TextEntityType.textUrl),
  strikethrough(TextEntityType.strikethrough),
  underline(TextEntityType.underline),
  spoiler(TextEntityType.spoiler),
  code(TextEntityType.code);

  final TextEntityType type;

  const TextFormat(this.type);
}

/// Text being written, with its formatting. Offsets count UTF-16 code units,
/// as Dart strings and Telegram both do.
@immutable
class ComposedText {
  final String text;

  /// Ordered by offset.
  final List<TextEntity> entities;

  const ComposedText(this.text, [this.entities = const []]);

  /// [text] with the marks a writer may keep when editing it: those Telegram
  /// takes from a client. Links, mentions and hashtags it finds itself.
  factory ComposedText.editable(String text, List<TextEntity> entities) =>
      ComposedText(
        text,
        [
          for (final entity in entities)
            if (_kept.contains(entity.type) &&
                entity.length > 0 &&
                entity.offset >= 0 &&
                entity.offset + entity.length <= text.length)
              entity,
        ]..sort(_byOffset),
      );

  static const _kept = {
    TextEntityType.bold,
    TextEntityType.italic,
    TextEntityType.underline,
    TextEntityType.strikethrough,
    TextEntityType.spoiler,
    TextEntityType.code,
    TextEntityType.codeBlock,
    TextEntityType.blockQuote,
    TextEntityType.expandableBlockQuote,
    TextEntityType.textUrl,
    TextEntityType.mentionName,
    TextEntityType.customEmoji,
  };

  bool get isEmpty => text.isEmpty;

  /// This once [text] has become [after]. Marks before and after the change
  /// stay where their text went, a mark around it stretches with it, and text
  /// typed at a mark's edge stays plain. [cursor], where the caret ended up,
  /// places an edit that the text alone leaves ambiguous, such as typing an
  /// "a" into "aa".
  ComposedText edited(String after, {int? cursor}) {
    if (after == text) return this;
    final shortest = math.min(text.length, after.length);
    var suffix = 0;
    while (suffix < shortest &&
        text.codeUnitAt(text.length - 1 - suffix) ==
            after.codeUnitAt(after.length - 1 - suffix)) {
      suffix++;
    }
    if (cursor != null && cursor >= 0 && cursor <= after.length) {
      suffix = math.min(suffix, after.length - cursor);
    }
    var prefix = 0;
    while (prefix < shortest - suffix &&
        text.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    return ComposedText(
      after,
      _moved(
        entities,
        start: prefix,
        oldEnd: text.length - suffix,
        newEnd: after.length - suffix,
      ),
    );
  }

  /// Whether every character of [start, end) carries [type].
  bool has(TextEntityType type, int start, int end) {
    if (start >= end) return false;
    var reached = start;
    for (final entity in entities) {
      if (entity.type != type) continue;
      if (entity.offset > reached) break;
      reached = math.max(reached, entity.offset + entity.length);
      if (reached >= end) return true;
    }
    return false;
  }

  /// Whether any mark touches [start, end).
  bool hasAny(int start, int end) =>
      entities.any((e) => e.offset < end && e.offset + e.length > start);

  /// [type] on [start, end), joined with marks of the same kind it meets. A
  /// link takes [url] and replaces any link already there.
  ComposedText withFormat(
    TextEntityType type,
    int start,
    int end, {
    String? url,
  }) {
    if (start >= end) return this;
    final isLink = type == TextEntityType.textUrl;
    var from = start;
    var to = end;
    final kept = <TextEntity>[];
    for (final entity in withoutFormat(type, start, end).entities) {
      final touches =
          entity.type == type &&
          !isLink &&
          entity.offset <= to &&
          entity.offset + entity.length >= from;
      if (!touches) {
        kept.add(entity);
        continue;
      }
      from = math.min(from, entity.offset);
      to = math.max(to, entity.offset + entity.length);
    }
    return ComposedText(
      text,
      [
        ...kept,
        TextEntity(
          offset: from,
          length: to - from,
          type: type,
          url: isLink ? url : null,
        ),
      ]..sort(_byOffset),
    );
  }

  /// [type] taken off [start, end). A mark running past either end keeps
  /// the part outside.
  ComposedText withoutFormat(TextEntityType type, int start, int end) =>
      _without((e) => e.type == type, start, end);

  /// Every mark taken off [start, end).
  ComposedText plain(int start, int end) => _without((_) => true, start, end);

  ComposedText _without(bool Function(TextEntity) matches, int start, int end) {
    final kept = <TextEntity>[];
    for (final entity in entities) {
      final entityEnd = entity.offset + entity.length;
      if (!matches(entity) || entityEnd <= start || entity.offset >= end) {
        kept.add(entity);
        continue;
      }
      if (entity.offset < start) {
        kept.add(entity.copyWith(length: start - entity.offset));
      }
      if (entityEnd > end) {
        kept.add(entity.copyWith(offset: end, length: entityEnd - end));
      }
    }
    return ComposedText(text, kept..sort(_byOffset));
  }

  /// Without the whitespace at either end, the marks moved to match.
  ComposedText trimmed() {
    final start = text.length - text.trimLeft().length;
    final end = text.trimRight().length;
    if (start == 0 && end == text.length) return this;
    if (start >= end) return const ComposedText('');
    return ComposedText(text.substring(start, end), [
      for (final entity in entities)
        if (math.min(entity.offset + entity.length, end) >
            math.max(entity.offset, start))
          entity.copyWith(
            offset: math.max(entity.offset, start) - start,
            length:
                math.min(entity.offset + entity.length, end) -
                math.max(entity.offset, start),
          ),
    ]);
  }

  /// Each match of [pattern] replaced with [replacement], the marks moved to
  /// match. A mark around a match stretches over its replacement.
  ComposedText replaceAll(RegExp pattern, String replacement) {
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) return this;
    var result = this;
    // From the end, so earlier offsets stay true.
    for (final match in matches.reversed) {
      result = ComposedText(
        result.text.replaceRange(match.start, match.end, replacement),
        _moved(
          result.entities,
          start: match.start,
          oldEnd: match.end,
          newEnd: match.start + replacement.length,
          // A mark that starts with the match keeps it.
          coversStart: true,
        ),
      );
    }
    return result;
  }

  /// [entities] once [start, oldEnd) of the text was replaced by text ending
  /// at [newEnd]. [coversStart] keeps a mark that begins at [start] on the
  /// new text, for a replacement rather than typing.
  static List<TextEntity> _moved(
    List<TextEntity> entities, {
    required int start,
    required int oldEnd,
    required int newEnd,
    bool coversStart = false,
  }) {
    final shift = newEnd - oldEnd;
    final moved = <TextEntity>[];
    for (final entity in entities) {
      final from = entity.offset;
      final to = entity.offset + entity.length;
      if (to <= start) {
        moved.add(entity);
      } else if (from >= oldEnd && !(coversStart && from == start)) {
        moved.add(entity.copyWith(offset: from + shift));
      } else {
        final newFrom = from <= start ? from : newEnd;
        final newTo = to >= oldEnd ? to + shift : start;
        if (newTo > newFrom) {
          moved.add(entity.copyWith(offset: newFrom, length: newTo - newFrom));
        }
      }
    }
    return moved..sort(_byOffset);
  }

  static int _byOffset(TextEntity a, TextEntity b) => a.offset != b.offset
      ? a.offset.compareTo(b.offset)
      : b.length.compareTo(a.length);

  @override
  bool operator ==(Object other) =>
      other is ComposedText &&
      other.text == text &&
      listEquals(other.entities, entities);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(entities));

  @override
  String toString() => 'ComposedText($text, $entities)';
}
