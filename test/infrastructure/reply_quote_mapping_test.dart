import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/reply_presentation.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

import '../support/td_fixtures.dart';

/// draws that differently from a reply to the whole post. The mapper filled
/// `replyToText` from three sources — the selected quote, a resolved excerpt,
/// and the target's own content — and kept no record of which, so by the time
/// the UI saw it the distinction was gone.
void main() {
  final channel = TdFixtures.chatWithPhoto(
    id: -1001,
    photoFileId: 900,
    title: 'The Channel',
    localPath: '/tmp/channel.jpg',
  );

  test('a reply to the whole post is not a quote', () {
    final post = TdlibMappers.mapMessageToPost(
      TdFixtures.replyingMessage(
        id: 5,
        chatId: -1001,
        replyToMessageId: 4,
        targetText: 'the whole original post',
      ),
      channel,
    );

    expect(post.replyToIsQuote, isFalse);
    expect(post.replyToText, 'the whole original post');
    expect(replyPresentationFor(post), ReplyPresentation.card);
  });

  test('a selected passage is a quote', () {
    final post = TdlibMappers.mapMessageToPost(
      TdFixtures.replyingMessage(
        id: 5,
        chatId: -1001,
        replyToMessageId: 4,
        quote: 'the part they picked',
      ),
      channel,
    );

    expect(post.replyToIsQuote, isTrue);
    expect(post.replyToText, 'the part they picked');
    expect(replyPresentationFor(post), ReplyPresentation.passage);
  });

  /// The fold that lost the distinction: both arrive together on a cross-chat
  /// quote, and whichever won the field decided the shape.
  test('the selected passage wins over the answered post\'s own words', () {
    final post = TdlibMappers.mapMessageToPost(
      TdFixtures.replyingMessage(
        id: 5,
        chatId: -1001,
        replyToMessageId: 4,
        replyToChatId: -1002,
        quote: 'the part they picked',
        targetText: 'the whole original post, which is much longer',
      ),
      channel,
    );

    expect(post.replyToText, 'the part they picked');
    expect(post.replyToIsQuote, isTrue);
    expect(post.replyToChatId, -1002);
    expect(replyPresentationFor(post), ReplyPresentation.passage);
  });

  /// An excerpt the repository resolved is the target's opening words, not a
  /// passage anybody chose — it must not be drawn as one.
  test('a resolved excerpt is not a quote', () {
    final post = TdlibMappers.mapMessageToPost(
      TdFixtures.replyingMessage(id: 5, chatId: -1001, replyToMessageId: 4),
      channel,
      knownReplyExcerpts: {'-1001_4': 'what the repository looked up'},
    );

    expect(post.replyToIsQuote, isFalse);
    expect(post.replyToText, 'what the repository looked up');
    expect(replyPresentationFor(post), ReplyPresentation.card);
  });

  test('a reply with nothing resolved is neither', () {
    final post = TdlibMappers.mapMessageToPost(
      TdFixtures.replyingMessage(id: 5, chatId: -1001, replyToMessageId: 4),
      channel,
    );

    expect(post.replyToIsQuote, isFalse);
    expect(replyPresentationFor(post), ReplyPresentation.line);
  });

  /// A quote of nothing is not a quote. Guards the shape that requires a
  /// non-null passage to draw at all.
  test('an empty quote does not claim to be one', () {
    final post = TdlibMappers.mapMessageToPost(
      TdFixtures.replyingMessage(
        id: 5,
        chatId: -1001,
        replyToMessageId: 4,
        quote: '   ',
      ),
      channel,
    );

    expect(post.replyToIsQuote, isFalse);
    expect(replyPresentationFor(post), isNot(ReplyPresentation.passage));
  });

  /// The bug the third device session found. A quote out of a **photo** post's
  /// caption came out as "📷 Photo": only the `messageText` branch filled
  /// `replyToText` with `??=`, and every other content branch assigned over
  /// whatever was there — including the passage the writer had chosen.
  group('a quote survives what the answered message is', () {
    test('quoting a photo caption keeps the words, not "Photo"', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.replyingMessage(
          id: 5,
          chatId: -1001,
          replyToMessageId: 4,
          quote: 'the sounds differ basing on the amount you sent',
          targetIsPhoto: true,
          targetCaption: 'an app that sends you meme sounds',
        ),
        channel,
      );

      expect(
        post.replyToText,
        'the sounds differ basing on the amount you sent',
      );
      expect(post.replyToIsQuote, isTrue);
      expect(replyPresentationFor(post), ReplyPresentation.passage);
    });

    test('a photo answered as a whole still describes itself', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.replyingMessage(
          id: 5,
          chatId: -1001,
          replyToMessageId: 4,
          targetIsPhoto: true,
        ),
        channel,
      );

      expect(post.replyToText, '📷 Photo');
      expect(post.replyToIsQuote, isFalse);
    });

    test('a photo caption is the preview when nothing was quoted', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.replyingMessage(
          id: 5,
          chatId: -1001,
          replyToMessageId: 4,
          targetIsPhoto: true,
          targetCaption: 'an app that sends you meme sounds',
        ),
        channel,
      );

      expect(post.replyToText, 'an app that sends you meme sounds');
      expect(post.replyToIsQuote, isFalse);
    });
  });

  /// The other half of the same screenshot: the passage was drawn under the
  /// byline of the channel doing the quoting, not the channel it came out of.
  group('a quote is not attributed to whoever quoted it', () {
    test('a passage from another channel has no borrowed author', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.replyingMessage(
          id: 5,
          chatId: -1001,
          replyToMessageId: 4,
          replyToChatId: -1002,
          originChatId: -1002,
          quote: 'the part they picked',
        ),
        channel,
      );

      expect(post.replyToAuthorTitle, isNull);
    });

    test('and takes the real name once the chat is known', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.replyingMessage(
          id: 5,
          chatId: -1001,
          replyToMessageId: 4,
          replyToChatId: -1002,
          originChatId: -1002,
          quote: 'the part they picked',
        ),
        channel,
        knownChatTitles: {-1002: 'RaGoose Projects'},
      );

      expect(post.replyToAuthorTitle, 'RaGoose Projects');
    });

    test('a reply within this channel is still authored by it', () {
      final post = TdlibMappers.mapMessageToPost(
        TdFixtures.replyingMessage(
          id: 5,
          chatId: -1001,
          replyToMessageId: 4,
          quote: 'the part they picked',
        ),
        channel,
      );

      expect(post.replyToAuthorTitle, 'The Channel');
    });
  });
}
