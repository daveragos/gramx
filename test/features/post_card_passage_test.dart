import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/features/feed/presentation/widgets/reply_target.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// A quoted passage is the one shape `ReplyTarget` does **not** draw: it
/// stands above the post, in the avatar gutter, so the host places it. That
/// makes forgetting to place it silent — the reply target would simply vanish
/// and look like a post that answers nothing. This is the guard.
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
          // The action bar asks whether this reader may act. Deciding that
          // walks the auth state into TDLib, which is not here.
          readerCapabilitiesProvider
              .overrideWithValue(ReaderCapabilities.signedIn),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PostCard(post: p))),
        ),
      );

  testWidgets('the card draws the passage it singles out', (tester) async {
    await tester.pumpWidget(host(post(
      replyToMessageId: 4,
      replyToText: 'the part they picked',
      replyToIsQuote: true,
    )));

    expect(find.byType(QuotedPassage), findsOneWidget);
    expect(find.text('the part they picked'), findsOneWidget);
    expect(find.text('the reply itself'), findsOneWidget);
  });

  /// The passage sits above the post, not inside it — which is what lets the
  /// connector run down into the reply's own avatar.
  testWidgets('the passage stands above the reply', (tester) async {
    await tester.pumpWidget(host(post(
      replyToMessageId: 4,
      replyToText: 'the part they picked',
      replyToIsQuote: true,
    )));

    final passage = tester.getTopLeft(find.text('the part they picked'));
    final reply = tester.getTopLeft(find.text('the reply itself'));
    expect(passage.dy, lessThan(reply.dy));
  });

  /// One action bar on the card, and none on the passage. The reply keeps
  /// every control; the fragment it quotes gets none.
  testWidgets('the passage adds no second action bar', (tester) async {
    await tester.pumpWidget(host(post(
      replyToMessageId: 4,
      replyToText: 'the part they picked',
      replyToIsQuote: true,
    )));

    expect(find.byType(PostActionBar), findsOneWidget);
    final bar = tester.getTopLeft(find.byType(PostActionBar));
    expect(bar.dy, greaterThan(tester.getTopLeft(find.text('the reply itself')).dy));
  });

  testWidgets('a whole-post reply gets the card, not the passage',
      (tester) async {
    await tester.pumpWidget(host(post(
      replyToMessageId: 4,
      replyToText: 'the whole original post',
    )));

    expect(find.byType(QuotedPassage), findsNothing);
    expect(find.byType(QuotedPostCard), findsOneWidget);
  });

  testWidgets('a post that answers nothing draws neither', (tester) async {
    await tester.pumpWidget(host(post()));

    expect(find.byType(QuotedPassage), findsNothing);
    expect(find.byType(QuotedPostCard), findsNothing);
  });
}
