import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/navigation/deep_link_handler.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/data/user_profile_mapper.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';

import '../support/td_fixtures.dart';

/// T17-3: the screen gramX never had — somewhere to put a person.
///
/// The mapper is what is worth testing here. Every one of these is a rule that
/// can be wrong quietly: an empty string that means "hidden" rendered as a
/// blank row, a deleted account drawn as somebody with a very sparse profile,
/// a missing photo inherited from somewhere else.
void main() {
  // A resolved username picks its screen from this. Getting it wrong is how a
  // person's t.me link opened the channel screen.
  group('what a resolved name belongs to', () {
    test('a person or a bot is a person', () {
      expect(
        ChatsRepository.resolvedKindOf(const td.ChatTypePrivate(userId: 42)),
        ResolvedChatKind.person,
      );
    });

    test('a broadcast supergroup is a channel', () {
      expect(
        ChatsRepository.resolvedKindOf(
          const td.ChatTypeSupergroup(supergroupId: 7, isChannel: true),
        ),
        ResolvedChatKind.channel,
      );
    });

    test('any other supergroup, and a basic group, is a group', () {
      expect(
        ChatsRepository.resolvedKindOf(
          const td.ChatTypeSupergroup(supergroupId: 7, isChannel: false),
        ),
        ResolvedChatKind.group,
      );
      expect(
        ChatsRepository.resolvedKindOf(
          const td.ChatTypeBasicGroup(basicGroupId: 9),
        ),
        ResolvedChatKind.group,
      );
    });
  });

  group('UserProfileMapper', () {
    test('reads the plain user record without a full one', () {
      final profile = UserProfileMapper.from(
        TdFixtures.user(
          id: 42,
          firstName: 'Ada',
          lastName: 'Lovelace',
          username: 'ada',
          isVerified: true,
        ),
      );

      expect(profile.userId, 42);
      expect(profile.chatId, 42);
      expect(profile.displayName, 'Ada Lovelace');
      expect(profile.username, 'ada');
      expect(profile.isVerified, isTrue);
      // Absent, not empty: the screen draws what it has while the second
      // request is still in flight rather than holding the page back.
      expect(profile.bio, isNull);
      expect(profile.groupsInCommon, 0);
    });

    test('a hidden phone number is absent, not an empty row', () {
      final profile = UserProfileMapper.from(TdFixtures.user(id: 42));
      expect(profile.phoneNumber, isNull);
    });

    test('a published one is rendered in international form', () {
      final profile = UserProfileMapper.from(
        TdFixtures.user(id: 42, phoneNumber: '15551234'),
      );
      expect(profile.phoneNumber, '+15551234');
    });

    test('a blank bio is nothing rather than an empty paragraph', () {
      expect(
        UserProfileMapper.bioOf(TdFixtures.userFullInfo(bio: '   ')),
        isNull,
      );
      expect(UserProfileMapper.bioOf(TdFixtures.userFullInfo()), isNull);
      expect(UserProfileMapper.bioOf(null), isNull);
      expect(
        UserProfileMapper.bioOf(TdFixtures.userFullInfo(bio: 'Analyst')),
        'Analyst',
      );
    });

    test('a person with no photo has none, never a placeholder path', () {
      final profile = UserProfileMapper.from(TdFixtures.user(id: 42));
      expect(profile.avatarPath, isNull);
      expect(profile.avatarFileId, isNull);
    });

    test('a downloaded photo is handed over by path', () {
      final profile = UserProfileMapper.from(
        TdFixtures.user(id: 42, profilePhotoFileId: 900),
      );
      expect(profile.avatarPath, '/tmp/avatar.jpg');
      expect(profile.avatarFileId, 900);
    });

    test('a bot is marked as software rather than as a person', () {
      final profile = UserProfileMapper.from(
        TdFixtures.user(id: 42, isBot: true),
      );

      expect(profile.isBot, isTrue);
      // A bot answers instantly and always, so a presence line for one is
      // noise dressed as information.
      expect(profile.presence, ChatPresence.unknown);
    });

    test('a deleted account says so rather than looking sparse', () {
      final profile = UserProfileMapper.from(
        TdFixtures.user(id: 42, firstName: '', isDeleted: true),
      );

      expect(profile.isDeleted, isTrue);
      expect(profile.displayName, 'Deleted account');
    });

    test('presence comes through in Telegram\'s own hedged buckets', () {
      final profile = UserProfileMapper.from(
        TdFixtures.user(
          id: 42,
          status: const {
            '@type': 'userStatusRecently',
            'by_my_privacy_settings': false,
          },
        ),
      );

      expect(profile.presence, ChatPresence.recently);
    });

    test('the personal channel is carried, with its title when known', () {
      final profile = UserProfileMapper.from(
        TdFixtures.user(id: 42),
        fullInfo: TdFixtures.userFullInfo(
          bio: 'Analyst',
          personalChatId: -100,
          groupInCommonCount: 3,
        ),
        personalChannelTitle: 'Ada Writes',
      );

      expect(profile.bio, 'Analyst');
      expect(profile.personalChannelId, -100);
      expect(profile.personalChannelTitle, 'Ada Writes');
      expect(profile.groupsInCommon, 3);
    });

    test('and is absent entirely when there is no personal chat', () {
      final profile = UserProfileMapper.from(
        TdFixtures.user(id: 42),
        fullInfo: TdFixtures.userFullInfo(),
        // Even handed a title, a person with no personal chat has no channel:
        // zero means none, and a stray title must not conjure one.
        personalChannelTitle: 'Ada Writes',
      );

      expect(profile.personalChannelId, isNull);
      expect(profile.personalChannelTitle, isNull);
    });
  });
}
