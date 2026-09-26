import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/post_sender.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

import '../support/td_fixtures.dart';

/// The bug: a comment left by somebody with **no profile photo** was
/// drawn wearing the channel's avatar, so a stranger appeared to be posting as
/// the channel itself.
///
/// The cause was a fallback per field. Title, avatar path and avatar file id
/// were three loose optional arguments, each falling back to the chat on its
/// own, so a sender who supplied two of the three silently inherited the third
/// from a channel they have nothing to do with. [PostSender] makes the answer
/// all-or-nothing.
void main() {
  final channel = TdFixtures.chatWithPhoto(
    id: -1001,
    photoFileId: 900,
    title: 'The Channel',
    localPath: '/tmp/channel.jpg',
  );

  group('a post with no sender is the channel', () {
    test('and takes the channel avatar', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.textMessage(id: 5, chatId: -1001),
        channel,
      );

      expect(post.channelTitle, 'The Channel');
      expect(post.channelAvatarUrl, '/tmp/channel.jpg');
      expect(post.channelAvatarFileId, 900);
      expect(post.senderUserId, isNull);
    });
  });

  group('a comment carries its own author', () {
    test('name, handle and picture all come from the sender', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.textMessage(id: 5, chatId: -1001),
        channel,
        sender: const PostSender(
          userId: 42,
          title: 'Ada',
          username: 'ada',
          avatarPath: '/tmp/ada.jpg',
          avatarFileId: 77,
        ),
      );

      expect(post.channelTitle, 'Ada');
      expect(post.channelUsername, 'ada');
      expect(post.channelAvatarUrl, '/tmp/ada.jpg');
      expect(post.channelAvatarFileId, 77);
      expect(post.senderUserId, 42);
    });

    // The regression itself.
    test('a sender with no picture gets none — not the channel\'s', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.textMessage(id: 5, chatId: -1001),
        channel,
        sender: const PostSender(userId: 42, title: 'Ada'),
      );

      expect(post.channelTitle, 'Ada');
      expect(post.channelAvatarUrl, isNull);
      expect(post.channelAvatarFileId, isNull);
    });

    test('the fallback colour follows the person, not the chat', () {
      final ada = TdlibMappers.mapMessageToPost(
        TdFixtures.textMessage(id: 5, chatId: -1001),
        channel,
        sender: const PostSender(userId: 42, title: 'Ada'),
      );
      final grace = TdlibMappers.mapMessageToPost(
        TdFixtures.textMessage(id: 6, chatId: -1001),
        channel,
        sender: const PostSender(userId: 43, title: 'Grace'),
      );
      final adaAgain = TdlibMappers.mapMessageToPost(
        TdFixtures.textMessage(id: 7, chatId: -1001),
        channel,
        sender: const PostSender(userId: 42, title: 'Ada'),
      );

      expect(ada.channelAvatarColor, isNot(grace.channelAvatarColor));
      expect(ada.channelAvatarColor, adaAgain.channelAvatarColor);
    });

    test('a channel posting into its own discussion group is not a user', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.textMessage(id: 5, chatId: -1001),
        channel,
        sender: const PostSender(
          senderChatId: -2002,
          title: 'Another Channel',
          avatarPath: '/tmp/other.jpg',
          avatarFileId: 88,
        ),
      );

      expect(post.channelTitle, 'Another Channel');
      expect(post.channelAvatarUrl, '/tmp/other.jpg');
      // Nothing to open a profile for: there is no person behind it.
      expect(post.senderUserId, isNull);
    });
  });

  group('userDisplayName', () {
    test('joins the two name fields', () {
      expect(
        TdlibMappers.userDisplayName(
          TdFixtures.user(id: 1, firstName: 'Ada', lastName: 'Lovelace'),
        ),
        'Ada Lovelace',
      );
    });

    test('falls back to the handle when both are empty', () {
      expect(
        TdlibMappers.userDisplayName(
          TdFixtures.user(id: 1, firstName: '', username: 'ada'),
        ),
        '@ada',
      );
    });

    test('names a deleted account as one', () {
      expect(
        TdlibMappers.userDisplayName(
          TdFixtures.user(id: 1, firstName: '', isDeleted: true),
        ),
        'Deleted account',
      );
    });
  });
}
