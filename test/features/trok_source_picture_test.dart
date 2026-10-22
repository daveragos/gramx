import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';

Post post({List<MediaItem> media = const [], int? linkPicture}) => Post(
  id: '-100_1048576',
  chatId: -100,
  channelId: '-100',
  messageId: 1048576,
  channelTitle: 'Durov',
  media: media,
  linkPreviewFileId: linkPicture,
  publishedAt: DateTime.utc(2026, 10, 21),
);

void main() {
  test('a photo shows its preview size, with its blurred preview', () {
    final picture = TrokSourcePicture.of(
      post(
        media: const [
          MediaItem(
            id: 'a',
            type: MediaType.photo,
            fileId: 10,
            thumbnailFileId: 11,
            minithumbnail: 'blur',
          ),
        ],
      ),
    )!;
    expect(picture.fileId, 11);
    expect(picture.minithumbnail, 'blur');
    expect(picture.isVideo, isFalse);
  });

  test('a video shows its cover, marked as a video', () {
    final picture = TrokSourcePicture.of(
      post(
        media: const [
          MediaItem(
            id: 'v',
            type: MediaType.video,
            fileId: 20,
            thumbnailFileId: 21,
          ),
        ],
      ),
    )!;
    expect(picture.fileId, 21);
    expect(picture.isVideo, isTrue);
  });

  test('a video without a cover never shows its whole file', () {
    expect(
      TrokSourcePicture.of(
        post(
          media: const [MediaItem(id: 'v', type: MediaType.video, fileId: 20)],
        ),
      ),
      isNull,
    );
  });

  test('audio is skipped for the next picture, then the link\'s', () {
    expect(
      TrokSourcePicture.of(
        post(
          media: const [
            MediaItem(
              id: 's',
              type: MediaType.audio,
              fileId: 30,
              thumbnailFileId: 31,
            ),
          ],
          linkPicture: 40,
        ),
      )!.fileId,
      40,
    );
    expect(TrokSourcePicture.of(post()), isNull);
  });
}
