import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/custom_emoji_provider.dart';

/// One custom (premium) emoji drawn inline in text. Shows the plain character
/// until the artwork loads, and for formats that can't be decoded.
class CustomEmojiGlyph extends ConsumerWidget {
  final int customEmojiId;
  final String fallbackText;
  final double size;

  /// Shown instead of [fallbackText] while the artwork is missing, for an
  /// emoji that stands in for a mark (such as an emoji status).
  final Widget? fallback;

  const CustomEmojiGlyph({
    super.key,
    required this.customEmojiId,
    required this.fallbackText,
    required this.size,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emoji = ref.watch(customEmojiProvider)[customEmojiId];

    // Requests are batched and cached, so this is cheap from build.
    if (emoji == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(customEmojiProvider.notifier).request([customEmojiId]);
      });
      return _fallback();
    }

    if (!emoji.isReady) return _fallback();

    return SizedBox(
      width: size,
      height: size,
      child: switch (emoji.format) {
        StickerFormat.tgs => _LottieGlyph(path: emoji.path!, size: size),
        StickerFormat.webp => Image.file(
          File(emoji.path!),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallback(),
        ),
        // Android's decoder drops WebM's alpha plane, so show the character.
        _ => _fallback(),
      },
    );
  }

  Widget _fallback() =>
      fallback ?? Text(fallbackText, style: TextStyle(fontSize: size * 0.9));
}

class _LottieGlyph extends StatefulWidget {
  final String path;
  final double size;

  const _LottieGlyph({required this.path, required this.size});

  @override
  State<_LottieGlyph> createState() => _LottieGlyphState();
}

class _LottieGlyphState extends State<_LottieGlyph> {
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decode();
  }

  @override
  void didUpdateWidget(_LottieGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _bytes = _decode();
  }

  Future<Uint8List> _decode() async {
    final raw = await File(widget.path).readAsBytes();
    final inflated = gzip.decode(raw);
    return inflated is Uint8List ? inflated : Uint8List.fromList(inflated);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return SizedBox.square(dimension: widget.size);
        return Lottie.memory(
          data,
          fit: BoxFit.contain,
          repeat: true,
          errorBuilder: (_, _, _) => SizedBox.square(dimension: widget.size),
        );
      },
    );
  }
}
