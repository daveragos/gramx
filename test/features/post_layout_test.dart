import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_action_bar.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/guest/domain/reader_capabilities.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

import '../support/td_fixtures.dart';

void main() {
  // With auto-download off, a photo nobody tapped is incomplete but idle. It
  // read as loading, and its spinner never stopped.
  group('FileDownloadProgressState', () {
    td.File file({bool active = false, String localPath = ''}) {
      final json = TdFixtures.fileJson(id: 9, localPath: localPath);
      (json['local'] as Map<String, dynamic>)['is_downloading_active'] = active;
      return td.File.fromJson(json);
    }

    test('a file nobody asked for is not downloading', () {
      final state = FileDownloadProgressState.of(file());
      expect(state.isCompleted, isFalse);
      expect(state.isDownloading, isFalse);
    });

    test('a file TDLib is fetching is', () {
      expect(
        FileDownloadProgressState.of(file(active: true)).isDownloading,
        isTrue,
      );
    });

    test('a finished file has its path', () {
      final state = FileDownloadProgressState.of(file(localPath: '/tmp/a.jpg'));
      expect(state.isCompleted, isTrue);
      expect(state.localPath, '/tmp/a.jpg');
    });
  });

  // A photo shows a small size while the full one loads, then sharpens.
  group('TdlibMappers.previewPhotoSize', () {
    td.PhotoSize size(String type, int width) => td.PhotoSize(
      type: type,
      photo: td.File.fromJson(TdFixtures.fileJson(id: width)),
      width: width,
      height: width * 3 ~/ 4,
      progressiveSizes: const [],
    );

    test('takes the largest small size, not the smallest', () {
      final sizes = [
        size('s', 90),
        size('m', 320),
        size('x', 800),
        size('y', 1280),
      ];
      expect(TdlibMappers.previewPhotoSize(sizes)?.type, 'm');
    });

    test('never the full size itself', () {
      final sizes = [size('m', 320), size('x', 800)];
      expect(TdlibMappers.previewPhotoSize(sizes)?.type, 'm');
    });

    test('falls back to the smallest when every size is large', () {
      final sizes = [size('x', 800), size('y', 1280)];
      expect(TdlibMappers.previewPhotoSize(sizes)?.type, 'x');
    });

    test('has none for a photo with one size', () {
      expect(TdlibMappers.previewPhotoSize([size('y', 1280)]), isNull);
    });
  });

  // Several photos sit side by side at one height, scrolling sideways.
  group('PostMediaGrid.rowItemWidth', () {
    MediaItem photo(int width, int height) =>
        MediaItem(id: '1', type: MediaType.photo, width: width, height: height);

    test('keeps a photo at its own shape', () {
      expect(
        PostMediaGrid.rowItemWidth(photo(400, 300), height: 200, maxWidth: 300),
        closeTo(266.7, 0.1),
      );
    });

    test('stops a wide photo short of the row, so the next one shows', () {
      expect(
        PostMediaGrid.rowItemWidth(
          photo(1600, 900),
          height: 200,
          maxWidth: 300,
        ),
        300,
      );
    });

    test('keeps a tall photo at least half as wide as the row is high', () {
      expect(
        PostMediaGrid.rowItemWidth(
          photo(300, 1200),
          height: 200,
          maxWidth: 300,
        ),
        100,
      );
    });

    test('draws a photo of unknown size square', () {
      expect(
        PostMediaGrid.rowItemWidth(photo(0, 0), height: 200, maxWidth: 300),
        200,
      );
    });
  });

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
