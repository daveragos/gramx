import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';

void main() {
  MediaItem item(MediaType type, {String? fileName}) =>
      MediaItem(id: 'x', type: type, fileName: fileName);

  group('describeMedia', () {
    test('names each media kind', () {
      expect(describeMedia(item(MediaType.photo), 0, 1), 'Photo');
      expect(describeMedia(item(MediaType.video), 0, 1), 'Video');
      expect(describeMedia(item(MediaType.gif), 0, 1), 'GIF');
      expect(describeMedia(item(MediaType.sticker), 0, 1), 'Sticker');
      expect(describeMedia(item(MediaType.voice), 0, 1), 'Voice message');
    });

    test('prefers a real filename for documents and audio', () {
      expect(
        describeMedia(item(MediaType.document, fileName: 'report.pdf'), 0, 1),
        'report.pdf',
      );
      expect(
        describeMedia(item(MediaType.audio, fileName: 'song.mp3'), 0, 1),
        'song.mp3',
      );
    });

    test('falls back when a filename is missing', () {
      expect(describeMedia(item(MediaType.document), 0, 1), 'Document');
      expect(describeMedia(item(MediaType.audio), 0, 1), 'Audio track');
    });

    test('gives position within an album', () {
      expect(describeMedia(item(MediaType.photo), 0, 4), 'Photo 1 of 4');
      expect(describeMedia(item(MediaType.photo), 3, 4), 'Photo 4 of 4');
    });

    test('omits the position for a single item', () {
      expect(describeMedia(item(MediaType.video), 0, 1), 'Video');
    });

    test('is never empty for any media type', () {
      for (final type in MediaType.values) {
        expect(
          describeMedia(item(type), 0, 1),
          isNotEmpty,
          reason: '$type needs a description',
        );
      }
    });
  });
}
