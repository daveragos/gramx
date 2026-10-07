import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/reply_presentation.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/reply_target.dart';
import 'package:gramx/infrastructure/telegram/chat_identity.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

Post post({
  String? replyToText,
  String? replyToAuthorTitle,
  int? replyToMessageId,
  int? replyToChatId,
  int? replyToThumbnailFileId,
  String? replyToThumbnailUrl,
  bool replyToIsQuote = false,
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
  replyToIsQuote: replyToIsQuote,
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

    // TDLib sends no excerpt for replies within one channel, so this is common.
    test('a reply with nothing to show gets the line', () {
      expect(
        replyPresentationFor(
          post(replyToMessageId: 4, replyToAuthorTitle: 'Ada'),
        ),
        ReplyPresentation.line,
      );
    });

    test('quoted words earn the card', () {
      expect(
        replyPresentationFor(
          post(replyToMessageId: 4, replyToText: 'the words'),
        ),
        ReplyPresentation.card,
      );
    });

    test('a picture alone earns the card', () {
      expect(
        replyPresentationFor(
          post(replyToMessageId: 4, replyToThumbnailFileId: 12),
        ),
        ReplyPresentation.card,
      );
      expect(
        replyPresentationFor(
          post(replyToMessageId: 4, replyToThumbnailUrl: '/tmp/thumb.jpg'),
        ),
        ReplyPresentation.card,
      );
    });

    // A blank excerpt falls back to the line rather than an empty box.
    test('whitespace is not content', () {
      expect(
        replyPresentationFor(post(replyToMessageId: 4, replyToText: '   \n ')),
        ReplyPresentation.line,
      );
    });

    test('a selected passage beats the card', () {
      expect(
        replyPresentationFor(
          post(
            replyToMessageId: 4,
            replyToText: 'the part they picked',
            replyToIsQuote: true,
          ),
        ),
        ReplyPresentation.passage,
      );
    });

    test('a passage outranks a picture too', () {
      expect(
        replyPresentationFor(
          post(
            replyToMessageId: 4,
            replyToText: 'the part they picked',
            replyToIsQuote: true,
            replyToThumbnailFileId: 12,
          ),
        ),
        ReplyPresentation.passage,
      );
    });

    // Without the quoted words there is nothing to draw, so it falls back.
    test('the quote flag without words is not a passage', () {
      expect(
        replyPresentationFor(
          post(
            replyToMessageId: 4,
            replyToIsQuote: true,
            replyToThumbnailFileId: 12,
          ),
        ),
        ReplyPresentation.card,
      );
      expect(
        replyPresentationFor(post(replyToMessageId: 4, replyToIsQuote: true)),
        ReplyPresentation.line,
      );
    });

    test('a zero file id is no file, not a file', () {
      expect(
        replyPresentationFor(
          post(replyToMessageId: 4, replyToThumbnailFileId: 0),
        ),
        ReplyPresentation.line,
      );
      expect(
        replyPresentationFor(
          post(replyToMessageId: 4, replyToThumbnailUrl: ''),
        ),
        ReplyPresentation.line,
      );
    });
  });

  group('ReplyTarget', () {
    Widget host(
      Post p, {
      bool compact = false,
      VoidCallback? onOpenPost,
      ReplySlot slot = ReplySlot.belowBody,
    }) => ProviderScope(
      // Without TDLib every file stays "not downloaded", as on a first frame.
      overrides: [
        fileDownloadProvider.overrideWith((ref, fileId) => Stream.value(null)),
        // TDLib knows nothing of the quoted chat.
        chatIdentityProvider.overrideWith(
          (ref, chatId) => (
            title: null,
            avatarPath: null,
            avatarFileId: null,
            username: null,
            isVerified: false,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ReplyTarget(
            post: p,
            slot: slot,
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
        host(
          post(replyToMessageId: 4, replyToAuthorTitle: 'Ada Lovelace'),
          slot: ReplySlot.aboveBody,
        ),
      );
      expect(
        find.text(AppStrings.chatReplyingToName('Ada Lovelace')),
        findsOneWidget,
      );
      expect(find.byType(QuotedPostCard), findsNothing);
    });

    testWidgets('the card carries the quoted byline and words', (tester) async {
      await tester.pumpWidget(
        host(
          post(
            replyToMessageId: 4,
            replyToAuthorTitle: 'Ada Lovelace',
            replyToText: 'the analytical engine',
          ),
        ),
      );
      expect(find.byType(QuotedPostCard), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('the analytical engine'), findsOneWidget);
    });

    // Comments already sit inside a thread; a card would nest another box.
    testWidgets('compact keeps the line even with words to quote', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          post(
            replyToMessageId: 4,
            replyToAuthorTitle: 'Ada Lovelace',
            replyToText: 'the analytical engine',
          ),
          compact: true,
          slot: ReplySlot.aboveBody,
        ),
      );
      expect(find.byType(QuotedPostCard), findsNothing);
      expect(
        find.text(AppStrings.chatReplyingToName('Ada Lovelace')),
        findsOneWidget,
      );
      // The words still show, under the line rather than in a box.
      expect(find.text('the analytical engine'), findsOneWidget);
    });

    testWidgets('a reply with no named author falls back to this channel', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(post(replyToMessageId: 4), slot: ReplySlot.aboveBody),
      );
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

    // The host draws the passage above the post; PostCard tests that it does.
    testWidgets('ReplyTarget leaves a passage to the host', (tester) async {
      await tester.pumpWidget(
        host(
          post(
            replyToMessageId: 4,
            replyToAuthorTitle: 'Ada Lovelace',
            replyToText: 'the part they picked',
            replyToIsQuote: true,
          ),
        ),
      );
      expect(find.byType(QuotedPostCard), findsNothing);
      expect(find.byType(QuotedPassage), findsNothing);
      expect(find.text('the part they picked'), findsNothing);
    });

    // A comment already hangs on a thread connector; a second one would nest.
    testWidgets('a comment shows a passage as the line, not a connector', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          post(
            replyToMessageId: 4,
            replyToAuthorTitle: 'Ada Lovelace',
            replyToText: 'the part they picked',
            replyToIsQuote: true,
          ),
          compact: true,
          slot: ReplySlot.aboveBody,
        ),
      );
      expect(find.byType(QuotedPassage), findsNothing);
      expect(
        find.text(AppStrings.chatReplyingToName('Ada Lovelace')),
        findsOneWidget,
      );
      expect(find.text('the part they picked'), findsOneWidget);
    });

    // A quote of another channel must not wear this channel's avatar or tick.
    testWidgets('a cross-chat quote borrows no identity from this post', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          post(
            replyToMessageId: 4,
            replyToChatId: -200,
            replyToAuthorTitle: 'Ada Lovelace',
            replyToText: 'the analytical engine',
            isChannelVerified: true,
          ),
        ),
      );

      final card = tester.widget<QuotedPostCard>(find.byType(QuotedPostCard));
      expect(card.authorTitle, 'Ada Lovelace');
      expect(card.avatarFileId, isNull);
      expect(card.authorUsername, isNull);
      expect(card.isAuthorVerified, isFalse);
    });

    testWidgets('a reply within this channel keeps its face and tick', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          post(
            replyToMessageId: 4,
            replyToText: 'the analytical engine',
            isChannelVerified: true,
          ),
        ),
      );

      final card = tester.widget<QuotedPostCard>(find.byType(QuotedPostCard));
      expect(card.avatarFileId, 77);
      expect(card.authorUsername, 'nasadaily');
      expect(card.isAuthorVerified, isTrue);
    });

    // Each shape belongs to one slot, since the host draws ReplyTarget in both.
    group('slots', () {
      final replied = post(
        replyToMessageId: 4,
        replyToAuthorTitle: 'Ada Lovelace',
        replyToText: 'the analytical engine',
      );
      final bare = post(replyToMessageId: 4, replyToAuthorTitle: 'Ada');

      testWidgets('the card is below the body and nowhere else', (
        tester,
      ) async {
        await tester.pumpWidget(host(replied, slot: ReplySlot.belowBody));
        expect(find.byType(QuotedPostCard), findsOneWidget);

        await tester.pumpWidget(host(replied, slot: ReplySlot.aboveBody));
        expect(find.byType(QuotedPostCard), findsNothing);
      });

      testWidgets('the line is above the body and nowhere else', (
        tester,
      ) async {
        await tester.pumpWidget(host(bare, slot: ReplySlot.aboveBody));
        expect(find.text(AppStrings.chatReplyingToName('Ada')), findsOneWidget);

        await tester.pumpWidget(host(bare, slot: ReplySlot.belowBody));
        expect(find.text(AppStrings.chatReplyingToName('Ada')), findsNothing);
      });
    });
  });

  // As X draws a quote: the author's face, handle and badge, when it was
  // posted, and its picture at its own shape.
  group('QuotedPostCard', () {
    Widget host(Widget card, {ChatIdentity? chat}) => ProviderScope(
      overrides: [
        fileDownloadProvider.overrideWith((ref, fileId) => Stream.value(null)),
        chatIdentityProvider.overrideWith(
          (ref, chatId) =>
              chat ??
              (
                title: null,
                avatarPath: null,
                avatarFileId: null,
                username: null,
                isVerified: false,
              ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: card)),
    );

    testWidgets('names another chat by what TDLib knows of it', (tester) async {
      await tester.pumpWidget(
        host(
          const QuotedPostCard(
            authorTitle: 'adidas Football',
            authorChatId: -200,
            text: 'thank you for loving me so much',
          ),
          chat: (
            title: null,
            avatarPath: null,
            avatarFileId: 7,
            username: 'adidasfootball',
            isVerified: true,
          ),
        ),
      );

      expect(find.text('@adidasfootball'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(
        tester.widget<ChannelAvatar>(find.byType(ChannelAvatar)).avatarFileId,
        7,
      );
    });

    testWidgets('says when the quoted post was sent', (tester) async {
      await tester.pumpWidget(
        host(
          QuotedPostCard(
            authorTitle: 'adidas Football',
            date: DateTime.now().subtract(const Duration(hours: 9)),
          ),
        ),
      );

      expect(find.text('· 9h'), findsOneWidget);
    });

    // On a phone's width, where the card is about 340 points across.
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('draws the picture at its own shape', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          const QuotedPostCard(
            authorTitle: 'adidas Football',
            thumbnailFileId: 5,
            mediaWidth: 1600,
            mediaHeight: 900,
          ),
        ),
      );

      final size = tester.getSize(find.byKey(QuotedPostCard.mediaKey));
      expect(size.width / size.height, closeTo(16 / 9, 0.01));
    });

    testWidgets('keeps a tall picture from taking over the card', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          const QuotedPostCard(
            authorTitle: 'adidas Football',
            thumbnailFileId: 5,
            mediaWidth: 900,
            mediaHeight: 1600,
          ),
        ),
      );

      final size = tester.getSize(find.byKey(QuotedPostCard.mediaKey));
      expect(size.height, 320);
      expect(tester.takeException(), isNull);
    });
  });

  group('QuotedPassage', () {
    Widget host(Widget child) => ProviderScope(
      overrides: [
        fileDownloadProvider.overrideWith((ref, fileId) => Stream.value(null)),
        // TDLib knows nothing of the quoted chat.
        chatIdentityProvider.overrideWith(
          (ref, chatId) => (
            title: null,
            avatarPath: null,
            avatarFileId: null,
            username: null,
            isVerified: false,
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

    // A passage from another channel, whose name the reply didn't carry: it
    // was drawn with no face and no name.
    testWidgets('names another chat by what TDLib knows of it', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileDownloadProvider.overrideWith(
              (ref, fileId) => Stream.value(null),
            ),
            chatIdentityProvider.overrideWith(
              (ref, chatId) => (
                title: 'The Chill Coding Lounge',
                avatarPath: null,
                avatarFileId: 11,
                username: 'chillcoding',
                isVerified: false,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuotedPassage(
                authorChatId: -300,
                passage: "I'm starting to hate mediocrity",
              ),
            ),
          ),
        ),
      );

      expect(find.text('The Chill Coding Lounge'), findsOneWidget);
      expect(find.text('@chillcoding'), findsOneWidget);
      expect(
        tester.widget<ChannelAvatar>(find.byType(ChannelAvatar)).avatarFileId,
        11,
      );
    });

    testWidgets('draws the selected words under their author', (tester) async {
      await tester.pumpWidget(
        host(
          const QuotedPassage(
            authorTitle: 'Ada Lovelace',
            authorUsername: 'ada',
            passage: 'the part they picked',
          ),
        ),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('@ada'), findsOneWidget);
      expect(find.text('the part they picked'), findsOneWidget);
    });

    // A quoted fragment cannot be liked, forwarded or bookmarked.
    testWidgets('carries no action bar', (tester) async {
      await tester.pumpWidget(
        host(
          const QuotedPassage(
            authorTitle: 'Ada Lovelace',
            passage: 'the part they picked',
          ),
        ),
      );

      expect(find.byType(PostActionBar), findsNothing);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      expect(find.byIcon(Icons.repeat), findsNothing);
    });

    testWidgets('the whole block opens what it came out of', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          QuotedPassage(
            authorTitle: 'Ada Lovelace',
            passage: 'the part they picked',
            onTap: () => opened++,
          ),
        ),
      );

      await tester.tap(find.text('the part they picked'));
      expect(opened, 1);
    });

    // Unlike the card, the passage is never clamped: the writer chose them.
    testWidgets('a long passage is not truncated', (tester) async {
      final long = List.filled(40, 'word').join(' ');
      await tester.pumpWidget(
        host(QuotedPassage(authorTitle: 'Ada Lovelace', passage: long)),
      );

      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    });

    // With no known author, the byline is left out rather than borrowed.
    testWidgets('an unattributed passage draws no byline', (tester) async {
      await tester.pumpWidget(
        host(const QuotedPassage(passage: 'the part they picked')),
      );

      expect(find.text('the part they picked'), findsOneWidget);
      expect(find.byType(ChannelAvatar), findsNothing);
    });

    testWidgets('and still leads to where it came from', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          QuotedPassage(passage: 'the part they picked', onTap: () => opened++),
        ),
      );

      await tester.tap(find.text('the part they picked'));
      expect(opened, 1);
    });

    // The height follows the content, so a short passage needs a minimum.
    testWidgets('a short passage still gets a connector you can see', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const QuotedPassage(authorTitle: 'Ada', passage: 'short')),
      );

      final height = tester.getSize(find.byType(QuotedPassage)).height;
      expect(
        height,
        greaterThanOrEqualTo(
          AppSpacing.avatarSize + QuotedPassage.minConnectorRun,
        ),
      );
    });

    testWidgets('a long passage is given more, not clamped to the floor', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const QuotedPassage(authorTitle: 'Ada', passage: 'short')),
      );
      final short = tester.getSize(find.byType(QuotedPassage)).height;

      await tester.pumpWidget(
        host(
          QuotedPassage(
            authorTitle: 'Ada',
            passage: List.filled(40, 'word').join(' '),
          ),
        ),
      );
      final long = tester.getSize(find.byType(QuotedPassage)).height;

      expect(long, greaterThan(short));
    });
  });
}
