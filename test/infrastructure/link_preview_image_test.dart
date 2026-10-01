import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:handy_tdlib/api.dart' as td;

Map<String, dynamic> fileJson(int id, {String path = ''}) => {
  '@type': 'file',
  'id': id,
  'size': 1024,
  'expected_size': 1024,
  'local': {
    '@type': 'localFile',
    'path': path,
    'can_be_downloaded': true,
    'can_be_deleted': false,
    'is_downloading_active': false,
    'is_downloading_completed': path.isNotEmpty,
    'download_offset': 0,
    'downloaded_prefix_size': 0,
    'downloaded_size': path.isNotEmpty ? 1024 : 0,
  },
  'remote': {
    '@type': 'remoteFile',
    'id': 'remote-$id',
    'unique_id': 'unique-$id',
    'is_uploading_active': false,
    'is_uploading_completed': true,
    'uploaded_size': 1024,
  },
};

/// A photo with two sizes: the mapper should reach for the larger one.
Map<String, dynamic> photoJson({int smallId = 1, int largeId = 2}) => {
  '@type': 'photo',
  'has_stickers': false,
  'sizes': [
    {
      '@type': 'photoSize',
      'type': 'm',
      'photo': fileJson(smallId),
      'width': 320,
      'height': 180,
      'progressive_sizes': <int>[],
    },
    {
      '@type': 'photoSize',
      'type': 'x',
      'photo': fileJson(largeId),
      'width': 1280,
      'height': 720,
      'progressive_sizes': <int>[],
    },
  ],
};

td.File? imageOf(Map<String, dynamic> typeJson) =>
    TdlibMappers.linkPreviewImage(td.LinkPreviewType.fromJson(typeJson));

void main() {
  group('linkPreviewImage', () {
    // Embedded players carry their thumbnail as a Photo, not on a Video.
    test('an embedded video player — a YouTube link — has its thumbnail', () {
      final image = imageOf({
        '@type': 'linkPreviewTypeEmbeddedVideoPlayer',
        'url': 'https://www.youtube.com/embed/abc',
        'thumbnail': photoJson(),
        'duration': 212,
        'width': 1280,
        'height': 720,
      });

      expect(image, isNotNull);
      expect(image!.id, 2, reason: 'the largest size is the one worth showing');
    });

    test('an embedded audio player too', () {
      final image = imageOf({
        '@type': 'linkPreviewTypeEmbeddedAudioPlayer',
        'url': 'https://soundcloud.com/embed',
        'thumbnail': photoJson(),
        'duration': 180,
        'width': 640,
        'height': 640,
      });

      expect(image?.id, 2);
    });

    test('an article keeps working', () {
      final image = imageOf({
        '@type': 'linkPreviewTypeArticle',
        'photo': photoJson(),
      });

      expect(image?.id, 2);
    });

    test('a plain photo keeps working', () {
      final image = imageOf({
        '@type': 'linkPreviewTypePhoto',
        'photo': photoJson(),
      });

      expect(image?.id, 2);
    });

    test('a shared album uses its first picture', () {
      final image = imageOf({
        '@type': 'linkPreviewTypeAlbum',
        'caption': '',
        'media': [
          {
            '@type': 'linkPreviewAlbumMediaPhoto',
            'photo': photoJson(smallId: 7, largeId: 8),
          },
        ],
      });

      expect(image?.id, 8);
    });

    // No thumbnail means a card with no banner, not an empty grey box.
    test('a player with no thumbnail has no image', () {
      final image = imageOf({
        '@type': 'linkPreviewTypeEmbeddedVideoPlayer',
        'url': 'https://example.com/embed',
        'thumbnail': null,
        'duration': 0,
        'width': 0,
        'height': 0,
      });

      expect(image, isNull);
    });

    test('a link with nothing visual to show has no image', () {
      final image = imageOf({'@type': 'linkPreviewTypeUnsupported'});

      expect(image, isNull);
    });
  });
}
