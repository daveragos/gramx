import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/compose/data/compose_repository.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/voice_waveform.dart';

ComposeAttachment of(ComposeMediaKind kind, {List<int> waveform = const []}) =>
    ComposeAttachment(
      path: '/tmp/file',
      kind: kind,
      width: 100,
      height: 60,
      durationSeconds: 5,
      waveform: waveform,
    );

void main() {
  group('what each kind allows', () {
    test('a round video note takes no caption', () {
      expect(ComposeMediaKind.videoNote.takesCaption, isFalse);
      // Everything else does, including a voice note.
      for (final kind in ComposeMediaKind.values) {
        if (kind == ComposeMediaKind.videoNote) continue;
        expect(kind.takesCaption, isTrue, reason: kind.name);
      }
    });

    test('a plain document cannot be made to disappear', () {
      expect(ComposeMediaKind.document.canSelfDestruct, isFalse);
      expect(ComposeMediaKind.photo.canSelfDestruct, isTrue);
      expect(ComposeMediaKind.voiceNote.canSelfDestruct, isTrue);
    });

    test('only a spoiler-able kind offers the toggle', () {
      expect(of(ComposeMediaKind.photo).canSpoiler, isTrue);
      expect(of(ComposeMediaKind.video).canSpoiler, isTrue);
      // Telegram has no spoiler for these, so offering one would be a control
      // that changes nothing.
      expect(of(ComposeMediaKind.document).canSpoiler, isFalse);
      expect(of(ComposeMediaKind.voiceNote).canSpoiler, isFalse);
    });

    test('photos and videos share an album, documents have their own', () {
      expect(
        ComposeMediaKind.photo.albumFamily,
        ComposeMediaKind.video.albumFamily,
      );
      expect(
        ComposeMediaKind.document.albumFamily,
        isNot(ComposeMediaKind.photo.albumFamily),
      );
      expect(ComposeMediaKind.voiceNote.albumFamily, isNull);
      expect(ComposeMediaKind.videoNote.albumFamily, isNull);
    });
  });

  group('when a send becomes an album', () {
    List<td.InputMessageContent> contentsFor(List<ComposeMediaKind> kinds) =>
        ComposeMessages.build(
          text: '',
          attachments: [for (final kind in kinds) of(kind)],
        );

    test('two photos are one album', () {
      expect(
        ComposeMessages.isAlbum(
          contentsFor([ComposeMediaKind.photo, ComposeMediaKind.photo]),
        ),
        isTrue,
      );
    });

    test('a photo and a video are one album', () {
      expect(
        ComposeMessages.isAlbum(
          contentsFor([ComposeMediaKind.photo, ComposeMediaKind.video]),
        ),
        isTrue,
      );
    });

    // TDLib's rule, and the reason count alone is not enough: documents group
    // only with documents, and asking for a mixed album is refused with an
    // error that names no file.
    test('a photo and a file are two messages, not an album', () {
      expect(
        ComposeMessages.isAlbum(
          contentsFor([ComposeMediaKind.photo, ComposeMediaKind.document]),
        ),
        isFalse,
      );
    });

    test('two files are one album', () {
      expect(
        ComposeMessages.isAlbum(
          contentsFor([ComposeMediaKind.document, ComposeMediaKind.document]),
        ),
        isTrue,
      );
    });

    test('anything ungroupable makes the whole send separate messages', () {
      expect(
        ComposeMessages.isAlbum(
          contentsFor([ComposeMediaKind.photo, ComposeMediaKind.voiceNote]),
        ),
        isFalse,
      );
    });

    test('one file is never an album', () {
      expect(
        ComposeMessages.isAlbum(contentsFor([ComposeMediaKind.photo])),
        isFalse,
      );
    });
  });

  group('the content each kind builds', () {
    td.InputMessageContent build(ComposeAttachment attachment) =>
        ComposeMessages.build(text: '', attachments: [attachment]).single;

    test('a document lets Telegram work its own type out', () {
      final content =
          build(of(ComposeMediaKind.document)) as td.InputMessageDocument;
      expect(content.disableContentTypeDetection, isFalse);
    });

    test('a voice note carries its waveform, packed and encoded', () {
      const samples = [0, 31, 16];
      final content =
          build(of(ComposeMediaKind.voiceNote, waveform: samples))
              as td.InputMessageVoiceNote;

      expect(content.waveform, VoiceWaveform.encode(samples));
      expect(content.duration, 5);
    });

    // A round note is square, and `length` is the side Telegram centre-crops
    // to. Taking the *shorter* side is what a centre crop actually leaves —
    // the longer one would declare a size the file does not have.
    test('a round note declares its shorter side as its length', () {
      final content =
          build(of(ComposeMediaKind.videoNote)) as td.InputMessageVideoNote;
      expect(content.length, 60);
    });
  });
}
