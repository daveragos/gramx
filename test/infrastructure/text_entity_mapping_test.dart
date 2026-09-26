import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:handy_tdlib/api.dart' as td;

/// Builds a TDLib entity of the given type over the whole string.
td.TextEntity entity(
  Map<String, dynamic> type, {
  int offset = 0,
  int length = 4,
}) => td.TextEntity.fromJson({
  '@type': 'textEntity',
  'offset': offset,
  'length': length,
  'type': type,
});

List<TextEntity> mapped(List<td.TextEntity> entities) {
  final json = TdlibMappers.serializeEntities(entities);
  return (jsonDecode(json!) as List)
      .map((e) => TextEntity.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  group('serializeEntities', () {
    // The reported bug: formatted text arrived stripped of its formatting.
    // Anything this mapper doesn't name falls through as `unknown` and renders
    // as plain text, so every branch of TDLib's union needs a name.
    test('marks that used to fall through now survive', () {
      final cases = <Map<String, dynamic>, TextEntityType>{
        {'@type': 'textEntityTypeBlockQuote'}: TextEntityType.blockQuote,
        {'@type': 'textEntityTypeExpandableBlockQuote'}:
            TextEntityType.expandableBlockQuote,
        {'@type': 'textEntityTypeCashtag'}: TextEntityType.cashtag,
        {'@type': 'textEntityTypeBotCommand'}: TextEntityType.botCommand,
        {'@type': 'textEntityTypeEmailAddress'}: TextEntityType.emailAddress,
        {'@type': 'textEntityTypePhoneNumber'}: TextEntityType.phoneNumber,
        {'@type': 'textEntityTypeBankCardNumber'}:
            TextEntityType.bankCardNumber,
        {'@type': 'textEntityTypeMediaTimestamp', 'media_timestamp': 12}:
            TextEntityType.mediaTimestamp,
        {'@type': 'textEntityTypeMentionName', 'user_id': 42}:
            TextEntityType.mentionName,
      };

      for (final testCase in cases.entries) {
        expect(
          mapped([entity(testCase.key)]).single.type,
          testCase.value,
          reason: '${testCase.key['@type']} should not render as plain text',
        );
      }
    });

    test('inline code and code blocks stay distinct', () {
      expect(
        mapped([
          entity({'@type': 'textEntityTypeCode'}),
        ]).single.type,
        TextEntityType.code,
      );
      expect(
        mapped([
          entity({'@type': 'textEntityTypePre'}),
        ]).single.type,
        TextEntityType.codeBlock,
      );
    });

    test('a fenced block keeps its language', () {
      final result = mapped([
        entity({'@type': 'textEntityTypePreCode', 'language': 'dart'}),
      ]).single;

      expect(result.type, TextEntityType.codeBlock);
      expect(result.language, 'dart');
    });

    test('a link keeps the url it points at', () {
      final result = mapped([
        entity({
          '@type': 'textEntityTypeTextUrl',
          'url': 'https://example.com',
        }),
      ]).single;

      expect(result.type, TextEntityType.textUrl);
      expect(result.url, 'https://example.com');
    });

    test('offsets and lengths are carried through unchanged', () {
      final result = mapped([
        entity({'@type': 'textEntityTypeBold'}, offset: 5, length: 9),
      ]).single;

      expect(result.offset, 5);
      expect(result.length, 9);
    });
  });
}
