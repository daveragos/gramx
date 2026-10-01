import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/features/chats/domain/chat_message.dart';
import 'package:gramx/features/feed/domain/media_item.dart';

/// The tap-to-view cover over self-destructing media. Shows no thumbnail or
/// preview of the content. Outgoing covers are not tappable.
class SecretMediaCover extends StatelessWidget {
  final ChatMessage message;

  /// The bubble's usable width.
  final double maxWidth;

  /// The bubble's foreground colour, used for the glyph and label.
  final Color foregroundColor;
  final Color mutedColor;

  /// Opens the media. Null when outgoing or already being opened.
  final VoidCallback? onOpen;

  const SecretMediaCover({
    super.key,
    required this.message,
    required this.maxWidth,
    required this.foregroundColor,
    required this.mutedColor,
    this.onOpen,
  });

  bool get _isVideo =>
      message.media.isNotEmpty && message.media.first.type != MediaType.photo;

  @override
  Widget build(BuildContext context) {
    final label = _isVideo
        ? AppStrings.secretMediaVideo
        : AppStrings.secretMediaPhoto;

    final subtitle = message.isOutgoing
        ? AppStrings.secretMediaOutgoing
        : AppStrings.secretMediaTapToView;

    return Semantics(
      button: !message.isOutgoing,
      label: '$label — $subtitle',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
        child: Container(
          width: maxWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: mutedColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
          ),
          child: Row(
            children: [
              Icon(
                message.isViewOnce
                    ? Icons.local_fire_department_outlined
                    : Icons.timer_outlined,
                color: foregroundColor,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.body(
                        color: foregroundColor,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.timestamp(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen viewer for self-destructing media, with no share or save.
/// Timed media closes when its countdown ends; view-once media stays until
/// dismissed.
class SecretMediaViewer extends ConsumerStatefulWidget {
  final MediaItem item;

  /// Countdown length in seconds. Zero for view-once media.
  final int seconds;

  const SecretMediaViewer({
    super.key,
    required this.item,
    required this.seconds,
  });

  /// Shows the viewer and completes when it closes.
  static Future<void> show(
    BuildContext context, {
    required MediaItem item,
    required int seconds,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SecretMediaViewer(item: item, seconds: seconds),
      ),
    );
  }

  @override
  ConsumerState<SecretMediaViewer> createState() => _SecretMediaViewerState();
}

class _SecretMediaViewerState extends ConsumerState<SecretMediaViewer> {
  Timer? _tick;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    if (_remaining > 0) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _remaining--);
        // The media is gone on Telegram's side once the timer ends.
        if (_remaining <= 0) {
          _tick?.cancel();
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.item.type != MediaType.photo;
    final path = resolveMediaPath(
      ref,
      fileId: isVideo ? widget.item.thumbnailFileId : widget.item.fileId,
      rawPath: isVideo
          ? widget.item.thumbnailUrl
          : (widget.item.localPath ?? widget.item.url),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // No share or save actions for self-destructing media.
        leading: IconButton(
          tooltip: AppStrings.secretMediaClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_remaining > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(
                child: Text(
                  AppStrings.secretMediaCountdown(_remaining),
                  style: AppTypography.body(
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: path == null
            ? const CircularProgressIndicator(color: AppColors.accent)
            : InteractiveViewer(
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
      ),
    );
  }
}
