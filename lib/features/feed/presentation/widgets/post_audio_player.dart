import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// A voice message or music track, with a bar that can be dragged.
///
/// Two different things share the one bar, and which one it is depends on
/// whether the file has arrived:
///
/// * **while downloading** it is a progress bar and nothing else, filled from
///   the `UpdateFile` stream. That stream used to carry only *completed*
///   files, which is why a download here announced itself in a snackbar and
///   then jumped straight to a play icon with nothing in between — see
///   `TdlibService._emitFileUpdate`;
/// * **once downloaded** it is a scrubber. Dragging it seeks, and it will
///   initialise the player to do so, so the reader does not have to press play
///   first just to move within the track.
class PostAudioPlayer extends ConsumerStatefulWidget {
  final MediaItem item;

  const PostAudioPlayer({super.key, required this.item});

  @override
  ConsumerState<PostAudioPlayer> createState() => _PostAudioPlayerState();
}

class _PostAudioPlayerState extends ConsumerState<PostAudioPlayer> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  /// Where the reader's thumb is, as a fraction of the track, while a drag is
  /// in flight. Null when nobody is dragging.
  ///
  /// Held separately from [_position] because the controller keeps reporting
  /// the *old* position until the seek lands, and letting that win would drag
  /// the handle back out from under the thumb.
  double? _scrubFraction;

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (_controller == null || !mounted) return;
    setState(() {
      _isPlaying = _controller!.value.isPlaying;
      _position = _controller!.value.position;
    });
  }

  /// The track's length: the player's answer once it has one, and Telegram's
  /// own metadata until then — which is what lets the bar be dragged before
  /// anything has been decoded.
  Duration get _duration {
    final decoded = _controller?.value.duration;
    if (decoded != null && decoded > Duration.zero) return decoded;
    return Duration(seconds: widget.item.duration);
  }

  /// Builds the player if there isn't one yet. Returns whether there is one.
  Future<bool> _ensureController(String path) async {
    if (_controller != null) return true;

    setState(() => _isInitializing = true);
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return false;
      }
      controller.addListener(_onControllerUpdate);
      _controller = controller;
      return true;
    } catch (e) {
      debugPrint('[AudioPlayer] Error: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _togglePlay(String path) async {
    if (!await _ensureController(path)) return;

    if (_isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  /// Seeks to a fraction of the track, starting the player if it has not been
  /// built yet — dragging the bar is a way of saying "play from here".
  Future<void> _seekToFraction(String path, double fraction) async {
    final total = _duration;
    if (total <= Duration.zero) {
      setState(() => _scrubFraction = null);
      return;
    }

    if (!await _ensureController(path)) {
      if (mounted) setState(() => _scrubFraction = null);
      return;
    }

    final target = Duration(
      milliseconds: (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    );
    await _controller!.seekTo(target);
    if (!mounted) return;
    setState(() {
      _position = target;
      _scrubFraction = null;
    });
  }

  void _startDownload(int fileId) {
    ref
        .read(syncServiceProvider)
        .downloadFileWithPriority(fileId, priority: 32);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceVariant;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final trackColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    final fileId = widget.item.fileId;
    FileDownloadProgressState? downloadState;

    if (fileId != null && fileId != 0) {
      downloadState = ref.watch(fileDownloadStatusProvider(fileId)).value;
    }
    final resolvedPath = downloadState?.localPath ?? widget.item.localPath;

    final isDownloaded =
        resolvedPath != null &&
        resolvedPath.isNotEmpty &&
        File(resolvedPath).existsSync();
    final progress = downloadState?.progress ?? 0.0;
    final isDownloading =
        downloadState != null &&
        !downloadState.isCompleted &&
        (progress > 0 || downloadState.downloadedSize > 0);

    final isVoice = widget.item.type == MediaType.voice;
    final title = isVoice
        ? AppStrings.mediaVoice
        : (widget.item.fileName ?? AppStrings.mediaAudio);

    final total = _duration;
    final playedFraction = total > Duration.zero
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final barFraction = _scrubFraction ?? playedFraction;
    final shownPosition = _scrubFraction == null
        ? _position
        : Duration(
            milliseconds: (total.inMilliseconds * _scrubFraction!).round(),
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          _TransportButton(
            isInitializing: _isInitializing,
            isDownloading: isDownloading,
            isDownloaded: isDownloaded,
            isPlaying: _isPlaying,
            progress: progress,
            onPressed: () {
              if (isDownloaded) {
                _togglePlay(resolvedPath);
              } else if (fileId != null && fileId != 0) {
                _startDownload(fileId);
              }
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    color: primaryColor,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // A progress bar and a scrubber are different controls, and
                // showing the draggable one over a file that has not arrived
                // would be a handle that moves nothing.
                if (isDownloaded)
                  _Scrubber(
                    fraction: barFraction,
                    trackColor: trackColor,
                    onChanged: (value) =>
                        setState(() => _scrubFraction = value),
                    onChangeEnd: (value) =>
                        _seekToFraction(resolvedPath, value),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isDownloading ? progress : 0,
                      minHeight: 4,
                      backgroundColor: trackColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDownloaded
                          ? '${TimeUtils.formatDuration(shownPosition.inSeconds)} / '
                                '${TimeUtils.formatDuration(total.inSeconds)}'
                          : TimeUtils.formatDuration(widget.item.duration),
                      style: AppTypography.actionCount(color: secondaryColor),
                    ),
                    Text(
                      isDownloading
                          ? AppStrings.downloadPercent((progress * 100).toInt())
                          : (isVoice
                                ? AppStrings.audioKindVoice
                                : AppStrings.audioKindAudio),
                      style: AppTypography.actionCount(color: secondaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The round button on the left: download, then play/pause.
class _TransportButton extends StatelessWidget {
  final bool isInitializing;
  final bool isDownloading;
  final bool isDownloaded;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPressed;

  const _TransportButton({
    required this.isInitializing,
    required this.isDownloading,
    required this.isDownloaded,
    required this.isPlaying,
    required this.progress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = !isDownloaded
        ? AppStrings.audioDownload
        : (isPlaying ? AppStrings.audioPause : AppStrings.audioPlay);

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: isInitializing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : isDownloading
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    !isDownloaded
                        ? Icons.download_rounded
                        : (isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The draggable position bar.
///
/// A `Slider` rather than a bar with a gesture detector on it: it comes with
/// the hit slop, the keyboard handling and the accessibility actions already
/// right, and those are the parts a hand-rolled scrubber gets wrong. Sized
/// down hard, because the default Material slider is furniture next to a
/// four-pixel progress line.
class _Scrubber extends StatelessWidget {
  final double fraction;
  final Color trackColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _Scrubber({
    required this.fraction,
    required this.trackColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: trackColor,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: SizedBox(
        height: 20,
        child: Slider(
          value: fraction.clamp(0.0, 1.0),
          label: AppStrings.audioSeek,
          semanticFormatterCallback: (value) =>
              AppStrings.downloadPercent((value * 100).round()),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}
