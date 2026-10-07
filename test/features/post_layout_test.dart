import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

void main() {
  group('PostActionBar', () {
    Post post() => Post(
      id: '-100123_4194304',
      chatId: -100123,
      channelId: '-100123',
      messageId: 4194304,
      channelTitle: 'gramX',
      publishedAt: DateTime(2026, 10, 7),
      replyCount: 3,
    );

    Widget host({required VoidCallback onReplyTap}) => ProviderScope(
      overrides: [
        readerCapabilitiesProvider.overrideWithValue(
          ReaderCapabilities.signedIn,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: PostActionBar(
                post: post(),
                secondaryColor: const Color(0xFF71767B),
                onBookmarkTap: () {},
                onSelectReaction: (_) {},
                onReplyTap: onReplyTap,
                onShareTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    // The icons are 18 points; a tap needed to land on one.
    testWidgets('an action answers anywhere in its cell, not just its icon', (
      tester,
    ) async {
      var replies = 0;
      await tester.pumpWidget(host(onReplyTap: () => replies++));

      final icon = tester.getCenter(find.byIcon(Icons.chat_bubble_outline));
      // Well to the right of the icon and its count, and below it.
      await tester.tapAt(icon + const Offset(40, 9));

      expect(replies, 1);
    });

    testWidgets('is tall enough to hit', (tester) async {
      await tester.pumpWidget(host(onReplyTap: () {}));

      expect(
        tester.getSize(find.byType(PostActionBar)).height,
        greaterThanOrEqualTo(18 + 2 * PostActionBar.touchSlop),
      );
    });
  });
}
