import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/handy_tdlib.dart' show TdPlugin;
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/domain/text_entity.dart';

/// Text as it goes to Telegram: the formatting the writer applied, and any
/// Markdown they typed (`**bold**`, `__italic__`, `~~struck~~`, `||spoiler||`,
/// `` `code` ``, `[text](url)`), read by TDLib's own parser as Telegram's
/// apps read it.
abstract final class OutgoingText {
  static td.FormattedText of(
    String text, [
    List<TextEntity> entities = const [],
  ]) => parseMarkdown(
    td.FormattedText(
      text: text,
      entities: [for (final entity in entities) ?toTd(entity)],
    ),
  );

  /// [text] with its Markdown made into formatting. TDLib answers this one
  /// synchronously, without a client. Unchanged if the library can't, as in
  /// tests.
  static td.FormattedText parseMarkdown(td.FormattedText text) {
    if (text.text.isEmpty) return text;
    try {
      final raw = TdPlugin.instance.tdExecute(
        jsonEncode(td.ParseMarkdown(text: text).toJson()),
      );
      if (raw == null) return text;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['@type'] != 'formattedText') return text;
      return td.FormattedText.fromJson(json);
    } catch (e) {
      debugPrint('[OutgoingText] Markdown left as typed: $e');
      return text;
    }
  }

  /// [entity] as TDLib takes it from a client. Null for marks Telegram finds
  /// by itself, such as links and hashtags.
  static td.TextEntity? toTd(TextEntity entity) {
    final td.TextEntityType? type = switch (entity.type) {
      TextEntityType.bold => const td.TextEntityTypeBold(),
      TextEntityType.italic => const td.TextEntityTypeItalic(),
      TextEntityType.underline => const td.TextEntityTypeUnderline(),
      TextEntityType.strikethrough => const td.TextEntityTypeStrikethrough(),
      TextEntityType.spoiler => const td.TextEntityTypeSpoiler(),
      TextEntityType.code => const td.TextEntityTypeCode(),
      TextEntityType.codeBlock => switch (entity.language) {
        final String language when language.isNotEmpty =>
          td.TextEntityTypePreCode(language: language),
        _ => const td.TextEntityTypePre(),
      },
      TextEntityType.blockQuote => const td.TextEntityTypeBlockQuote(),
      TextEntityType.expandableBlockQuote =>
        const td.TextEntityTypeExpandableBlockQuote(),
      TextEntityType.textUrl when (entity.url ?? '').isNotEmpty =>
        td.TextEntityTypeTextUrl(url: entity.url!),
      TextEntityType.mentionName when entity.userId != null =>
        td.TextEntityTypeMentionName(userId: entity.userId!),
      TextEntityType.customEmoji
          when int.tryParse(entity.customEmojiId ?? '') != null =>
        td.TextEntityTypeCustomEmoji(
          customEmojiId: int.parse(entity.customEmojiId!),
        ),
      _ => null,
    };
    if (type == null || entity.length <= 0) return null;
    return td.TextEntity(
      offset: entity.offset,
      length: entity.length,
      type: type,
    );
  }
}
