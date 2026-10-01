import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/reaction_choice.dart';

void main() {
  group('applyReactionChoice', () {
    test('adding a first reaction counts it and marks it chosen', () {
      final next = applyReactionChoice(
        reactions: const {},
        chosen: const {},
        emoji: '👍',
      );

      expect(next.reactions, {'👍': 1});
      expect(next.chosen, {'👍'});
    });

    test('picking a second reaction replaces the first', () {
      final next = applyReactionChoice(
        reactions: const {'👍': 3, '🔥': 1},
        chosen: const {'👍'},
        emoji: '🔥',
      );

      expect(next.chosen, {'🔥'}, reason: 'only one reaction per message');
      expect(next.reactions['👍'], 2, reason: 'the old one is given back');
      expect(next.reactions['🔥'], 2);
    });

    test('tapping the current reaction removes it', () {
      final next = applyReactionChoice(
        reactions: const {'👍': 3},
        chosen: const {'👍'},
        emoji: '👍',
      );

      expect(next.chosen, isEmpty);
      expect(next.reactions['👍'], 2);
    });

    test('a reaction dropping to zero disappears from the counts', () {
      final next = applyReactionChoice(
        reactions: const {'👍': 1},
        chosen: const {'👍'},
        emoji: '👍',
      );

      expect(next.reactions.containsKey('👍'), isFalse);
    });

    test('replacing the last of a reaction removes it entirely', () {
      final next = applyReactionChoice(
        reactions: const {'👍': 1},
        chosen: const {'👍'},
        emoji: '❤️',
      );

      expect(next.reactions.containsKey('👍'), isFalse);
      expect(next.reactions['❤️'], 1);
      expect(next.chosen, {'❤️'});
    });

    test('other people\'s reactions are left alone', () {
      final next = applyReactionChoice(
        reactions: const {'👍': 10, '😂': 4},
        chosen: const {},
        emoji: '👍',
      );

      expect(next.reactions['😂'], 4);
      expect(next.reactions['👍'], 11);
    });

    test('does not mutate the maps it was given', () {
      final reactions = {'👍': 2};
      final chosen = {'👍'};

      applyReactionChoice(reactions: reactions, chosen: chosen, emoji: '🔥');

      expect(reactions, {'👍': 2});
      expect(chosen, {'👍'});
    });

    test('current reports the user\'s own reaction', () {
      const none = ReactionState(reactions: {}, chosen: {});
      expect(none.current, isNull);

      const one = ReactionState(reactions: {'👍': 1}, chosen: {'👍'});
      expect(one.current, '👍');
    });
  });
}
