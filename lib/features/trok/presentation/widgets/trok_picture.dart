import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/widgets/minithumbnail.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_style.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// [post]'s picture for Trok's cards and quotes. A post History rebuilt
/// carries no media, so it is looked up.
TrokSourcePicture? trokPictureOf(WidgetRef ref, Post post) {
  final held = TrokSourcePicture.of(post);
  if (held != null || post.media.isNotEmpty) return held;
  final looked = ref.watch(postDetailProvider(post.id)).value;
  return looked == null ? null : TrokSourcePicture.of(looked);
}

/// A source's picture, over its blurred preview until it arrives. Follows
/// the reader's choice to download pictures automatically.
class TrokPictureView extends ConsumerWidget {
  final TrokSourcePicture picture;

  /// The size of a video's play mark.
  final double markSize;

  const TrokPictureView({super.key, required this.picture, this.markSize = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final automatic = ref.watch(
      settingsProvider.select((s) => s.autoDownloadImagesEnabled),
    );
    // Watching the download provider starts the download.
    final path = automatic
        ? ref.watch(fileDownloadProvider(picture.fileId)).value
        : ref
              .watch(fileDownloadStatusProvider(picture.fileId))
              .value
              ?.localPath;
    final blurred = Minithumbnail.provider(picture.minithumbnail);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: TrokStyle.border(theme).withValues(alpha: 0.3)),
        if (blurred != null) Image(image: blurred, fit: BoxFit.cover),
        if (path != null && path.isNotEmpty)
          Image.file(
            File(path),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: fadeInFrame,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        if (picture.isVideo)
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(markSize / 4),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: markSize,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
