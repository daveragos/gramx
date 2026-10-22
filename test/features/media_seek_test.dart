import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/media_seek.dart';

/// Which media a timestamp such as "1:23" in a caption plays.
void main() {
  MediaItem item(MediaType type, {int? fileId = 1, String? url}) =>
      MediaItem(id: '$type$fileId', type: type, fileId: fileId, url: url);

  test('the first video or track after any photos', () {
    final photo = item(MediaType.photo);
    final video = item(MediaType.video, fileId: 2);
    final track = item(MediaType.audio, fileId: 3);

    expect(timestampTarget([photo, video, track]), video);
    expect(timestampTarget([photo, track]), track);
  });

  test('a voice message counts', () {
    final voice = item(MediaType.voice);
    expect(timestampTarget([voice]), voice);
  });

  test('photos, documents and stickers have no time to seek to', () {
    expect(
      timestampTarget([
        item(MediaType.photo),
        item(MediaType.document),
        item(MediaType.sticker),
      ]),
      isNull,
    );
  });

  test('a track without a file has nothing to play', () {
    expect(timestampTarget([item(MediaType.audio, fileId: null)]), isNull);
  });

  // Guest videos have no TDLib file, only the CDN address.
  test('a guest video plays from its address', () {
    final guest = item(
      MediaType.video,
      fileId: null,
      url: 'https://cdn4.telesco.pe/file/a.mp4',
    );
    expect(timestampTarget([guest]), guest);
  });

  // The same track can be on screen twice, in a post and a repost of it, or
  // in the feed under an open post. The tap must start only the one beside
  // the text.
  testWidgets('a timestamp reaches only the players in its own scope', (
    tester,
  ) async {
    late BuildContext tappedIn;
    ValueListenable<MediaSeekRequest?>? here;
    ValueListenable<MediaSeekRequest?>? elsewhere;

    await tester.pumpWidget(
      Column(
        children: [
          MediaSeekScope(
            child: Builder(
              builder: (context) {
                tappedIn = context;
                here = MediaSeekScope.of(context);
                return const SizedBox();
              },
            ),
          ),
          MediaSeekScope(
            child: Builder(
              builder: (context) {
                elsewhere = MediaSeekScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );

    final track = item(MediaType.audio, fileId: 9);
    playFromTimestamp(tappedIn, [track])!(83);

    expect(here!.value?.fileId, 9);
    expect(here!.value?.position, const Duration(seconds: 83));
    expect(elsewhere!.value, isNull);
  });
}
