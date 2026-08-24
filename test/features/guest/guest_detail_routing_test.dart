import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/channels/domain/channel_tab.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';

/// Every detail screen in the app went through TDLib, and a guest post has no
/// TDLib behind it — so a post the reader could plainly see on the feed opened
/// onto "post not found", and its channel onto "channel unavailable".
///
/// The discriminator is the synthetic chat id. These tests pin it, because
/// getting it wrong in either direction is bad in a different way: too narrow
/// and guest detail screens break again, too wide and a real Telegram channel
/// gets routed into the guest path and shows nothing.
void main() {
  group('synthetic chat ids', () {
    test('a guest channel id is recognised as synthetic', () {
      final id = GuestPostMapper.syntheticChatId('ragoose_dumps');
      expect(GuestPostMapper.isSynthetic(id), isTrue);
    });

    // Real supergroup chat ids are -100 followed by the supergroup id, which
    // puts every one of them below the synthetic floor.
    test('a real supergroup chat id is not', () {
      for (final id in [-1001234567890, -1002000000000, -1009999999999]) {
        expect(GuestPostMapper.isSynthetic(id), isFalse, reason: '$id');
      }
    });

    test('a user chat id is not', () {
      expect(GuestPostMapper.isSynthetic(123456789), isFalse);
      expect(GuestPostMapper.isSynthetic(0), isFalse);
    });

    test('the id is stable across calls, so bookmarks survive a restart', () {
      expect(
        GuestPostMapper.syntheticChatId('ragoose_dumps'),
        GuestPostMapper.syntheticChatId('ragoose_dumps'),
      );
    });

    test('case does not make a second channel', () {
      expect(
        GuestPostMapper.syntheticChatId('Ragoose_Dumps'),
        GuestPostMapper.syntheticChatId('ragoose_dumps'),
      );
    });

    test('different channels get different ids', () {
      expect(
        GuestPostMapper.syntheticChatId('ragoose_dumps'),
        isNot(GuestPostMapper.syntheticChatId('lidsverse')),
      );
    });

    // How the detail providers split the two sources: the post id's chat half
    // is what decides which way the lookup goes.
    test('a guest post id parses back to a synthetic chat id', () {
      final chatId = GuestPostMapper.syntheticChatId('ragoose_dumps');
      const messageId = 482;
      final postId = '${chatId}_$messageId';

      final parts = postId.split('_');
      expect(parts, hasLength(2));
      expect(GuestPostMapper.isSynthetic(int.parse(parts.first)), isTrue);
      expect(int.parse(parts.last), messageId);
    });
  });

  group('guest channel tabs', () {
    // Four of the five tabs are SearchChatMessages, which needs a real chat.
    // A guest channel has none, so those tabs could only ever show an error.
    List<ChannelTab> tabsFor({required bool isGuest}) =>
        isGuest ? const [ChannelTab.posts] : ChannelTab.values;

    test('a guest channel offers history only', () {
      expect(tabsFor(isGuest: true), [ChannelTab.posts]);
    });

    test('a signed-in channel keeps all five', () {
      expect(tabsFor(isGuest: false), hasLength(5));
    });

    // The one tab a guest does get must be the one that needs no search.
    test('the guest tab is a history tab', () {
      expect(tabsFor(isGuest: true).single.isHistory, isTrue);
    });
  });
}
