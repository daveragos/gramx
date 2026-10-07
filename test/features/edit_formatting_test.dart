import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/chats/data/chats_repository.dart';

td.TextEntity bold(int offset, int length) => td.TextEntity(
  offset: offset,
  length: length,
  type: const td.TextEntityTypeBold(),
);

List<(int, int)> spans(List<td.TextEntity> entities) => [
  for (final e in entities) (e.offset, e.length),
];

/// An edit used to drop every bold, link and custom emoji.
void main() {
  final before = td.FormattedText(
    text: 'Launch at noon today',
    entities: [bold(0, 6), bold(15, 5)],
  );

  test('keeps marks before and after the change', () {
    final kept = ChatsRepository.keptEntities(before, 'Launch at 3pm today');

    expect(spans(kept), [(0, 6), (14, 5)]);
  });

  test('a mark around the change stretches with it', () {
    final kept = ChatsRepository.keptEntities(
      td.FormattedText(text: 'big news', entities: [bold(0, 8)]),
      'big good news',
    );

    expect(spans(kept), [(0, 13)]);
  });

  test('a replaced word inside a mark keeps it', () {
    final kept = ChatsRepository.keptEntities(before, 'Liftoff at noon today');

    expect(spans(kept), [(0, 7), (16, 5)]);
  });

  test('drops a mark the change runs out of', () {
    final kept = ChatsRepository.keptEntities(before, 'Laun today');

    expect(spans(kept), [(5, 5)]);
  });

  test('leaves links and mentions for Telegram to find', () {
    final kept = ChatsRepository.keptEntities(
      td.FormattedText(
        text: 'see @nasa',
        entities: [
          td.TextEntity(
            offset: 4,
            length: 5,
            type: const td.TextEntityTypeMention(),
          ),
        ],
      ),
      'see @nasa now',
    );

    expect(kept, isEmpty);
  });

  test('an unchanged text keeps all its marks', () {
    expect(spans(ChatsRepository.keptEntities(before, before.text)), [
      (0, 6),
      (15, 5),
    ]);
  });
}
