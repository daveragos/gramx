import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/features/compose/presentation/widgets/compose_fab.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/pending_posts_provider.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_image_viewer.dart';
import 'package:gramx/features/feed/presentation/widgets/post_document_card.dart';

Post post(String id, {int chatId = -100, int minutesAgo = 1}) => Post(
  id: id,
  chatId: chatId,
  channelId: '$chatId',
  messageId: int.parse(id.split('_').last),
  channelTitle: 'Channel $chatId',
  publishedAt: DateTime(
    2026,
    8,
    28,
    12,
  ).subtract(Duration(minutes: minutesAgo)),
);

void main() {
  Widget host(Widget child) => ProviderScope(child: MaterialApp(home: child));

  // The scaffold removes the button with the chrome rather than sliding it by
  // a measured offset.
  group('the compose button leaves with the chrome', () {
    Widget scaffold() => host(
      ChromeScaffold(
        header: const SizedBox(),
        floatingActionButton: const ComposeFab(),
        body: (context, top, bottom) => const SizedBox(),
      ),
    );

    testWidgets('is on screen while the chrome is', (tester) async {
      await tester.pumpWidget(scaffold());
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('is gone entirely once the chrome retires', (tester) async {
      await tester.pumpWidget(scaffold());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChromeScaffold)),
      );

      container
          .read(chromeOffsetProvider.notifier)
          .onScroll(delta: 200, extent: 100, pixels: 200);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('is a circle', (tester) async {
      await tester.pumpWidget(scaffold());
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      expect(fab.shape, isA<CircleBorder>());
    });
  });

  // The pill shows who posted, not just how many.
  group('pillAvatarPosts', () {
    test('one face per channel, however many it posted', () {
      final faces = pillAvatarPosts([
        post('-100_3'),
        post('-100_2'),
        post('-200_1', chatId: -200),
        post('-100_1'),
      ]);

      expect(faces.map((p) => p.chatId), [-100, -200]);
    });

    test('stops at the cap rather than becoming a texture', () {
      final faces = pillAvatarPosts([
        for (var i = 1; i <= 8; i++) post('-${i}00_1', chatId: -i * 100),
      ]);

      expect(faces, hasLength(3));
    });

    test('keeps the order it was given, which is newest first', () {
      final faces = pillAvatarPosts([
        post('-300_1', chatId: -300),
        post('-100_1', chatId: -100),
      ]);

      expect(faces.map((p) => p.chatId), [-300, -100]);
    });

    test('nothing pending means no faces', () {
      expect(pillAvatarPosts(const []), isEmpty);
    });
  });

  // Only the leading circle, which doubles as the progress ring, shows a
  // download icon.
  group('PostDocumentCard', () {
    testWidgets('an undownloaded file shows one download icon, not two', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Scaffold(
            body: PostDocumentCard(
              item: MediaItem(
                id: 'doc',
                type: MediaType.document,
                fileName: 'report.pdf',
                fileSize: 2048,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });
  });

  // A photo still downloading has no local path yet, so the viewer opens on
  // the file id.
  group('ViewerImage', () {
    test('a file id alone is enough to open on', () {
      const image = ViewerImage(fileId: 42);
      expect(image.hasSource, isTrue);
    });

    test('carries the file id across, not just whatever string it had', () {
      const item = MediaItem(
        id: 'photo',
        type: MediaType.photo,
        url: 'AgACAgQAAx0-remote-id',
        fileId: 42,
        minithumbnail: 'AAAA',
      );
      final image = ViewerImage.of(item);

      expect(image.fileId, 42);
      expect(image.minithumbnail, 'AAAA');
    });

    test('a downloaded path wins over the placeholder string', () {
      const item = MediaItem(
        id: 'photo',
        type: MediaType.photo,
        url: 'AgACAgQAAx0-remote-id',
        fileId: 42,
      );
      final image = ViewerImage.of(item, downloadedPath: '/tmp/photo.jpg');

      expect(image.path, '/tmp/photo.jpg');
    });

    test('an item with neither a path nor a file id is not worth opening', () {
      const item = MediaItem(id: 'photo', type: MediaType.photo);
      expect(ViewerImage.of(item).hasSource, isFalse);
    });
  });
}
