import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/widgets/shell_fab.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
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

  // One button for the whole shell, as on X.
  group('the shell button', () {
    Widget shell(ShellTab tab, {bool canCompose = true}) => ProviderScope(
      overrides: [canComposeProvider.overrideWithValue(canCompose)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: ShellFab(tab: tab)),
        ),
      ),
    );

    testWidgets('composes on Home', (tester) async {
      await tester.pumpWidget(shell(ShellTab.home));
      expect(find.byTooltip(AppStrings.a11yCompose), findsOneWidget);
    });

    testWidgets('starts a chat on Messages', (tester) async {
      await tester.pumpWidget(shell(ShellTab.messages));
      expect(find.byTooltip(AppStrings.messagesNewChat), findsOneWidget);
    });

    testWidgets('turns its icon over going from Home to Messages', (
      tester,
    ) async {
      await tester.pumpWidget(shell(ShellTab.home));
      final button = tester.element(find.byType(FloatingActionButton));

      await tester.pumpWidget(shell(ShellTab.messages));
      await tester.pump(ShellFab.duration ~/ 2);

      // The same button, with both icons on it mid-turn.
      expect(tester.element(find.byType(FloatingActionButton)), button);
      expect(find.byIcon(ShellFabAction.compose.icon), findsOneWidget);
      expect(find.byIcon(ShellFabAction.newChat.icon), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byIcon(ShellFabAction.compose.icon), findsNothing);
      expect(find.byIcon(ShellFabAction.newChat.icon), findsOneWidget);
    });

    testWidgets('shrinks away on a tab without an action', (tester) async {
      await tester.pumpWidget(shell(ShellTab.home));
      await tester.pumpWidget(shell(ShellTab.search));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('is absent on Home with nowhere to post', (tester) async {
      await tester.pumpWidget(shell(ShellTab.home, canCompose: false));
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('is gone entirely once the chrome retires', (tester) async {
      await tester.pumpWidget(shell(ShellTab.home));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ShellFab)),
      );

      container
          .read(chromeOffsetProvider.notifier)
          .onScroll(delta: 200, extent: 100, pixels: 200);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('is a circle', (tester) async {
      await tester.pumpWidget(shell(ShellTab.home));
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
