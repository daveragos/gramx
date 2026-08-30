import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/reply_presentation.dart';
import 'package:gramx/features/feed/presentation/widgets/reply_target.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

Post post({
  String? replyToText,
  String? replyToAuthorTitle,
  int? replyToMessageId,
  int? replyToChatId,
  int? replyToThumbnailFileId,
  String? replyToThumbnailUrl,
  bool isChannelVerified = false,
}) => Post(
  id: '-100_5',
  chatId: -100,
  channelId: '-100',
  messageId: 5,
  channelTitle: 'Nasa Daily',
  channelUsername: 'nasadaily',
  channelAvatarFileId: 77,
  channelAvatarColor: '#1D9BF0',
  isChannelVerified: isChannelVerified,
  publishedAt: DateTime(2026, 8, 30, 12),
  replyToText: replyToText,
  replyToAuthorTitle: replyToAuthorTitle,
  replyToMessageId: replyToMessageId,
  replyToChatId: replyToChatId,
  replyToThumbnailFileId: replyToThumbnailFileId,
  replyToThumbnailUrl: replyToThumbnailUrl,
);

void main() {
  group('replyPresentationFor', () {
    test('a post that answers nothing gets neither shape', () {
      expect(replyPresentationFor(post()), ReplyPresentation.none);
    });

    test('any one of the three reply fields is enough to count as a reply', () {
      expect(
        replyPresentationFor(post(replyToMessageId: 4)),
        isNot(ReplyPresentation.none),
      );
      expect(
        replyPresentationFor(post(replyToAuthorTitle: 'Ada')),
        isNot(ReplyPresentation.none),
      );
      expect(
        replyPresentationFor(post(replyToText: 'hi')),
        isNot(ReplyPresentation.none),
      );
    });

    // TDLib sends no excerpt for a reply inside one channel, so this is the
    // common case, not the edge one.
    test('a reply with nothing to show gets the line', () {
      expect(
        replyPresentationFor(post(replyToMessageId: 4, replyToAuthorTitle: 'Ada')),
        ReplyPresentation.line,
      );
    });

    test('quoted words earn the card', () {
      expect(
        replyPresentationFor(post(replyToMessageId: 4, replyToText: 'the words')),
        ReplyPresentation.card,
      );
    });

    test('a picture alone earns the card', () {
      expect(
        replyPresentationFor(post(replyToMessageId: 4, replyToThumbnailFileId: 12)),
        ReplyPresentation.card,
      );
      expect(
        replyPresentationFor(
          post(replyToMessageId: 4, replyToThumbnailUrl: '/tmp/thumb.jpg'),
        ),
        ReplyPresentation.card,
      );
    });

    // An empty bordered box is worse than the line it replaced.
    test('whitespace is not content', () {
      expect(
        replyPresentationFor(post(replyToMessageId: 4, replyToText: '   \n ')),
        ReplyPresentation.line,
      );
    });

    test('a zero file id is no file, not a file', () {
      expect(
        replyPresentationFor(post(replyToMessageId: 4, replyToThumbnailFileId: 0)),
        ReplyPresentation.line,
      );
      expect(
        replyPresentationFor(post(replyToMessageId: 4, replyToThumbnailUrl: '')),
        ReplyPresentation.line,
      );
    });
  });

  group('ReplyTarget', () {
    Widget host(Post p, {bool compact = false, VoidCallback? onOpenPost}) =>
        ProviderScope(
          // An avatar or a thumbnail asks TDLib for the file behind it. There
          // is no TDLib here, so every id resolves to "not downloaded" — which
          // is also what the widget sees on a real first frame.
          overrides: [
            fileDownloadProvider.overrideWith((ref, fileId) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReplyTarget(
                post: p,
                compact: compact,
                onOpenPost: onOpenPost ?? () {},
                onOpenAuthor: () {},
              ),
            ),
          ),
        );

    testWidgets('draws nothing when the post answers nothing', (tester) async {
      await tester.pumpWidget(host(post()));
      expect(find.byType(QuotedPostCard), findsNothing);
      expect(find.textContaining(AppStrings.chatReplyingTo), findsNothing);
    });

    testWidgets('the line names who is being answered', (tester) async {
      await tester.pumpWidget(
        host(post(replyToMessageId: 4, replyToAuthorTitle: 'Ada Lovelace')),
      );
      expect(
        find.text(AppStrings.chatReplyingToName('Ada Lovelace')),
        findsOneWidget,
      );
      expect(find.byType(QuotedPostCard), findsNothing);
    });

    testWidgets('the card carries the quoted byline and words', (tester) async {
      await tester.pumpWidget(
        host(post(
          replyToMessageId: 4,
          replyToAuthorTitle: 'Ada Lovelace',
          replyToText: 'the analytical engine',
        )),
      );
      expect(find.byType(QuotedPostCard), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('the analytical engine'), findsOneWidget);
    });

    // Telegram's block was drawn inside a comment, which is inside a thread,
    // which is inside the post screen. The card there would be a fourth box.
    testWidgets('compact keeps the line even with words to quote',
        (tester) async {
      await tester.pumpWidget(
        host(
          post(
            replyToMessageId: 4,
            replyToAuthorTitle: 'Ada Lovelace',
            replyToText: 'the analytical engine',
          ),
          compact: true,
        ),
      );
      expect(find.byType(QuotedPostCard), findsNothing);
      expect(
        find.text(AppStrings.chatReplyingToName('Ada Lovelace')),
        findsOneWidget,
      );
      // The words still survive, under the line rather than in a box.
      expect(find.text('the analytical engine'), findsOneWidget);
    });

    testWidgets('a reply with no named author falls back to this channel',
        (tester) async {
      await tester.pumpWidget(host(post(replyToMessageId: 4)));
      expect(
        find.text(AppStrings.chatReplyingToName('Nasa Daily')),
        findsOneWidget,
      );
    });

    testWidgets('tapping the card opens what it quotes', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          post(replyToMessageId: 4, replyToText: 'the analytical engine'),
          onOpenPost: () => opened++,
        ),
      );
      await tester.tap(find.byType(QuotedPostCard));
      expect(opened, 1);
    });

    // The same fault PostSender was built to prevent, one level down: a quote
    // of another channel must not wear this channel's picture and tick.
    testWidgets('a cross-chat quote borrows no identity from this post',
        (tester) async {
      await tester.pumpWidget(
        host(post(
          replyToMessageId: 4,
          replyToChatId: -200,
          replyToAuthorTitle: 'Ada Lovelace',
          replyToText: 'the analytical engine',
          isChannelVerified: true,
        )),
      );

      final card = tester.widget<QuotedPostCard>(find.byType(QuotedPostCard));
      expect(card.authorTitle, 'Ada Lovelace');
      expect(card.avatarFileId, isNull);
      expect(card.authorUsername, isNull);
      expect(card.isAuthorVerified, isFalse);
    });

    testWidgets('a reply within this channel keeps its face and tick',
        (tester) async {
      await tester.pumpWidget(
        host(post(
          replyToMessageId: 4,
          replyToText: 'the analytical engine',
          isChannelVerified: true,
        )),
      );

      final card = tester.widget<QuotedPostCard>(find.byType(QuotedPostCard));
      expect(card.avatarFileId, 77);
      expect(card.authorUsername, 'nasadaily');
      expect(card.isAuthorVerified, isTrue);
    });
  });
}
