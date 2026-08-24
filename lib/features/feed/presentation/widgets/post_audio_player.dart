import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

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

  Future<void> _togglePlay(String path) async {
    if (_controller == null) {
      setState(() => _isInitializing = true);
      try {
        _controller = VideoPlayerController.file(File(path));
        await _controller!.initialize();
        _controller!.addListener(_onControllerUpdate);
        await _controller!.play();
      } catch (e) {
        debugPrint('[AudioPlayer] Error: $e');
      } finally {
        if (mounted) setState(() => _isInitializing = false);
      }
    } else {
      if (_isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final fileId = widget.item.fileId;
    FileDownloadProgressState? downloadState;

    if (fileId != null && fileId != 0) {
      downloadState = ref.watch(fileDownloadStatusProvider(fileId)).value;
    }
    final resolvedPath = downloadState?.localPath ?? widget.item.localPath;

    final isDownloaded = resolvedPath != null && resolvedPath.isNotEmpty && File(resolvedPath).existsSync();
    final isDownloading = downloadState != null && !downloadState.isCompleted && (downloadState.progress > 0 || downloadState.downloadedSize > 0);
    final progress = downloadState?.progress ?? 0.0;
    final isVoice = widget.item.type == MediaType.voice;
    final title = isVoice ? 'Voice message' : (widget.item.fileName ?? 'Audio track');
    final durationSecs = widget.item.duration;
    final totalDurationText = _formatDuration(durationSecs);
    final currentPosText = _formatDuration(_position.inSeconds);

    final progressRatio = (_controller != null && _controller!.value.duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _controller!.value.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (isDownloaded) {
                    _togglePlay(resolvedPath);
                  } else if (fileId != null && fileId != 0) {
                    ref.read(syncServiceProvider).downloadFileWithPriority(fileId, priority: 32);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(AppStrings.audioDownloading),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: _isInitializing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : isDownloading
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(
                                value: progress > 0 ? progress : null,
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              !isDownloaded
                                  ? Icons.download_rounded
                                  : (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              color: Colors.white,
                              size: 26,
                            ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body(color: primaryColor).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: isDownloading ? progress : progressRatio,
                        minHeight: 4,
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPlaying ? currentPosText : totalDurationText,
                          style: AppTypography.actionCount(color: secondaryColor),
                        ),
                        Text(
                          isDownloading
                              ? '${(progress * 100).toInt()}%'
                              : (isVoice ? 'Voice' : 'Audio'),
                          style: AppTypography.actionCount(color: secondaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
