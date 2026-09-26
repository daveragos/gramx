import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/features/feed/domain/media_item.dart';

void main() {
  group('StickerFormat.fromTdName', () {
    // Mapping every sticker to MediaType.photo is what left TGS and WebM
    // stickers drawing nothing: neither is an image.
    test('recognises the three Telegram formats', () {
      expect(StickerFormat.fromTdName('stickerFormatWebp'), StickerFormat.webp);
      expect(StickerFormat.fromTdName('stickerFormatTgs'), StickerFormat.tgs);
      expect(StickerFormat.fromTdName('stickerFormatWebm'), StickerFormat.webm);
    });

    test('falls back to unknown for anything else', () {
      expect(
        StickerFormat.fromTdName('stickerFormatFuture'),
        StickerFormat.unknown,
      );
      expect(StickerFormat.fromTdName(null), StickerFormat.unknown);
      expect(StickerFormat.fromTdName(''), StickerFormat.unknown);
    });
  });

  group('isAnimatable', () {
    test('true for the formats this app can decode', () {
      expect(StickerFormat.webp.isAnimatable, isTrue);
      expect(StickerFormat.tgs.isAnimatable, isTrue);
    });

    // WebM stickers are VP9 with an alpha channel, which Android's hardware
    // decoder drops — so they fall back to the still thumbnail.
    test('false for formats that fall back to a thumbnail', () {
      expect(StickerFormat.webm.isAnimatable, isFalse);
      expect(StickerFormat.unknown.isAnimatable, isFalse);
    });
  });

  group('MediaItem', () {
    test('defaults to an unknown sticker format', () {
      const item = MediaItem(id: 'a', type: MediaType.photo);
      expect(item.stickerFormat, StickerFormat.unknown);
    });

    test('carries the format through a copyWith', () {
      const item = MediaItem(id: 'a', type: MediaType.sticker);
      final updated = item.copyWith(stickerFormat: StickerFormat.tgs);
      expect(updated.stickerFormat, StickerFormat.tgs);
    });

    test('survives a JSON round-trip', () {
      const item = MediaItem(
        id: 'a',
        type: MediaType.sticker,
        stickerFormat: StickerFormat.webm,
      );
      final restored = MediaItem.fromJson(item.toJson());
      expect(restored.stickerFormat, StickerFormat.webm);
      expect(restored.type, MediaType.sticker);
    });
  });
}
