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
}
