import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';

Post _post({String? text, List<TextEntity> entities = const []}) => Post(
  id: '-100500_4',
  chatId: -100500,
  channelId: '-100500',
  messageId: 4,
  channelTitle: 'Ada Writes',
  publishedAt: DateTime(2026, 9, 26),
  text: text,
  entities: entities,
);

void main() {
  // An edit the reader made shows at once, from the same override reactions
  // use — refetching the post or the thread for it drops the screen to a
  // spinner and loses their place.
  group('an edited post', () {
    test('takes the new words', () {
      final edited = applyPostOverrides(_post(text: 'old'), {
        '-100500_4': {'text': 'new'},
      });
      expect(edited.text, 'new');
    });

    // The entities described the old text and would point at the wrong
    // characters in the new; the edit box is plain text, so plain it is.
    test('drops formatting that described the old words', () {
      final edited = applyPostOverrides(
        _post(
          text: 'bold words',
          entities: const [TextEntity(offset: 0, length: 4, type: TextEntityType.bold)],
        ),
        {
          '-100500_4': {'text': 'new'},
        },
      );
      expect(edited.entities, isEmpty);
    });

    test('an emptied caption is no text rather than empty text', () {
      final edited = applyPostOverrides(_post(text: 'caption'), {
        '-100500_4': {'text': ''},
      });
      expect(edited.text, isNull);
    });

    test('a post nobody edited is left alone', () {
      final post = _post(text: 'as it was');
      expect(applyPostOverrides(post, const {}), same(post));
    });
  });
}
