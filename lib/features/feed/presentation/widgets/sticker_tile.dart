import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// Renders a Telegram sticker by format: WebP through `Image`, TGS (gzipped
/// Lottie JSON) through Lottie, and WebM as its static thumbnail, since
/// Android's hardware decoder drops the VP9 alpha channel.
class StickerTile extends ConsumerWidget {
  final MediaItem item;

  static const double maxExtent = 180;

  const StickerTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so the sticker appears as soon as its file lands.
    final fileId = item.fileId;
    final downloaded = fileId != null && fileId != 0
        ? ref.watch(fileDownloadProvider(fileId)).value
        : null;

    final path = downloaded ?? item.localPath;
    final size = _preferredSize();

    if (path == null || path.isEmpty) {
      return _fallback(context, size);
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: switch (item.stickerFormat) {
        StickerFormat.tgs => _TgsSticker(path: path, fallbackSize: size),
        StickerFormat.webp => Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => _fallback(context, size),
        ),
        // WebM and anything unrecognised: show the still preview.
        _ => _thumbnailOr(context, size),
      },
    );
  }

  Size _preferredSize() {
    final w = item.width > 0 ? item.width.toDouble() : maxExtent;
    final h = item.height > 0 ? item.height.toDouble() : maxExtent;
    final scale = maxExtent / (w > h ? w : h);
    return scale < 1 ? Size(w * scale, h * scale) : Size(w, h);
  }

  Widget _thumbnailOr(BuildContext context, Size size) {
    final thumb = item.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty && File(thumb).existsSync()) {
      return Image.file(
        File(thumb),
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => _fallback(context, size),
      );
    }
    return _fallback(context, size);
  }

  Widget _fallback(BuildContext context, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.emoji_emotions_outlined,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        size: 28,
      ),
    );
  }
}

/// A TGS sticker (gzipped Lottie JSON), decoded once and held across
/// rebuilds.
class _TgsSticker extends StatefulWidget {
  final String path;
  final Size fallbackSize;

  const _TgsSticker({required this.path, required this.fallbackSize});

  @override
  State<_TgsSticker> createState() => _TgsStickerState();
}

class _TgsStickerState extends State<_TgsSticker> {
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decode();
  }

  @override
  void didUpdateWidget(_TgsSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _bytes = _decode();
  }

  /// Reads and gunzips the file. `gzip.decode` returns `List<int>`; Lottie
  /// needs a `Uint8List`.
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
        if (data == null) return SizedBox.fromSize(size: widget.fallbackSize);

        return Lottie.memory(
          data,
          fit: BoxFit.contain,
          repeat: true,
          errorBuilder: (context, _, _) =>
              SizedBox.fromSize(size: widget.fallbackSize),
        );
      },
    );
  }
}
