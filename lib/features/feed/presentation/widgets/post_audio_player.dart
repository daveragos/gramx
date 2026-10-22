import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:video_player/video_player.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/audio/playable_audio.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/presentation/media_seek.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';
import 'package:gramx/infrastructure/telegram/tdlib_file_server.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// A voice message or music track. Music plays as it downloads, through
/// [TdlibFileServer]. A voice message downloads first and plays when it
/// lands; the bar shows download progress from `UpdateFile` until then.
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

  /// The drag position as a fraction of the track, or null when not dragging.
  /// Separate from [_position] because the controller reports the old
  /// position until the seek lands.
  double? _scrubFraction;

  /// Set by a tap on a track that can't stream, so it plays once its download
  /// lands rather than waiting for a second tap.
  bool _playWhenDownloaded = false;

  /// Where to start once that download lands, from a tapped timestamp.
  Duration? _startAt;

  /// Whether this player started the download behind a stream. It stops it on
  /// dispose; TDLib keeps the parts for next time.
  bool _ownsDownload = false;

  /// Read up front: dispose, which stops an owned download, may not use ref.
  late final TdlibService _tdlib;

  /// Timestamps tapped beside this player; see [MediaSeekScope].
  ValueListenable<MediaSeekRequest?>? _seekRequests;

  @override
  void initState() {
    super.initState();
    _tdlib = ref.read(tdlibServiceProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final requests = MediaSeekScope.of(context);
    if (!identical(requests, _seekRequests)) {
      _seekRequests?.removeListener(_onSeekRequest);
      _seekRequests = requests?..addListener(_onSeekRequest);
    }
  }

  /// Plays this track from a timestamp tapped in its caption or a reply.
  void _onSeekRequest() {
    final request = _seekRequests?.value;
    final fileId = widget.item.fileId;
    if (request == null || fileId == null || request.fileId != fileId) return;
    final path =
        ref.read(fileDownloadStatusProvider(fileId)).value?.localPath ??
        widget.item.localPath;
    final onDisk = path != null && path.isNotEmpty && File(path).existsSync();
    _playFrom(request.position, onDisk ? path : null);
  }

  @override
  void dispose() {
    _seekRequests?.removeListener(_onSeekRequest);
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    final fileId = widget.item.fileId;
    if (_ownsDownload && fileId != null) {
      // Does nothing if the download already finished.
      unawaited(
        _tdlib
            .sendRequest(
              td.CancelDownloadFile(fileId: fileId, onlyIfPending: false),
            )
            .then((_) {}, onError: (_) {}),
      );
    }
    super.dispose();
  }

  /// Whether the track can play before it is downloaded. A voice message is
  /// small and is fetched whole. On iOS, OGG has to be whole too, to become
  /// CAF (see `playableAudioPath`).
  bool get _canStream {
    final item = widget.item;
    if (item.type != MediaType.audio) return false;
    if (item.fileId == null || item.fileId == 0) return false;
    final mime = item.mimeType?.toLowerCase() ?? '';
    return !(Platform.isIOS && (mime.contains('ogg') || mime.contains('opus')));
  }

  void _onControllerUpdate() {
    if (_controller == null || !mounted) return;
    setState(() {
      _isPlaying = _controller!.value.isPlaying;
      _position = _controller!.value.position;
    });
  }

  /// The track's length from the player, or from Telegram's metadata before
  /// the player is ready. Also from the metadata when the player reports
  /// under a second, as it does for a file it can't index, such as a long
  /// M4A of fragments; it can't seek in that one either.
  Duration get _duration {
    final decoded = _controller?.value.duration;
    if (decoded != null && decoded >= const Duration(seconds: 1)) {
      return decoded;
    }
    return Duration(seconds: widget.item.duration);
  }

  /// Builds the player if there isn't one yet: music through
  /// [TdlibFileServer], whether or not it is on disk, and anything else from
  /// [path]. Returns whether there is one.
  Future<bool> _ensureController(String? path) async {
    if (_controller != null) return true;
    if (!_canStream && path == null) return false;

    setState(() => _isInitializing = true);
    VideoPlayerController? controller;
    try {
      controller = _canStream
          ? await _streamController(widget.item.fileId!)
          : await _fileController(path!);
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
      await controller?.dispose();
      return false;
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<VideoPlayerController> _fileController(String path) async =>
      VideoPlayerController.file(File(await playableAudioPath(path)));

  /// A player reading the track through [TdlibFileServer], as it downloads or
  /// once it has. The server gives a track in fragments the index the player
  /// needs to seek, so a finished download goes through it too.
  Future<VideoPlayerController> _streamController(int fileId) async {
    final result = await _tdlib.sendRequest(td.GetFile(fileId: fileId));
    final local = result is td.File ? result.local : null;
    // A finished download, or one already running, isn't this player's to
    // stop: someone else still wants it after this player goes.
    _ownsDownload =
        !(local?.isDownloadingCompleted ?? false) &&
        !(local?.isDownloadingActive ?? false);
    final url = await ref
        .read(tdlibFileServerProvider)
        .urlFor(fileId, mimeType: widget.item.mimeType);
    return VideoPlayerController.networkUrl(url);
  }

  /// Plays or pauses. A track not on disk streams if it can; otherwise, or
  /// if streaming fails, it downloads and plays when the download lands.
  Future<void> _togglePlay(String? path) async {
    if (path == null && !_canStream) {
      _downloadThenPlay();
      return;
    }
    if (!await _ensureController(path)) {
      if (path == null) _downloadThenPlay();
      return;
    }

    if (_isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  /// Plays from [position], for a timestamp tapped in the caption or a reply.
  /// A track that can't stream starts there once its download lands.
  Future<void> _playFrom(Duration position, String? path) async {
    if (path == null && !_canStream) {
      _startAt = position;
      _downloadThenPlay();
      return;
    }
    if (!await _ensureController(path)) {
      if (path == null) {
        _startAt = position;
        _downloadThenPlay();
      }
      return;
    }
    await _controller!.seekTo(position);
    await _controller!.play();
    if (mounted) setState(() => _position = position);
  }

  /// Seeks to a fraction of the track, starting the player if needed.
  Future<void> _seekToFraction(String? path, double fraction) async {
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

  /// Downloads the whole track to keep, playing or not. A download asked for
  /// is not stopped when the player goes.
  void _download() {
    final fileId = widget.item.fileId;
    if (fileId == null || fileId == 0) return;
    setState(() => _ownsDownload = false);
    ref
        .read(syncServiceProvider)
        .downloadFileWithPriority(fileId, priority: 32);
  }

  void _downloadThenPlay() {
    final fileId = widget.item.fileId;
    if (fileId == null || fileId == 0) return;
    setState(() => _playWhenDownloaded = true);
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

    // A stream already plays, so the download under it isn't news.
    final hasPlayer = _controller != null;
    final showsPosition = isDownloaded || hasPlayer;

    if (isDownloaded && _playWhenDownloaded) {
      _playWhenDownloaded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final start = _startAt;
        _startAt = null;
        if (start != null) {
          _playFrom(start, resolvedPath);
        } else if (!_isPlaying) {
          _togglePlay(resolvedPath);
        }
      });
    }

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
            isPlayable: showsPosition,
            canStream: _canStream,
            isPlaying: _isPlaying,
            progress: progress,
            onPressed: () => _togglePlay(isDownloaded ? resolvedPath : null),
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
                if (showsPosition)
                  _Scrubber(
                    fraction: barFraction,
                    trackColor: trackColor,
                    onChanged: (value) =>
                        setState(() => _scrubFraction = value),
                    onChangeEnd: (value) => _seekToFraction(
                      isDownloaded ? resolvedPath : null,
                      value,
                    ),
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
                      showsPosition
                          ? '${TimeUtils.formatDuration(shownPosition.inSeconds)} / '
                                '${TimeUtils.formatDuration(total.inSeconds)}'
                          : TimeUtils.formatDuration(widget.item.duration),
                      style: AppTypography.actionCount(color: secondaryColor),
                    ),
                    Text(
                      isDownloading && !hasPlayer
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
          // Streaming took the play button, so music gets its own way to be
          // saved without playing.
          if (_canStream && !isDownloaded) ...[
            const SizedBox(width: AppSpacing.sm),
            _DownloadButton(
              progress: isDownloading && !_ownsDownload ? progress : null,
              color: secondaryColor,
              onPressed: _download,
            ),
          ],
        ],
      ),
    );
  }
}

/// Downloads a track that can also stream. Shows the download's progress
/// once one is under way, unless it is only feeding a stream.
class _DownloadButton extends StatelessWidget {
  final double? progress;
  final Color color;
  final VoidCallback onPressed;

  const _DownloadButton({
    required this.progress,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return Semantics(
      button: true,
      label: AppStrings.audioDownload,
      excludeSemantics: true,
      child: Tooltip(
        message: AppStrings.audioDownload,
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: SizedBox(
            width: 36,
            height: 36,
            child: progress == null
                ? Icon(Icons.download_rounded, color: color, size: 22)
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 2.5,
                      color: AppColors.accent,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The round button on the left: play/pause, or download for a track that
/// can't stream.
class _TransportButton extends StatelessWidget {
  final bool isInitializing;
  final bool isDownloading;

  /// Whether there is a player, or a file to start one from.
  final bool isPlayable;
  final bool canStream;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPressed;

  const _TransportButton({
    required this.isInitializing,
    required this.isDownloading,
    required this.isPlayable,
    required this.canStream,
    required this.isPlaying,
    required this.progress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = isPlayable
        ? (isPlaying ? AppStrings.audioPause : AppStrings.audioPlay)
        : (canStream ? AppStrings.audioPlay : AppStrings.audioDownload);

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
                // Music can stream at any point, so its button stays Play;
                // the download button beside it shows the progress.
                : isDownloading && !isPlayable && !canStream
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : (isPlayable || canStream
                              ? Icons.play_arrow_rounded
                              : Icons.download_rounded),
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The draggable position bar: a compact `Slider`, for its hit slop,
/// keyboard handling and accessibility actions.
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
