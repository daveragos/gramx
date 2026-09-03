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

/// The cover over media that disappears once it is opened.
///
/// Telegram's tap-to-view shape, drawn in the bubble's own colours rather than
/// as a black box: a glyph, what kind of thing is under it, and — on an
/// incoming one — an invitation to open it. There is deliberately no preview,
/// no blurred frame and no thumbnail. The point of the feature is that the
/// picture has not been seen yet, and a thumbnail is a small copy of the
/// picture.
///
/// Outgoing covers are not tappable. The sender already saw what they sent, and
/// opening one's own view-once message is a state Telegram does not have.
class SecretMediaCover extends StatelessWidget {
  final ChatMessage message;

  /// The bubble's usable width, so the cover matches the bubbles around it.
  final double maxWidth;

  /// Foreground for the glyph and the label — the bubble's own, because an
  /// outgoing bubble is the accent colour and accent-on-accent is invisible.
  final Color foregroundColor;
  final Color mutedColor;

  /// Opens it. Null on an outgoing message, and on one already being opened.
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

/// The full-screen look at media that is about to be destroyed.
///
/// Its own route rather than the ordinary image viewer, because two of the
/// things it does are the opposite of what that one does: it cannot be shared
/// or saved, and it closes itself. A countdown is drawn for timed media and
/// closes the route when it reaches zero; view-once media has no clock and
/// stays until the viewer dismisses it, which is exactly what Telegram means by
/// "view once".
class SecretMediaViewer extends ConsumerStatefulWidget {
  final MediaItem item;

  /// Seconds on the clock. Zero for view-once media, which has none.
  final int seconds;

  const SecretMediaViewer({
    super.key,
    required this.item,
    required this.seconds,
  });

  /// Shows it. Returns when the viewer is gone, however it went.
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
        // Closes itself rather than sitting at zero. The media is gone on
        // Telegram's side at this point; leaving it on screen would be showing
        // something that no longer exists.
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
        // No share and no save. Both exist on the ordinary viewer, and neither
        // belongs on something the sender chose to make temporary.
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
