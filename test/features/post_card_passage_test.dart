import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/features/feed/presentation/widgets/reply_target.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/telegram/chat_identity.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// `ReplyTarget` does not draw a quoted passage: the card places it above the
/// post, so these tests catch a passage that silently goes missing.
Post post({
  String? replyToText,
  bool replyToIsQuote = false,
  int? replyToMessageId,
}) => Post(
  id: '-100_5',
  chatId: -100,
  channelId: '-100',
  messageId: 5,
  channelTitle: 'Nasa Daily',
  channelUsername: 'nasadaily',
  text: 'the reply itself',
  publishedAt: DateTime(2026, 8, 30, 12),
  replyToText: replyToText,
  replyToIsQuote: replyToIsQuote,
  replyToAuthorTitle: 'Ada Lovelace',
  replyToMessageId: replyToMessageId,
);

void main() {
  Widget host(Post p) => ProviderScope(
    overrides: [
      fileDownloadProvider.overrideWith((ref, fileId) => Stream.value(null)),
      // The action bar reads the auth state from TDLib, which is absent here.
      readerCapabilitiesProvider.overrideWithValue(ReaderCapabilities.signedIn),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: PostCard(post: p)),
      ),
    ),
  );

  testWidgets('the card draws the passage it singles out', (tester) async {
    await tester.pumpWidget(
      host(
        post(
          replyToMessageId: 4,
          replyToText: 'the part they picked',
          replyToIsQuote: true,
        ),
      ),
    );

    expect(find.byType(QuotedPassage), findsOneWidget);
    expect(find.text('the part they picked'), findsOneWidget);
    expect(find.text('the reply itself'), findsOneWidget);
  });

  /// Above the post, not inside it, so the connector can reach the avatar.
  testWidgets('the passage stands above the reply', (tester) async {
    await tester.pumpWidget(
      host(
        post(
          replyToMessageId: 4,
          replyToText: 'the part they picked',
          replyToIsQuote: true,
        ),
      ),
    );

    final passage = tester.getTopLeft(find.text('the part they picked'));
    final reply = tester.getTopLeft(find.text('the reply itself'));
    expect(passage.dy, lessThan(reply.dy));
  });

  testWidgets('the passage adds no second action bar', (tester) async {
    await tester.pumpWidget(
      host(
        post(
          replyToMessageId: 4,
          replyToText: 'the part they picked',
          replyToIsQuote: true,
        ),
      ),
    );

    expect(find.byType(PostActionBar), findsOneWidget);
    final bar = tester.getTopLeft(find.byType(PostActionBar));
    expect(
      bar.dy,
      greaterThan(tester.getTopLeft(find.text('the reply itself')).dy),
    );
  });

  testWidgets('a whole-post reply gets the card, not the passage', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(post(replyToMessageId: 4, replyToText: 'the whole original post')),
    );

    expect(find.byType(QuotedPassage), findsNothing);
    expect(find.byType(QuotedPostCard), findsOneWidget);
  });

  testWidgets('a post that answers nothing draws neither', (tester) async {
    await tester.pumpWidget(host(post()));

    expect(find.byType(QuotedPassage), findsNothing);
    expect(find.byType(QuotedPostCard), findsNothing);
  });

  /// The reply's own words come first, then the post it quotes.
  group('the quote card sits under the answer', () {
    Post quoting() => Post(
      id: '-100_5',
      chatId: -100,
      channelId: '-100',
      messageId: 5,
      channelTitle: 'Nasa Daily',
      text: 'Extending consciousness beyond Earth',
      publishedAt: DateTime(2026, 8, 30, 12),
      replyToMessageId: 4,
      replyToAuthorTitle: 'Deep Freeze',
      replyToText: "SpaceX's road to making humanity multiplanetary",
    );

    testWidgets('below the reply\'s own words', (tester) async {
      await tester.pumpWidget(host(quoting()));

      final own = tester.getTopLeft(
        find.text('Extending consciousness beyond Earth'),
      );
      final quoted = tester.getTopLeft(find.byType(QuotedPostCard));
      expect(quoted.dy, greaterThan(own.dy));
    });

    testWidgets('and above the action bar, which belongs to the reply', (
      tester,
    ) async {
      await tester.pumpWidget(host(quoting()));

      final quoted = tester.getTopLeft(find.byType(QuotedPostCard));
      final bar = tester.getTopLeft(find.byType(PostActionBar));
      expect(bar.dy, greaterThan(quoted.dy));
    });

    // ReplyTarget is drawn in both slots; a shape matching both shows twice.
    testWidgets('exactly once', (tester) async {
      await tester.pumpWidget(host(quoting()));
      expect(find.byType(QuotedPostCard), findsOneWidget);
    });

    // The line gives context for the words, so it stays above them.
    testWidgets('the line still comes before the words', (tester) async {
      await tester.pumpWidget(host(post(replyToMessageId: 4)));

      final line = tester.getTopLeft(find.textContaining('Replying to'));
      final own = tester.getTopLeft(find.text('the reply itself'));
      expect(line.dy, lessThan(own.dy));
    });
  });

  // A forward whose original channel arrived after the post was mapped read
  // "Original Channel", with a blank face.
  testWidgets('a repost names its original channel as TDLib knows it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileDownloadProvider.overrideWith(
            (ref, fileId) => Stream.value(null),
          ),
          readerCapabilitiesProvider.overrideWithValue(
            ReaderCapabilities.signedIn,
          ),
          chatIdentityProvider.overrideWith(
            (ref, chatId) => (
              title: 'WTM Ethiopia',
              avatarPath: null,
              avatarFileId: 21,
              username: 'Womentechmakers',
              isVerified: true,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCard(
                post: post().copyWith(forwardedFromChatId: '-1009876'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('WTM Ethiopia'), findsOneWidget);
    expect(find.text('Original Channel'), findsNothing);
    expect(find.text('@Womentechmakers'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });
}
