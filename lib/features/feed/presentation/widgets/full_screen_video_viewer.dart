import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/features/guest/data/guest_media_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_file_server.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// Full-screen video playback. Opens immediately on the poster frame and
/// streams: a Telegram video through [TdlibFileServer] while TDLib downloads
/// it, a guest video straight from Telegram's CDN.
class FullScreenVideoViewer extends ConsumerStatefulWidget {
  /// Local file, if it has already been downloaded.
  final String? videoPath;

  /// TDLib file id, so the viewer can request and track the download itself.
  final int? fileId;

  /// Poster frame shown while the video is still arriving.
  final String? thumbnailPath;

  /// A guest post's `t.me` video URL, streamed from Telegram's CDN.
  final String? remoteUrl;

  /// The post this video belongs to, for the viewer's header and actions.
  final Post? post;

  /// Where playback starts, from a timestamp tapped in a caption or reply.
  final Duration? startAt;

  const FullScreenVideoViewer({
    super.key,
    this.videoPath,
    this.fileId,
    this.thumbnailPath,
    this.remoteUrl,
    this.post,
    this.startAt,
  });

  static Future<void> show(
    BuildContext context, {
    String? videoPath,
    int? fileId,
    String? thumbnailPath,
    String? remoteUrl,
    Post? post,
    Duration? startAt,
  }) {
    // Root navigator, so the shell's bottom bar isn't painted over the video.
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenVideoViewer(
          videoPath: videoPath,
          fileId: fileId,
          thumbnailPath: thumbnailPath,
          remoteUrl: remoteUrl,
          post: post,
          startAt: startAt,
        ),
      ),
    );
  }

  @override
  ConsumerState<FullScreenVideoViewer> createState() =>
      _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends ConsumerState<FullScreenVideoViewer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _startedPlayback = false;
  bool _showControls = true;
  bool _hasError = false;
  String? _errorMessage;

  /// Whether the player reads the video as it arrives. The poster then shows
  /// no percentage, since playback doesn't wait for the whole file.
  bool _streaming = false;

  /// Whether this viewer started the TDLib download. It stops it on close, so
  /// a video left after ten seconds doesn't keep downloading; TDLib keeps the
  /// parts for next time.
  bool _ownsDownload = false;

  /// Read up front: dispose, which stops an owned download, may not use ref.
  late final TdlibService _tdlib;

  /// A timestamp to seek to once the player is ready.
  Duration? _pendingSeek;

  @override
  void initState() {
    super.initState();
    _tdlib = ref.read(tdlibServiceProvider);
    _pendingSeek = widget.startAt;

    final path = widget.videoPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      _initializePlayer(path);
      return;
    }

    final fileId = widget.fileId;
    if (fileId != null && fileId != 0) {
      _startStreaming(fileId);
      return;
    }

    final url = widget.remoteUrl;
    if (url != null && GuestMediaCache.isAllowed(url)) {
      _startRemote(url);
      return;
    }
    _hasError = true;
    _errorMessage = AppStrings.videoUnavailable;
  }

  /// Plays a guest video from its CDN URL, buffering as it goes.
  Future<void> _startRemote(String url) async {
    _startedPlayback = true;
    _streaming = true;

    try {
      await _play(VideoPlayerController.networkUrl(Uri.parse(url)));
    } catch (e) {
      debugPrint('[VideoViewer] guest video failed: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = AppStrings.videoUnavailable;
      });
    }
  }

  /// Plays from the loopback server while TDLib downloads, falling back to a
  /// full download if the player can't read the video that way.
  Future<void> _startStreaming(int fileId) async {
    if (_startedPlayback) return;
    _startedPlayback = true;

    final local = (await _getFile(fileId))?.local;
    if (!mounted) return;
    if (local != null &&
        local.isDownloadingCompleted &&
        local.path.isNotEmpty) {
      _startedPlayback = false;
      await _initializePlayer(local.path);
      return;
    }
    // A download already running was started by someone else, who still
    // wants it after this viewer closes.
    _ownsDownload = !(local?.isDownloadingActive ?? false);
    setState(() => _streaming = true);

    try {
      final url = await ref.read(tdlibFileServerProvider).urlFor(fileId);
      if (!mounted) return;
      await _play(VideoPlayerController.networkUrl(url));
    } catch (e) {
      debugPrint('[VideoViewer] streaming failed, downloading instead: $e');
      if (!mounted) return;
      setState(() => _streaming = false);
      _startedPlayback = false;
      ref
          .read(syncServiceProvider)
          .downloadFileWithPriority(fileId, priority: 32);
    }
  }

  Future<td.File?> _getFile(int fileId) async {
    try {
      final result = await _tdlib.sendRequest(td.GetFile(fileId: fileId));
      return result is td.File ? result : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initializePlayer(String path) async {
    if (_isInitialized || _startedPlayback) return;
    _startedPlayback = true;

    final file = File(path);
    try {
      if (!file.existsSync()) throw FileSystemException('missing', path);
      await _play(VideoPlayerController.file(file));
    } catch (e) {
      debugPrint('[VideoViewer] $path failed: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = AppStrings.videoUnavailable;
      });
    }
  }

  /// Initializes [controller] and starts it. Throws if it can't play. A viewer
  /// closed meanwhile leaves the controller to [dispose].
  Future<void> _play(VideoPlayerController controller) async {
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      if (identical(_controller, controller)) _controller = null;
      await controller.dispose();
      rethrow;
    }
    if (!mounted) return;
    final start = _pendingSeek;
    _pendingSeek = null;
    if (start != null) await controller.seekTo(start);
    controller.addListener(_onPlayerStateChanged);
    await controller.play();
    if (mounted) setState(() => _isInitialized = true);
  }

  /// Plays from [seconds], for a timestamp tapped in the caption. Before the
  /// player is ready, it starts there instead.
  void _seekTo(int seconds) {
    final position = Duration(seconds: seconds);
    final controller = _controller;
    if (!_isInitialized || controller == null) {
      _pendingSeek = position;
      return;
    }
    controller.seekTo(position);
    controller.play();
    setState(() => _showControls = true);
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlayerStateChanged);
      controller.dispose();
    }
    final fileId = widget.fileId;
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

  /// Download progress, or null while TDLib hasn't reported a size yet.
  static double? _progressOf(FileDownloadProgressState? state) {
    if (state == null || state.totalSize <= 0) return null;
    return state.progress;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString();
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Starts playback once a fallback download lands. The path also feeds the
    // "open with" button, so it is read even during playback. Status only:
    // the progress provider would start a second download from byte zero
    // under the stream.
    final fileId = widget.fileId;
    String? downloadedPath = widget.videoPath;
    FileDownloadProgressState? download;
    if (fileId != null && fileId != 0) {
      download = ref.watch(fileDownloadStatusProvider(fileId)).value;
      final ready = download?.localPath;
      if (download != null && download.isCompleted && ready != null) {
        downloadedPath = ready;
        if (!_isInitialized && !_hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _initializePlayer(ready);
          });
        }
      }
    }

    final controller = _controller;
    return MediaViewerChrome(
      post: widget.post,
      showChrome: _showControls,
      localPath: downloadedPath,
      onMediaTimestampTap: _seekTo,
      controls: _isInitialized && controller != null
          ? _buildScrubber(controller)
          : null,
      child: DragToDismiss(
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: Center(
            child: _hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorMessage ?? AppStrings.videoUnavailable,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : _isInitialized && controller != null
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(controller),
                  )
                : _LoadingPoster(
                    thumbnailPath: widget.thumbnailPath,
                    progress: _streaming ? null : _progressOf(download),
                  ),
          ),
        ),
      ),
    );
  }

  /// Scrubber, play/pause, elapsed time and mute.
  Widget _buildScrubber(VideoPlayerController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: AppColors.accent,
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white12,
          ),
        ),
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
              tooltip: controller.value.isPlaying
                  ? AppStrings.videoPause
                  : AppStrings.videoPlay,
              onPressed: () => setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              }),
            ),
            const SizedBox(width: 12),
            Text(
              '${_formatDuration(controller.value.position)}'
              ' / ${_formatDuration(controller.value.duration)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                controller.value.volume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: controller.value.volume == 0
                  ? AppStrings.videoUnmute
                  : AppStrings.videoMute,
              onPressed: () => setState(() {
                controller.setVolume(controller.value.volume == 0 ? 1.0 : 0.0);
              }),
            ),
          ],
        ),
      ],
    );
  }
}

/// The poster frame and progress shown while a video is still downloading.
class _LoadingPoster extends StatelessWidget {
  final String? thumbnailPath;
  final double? progress;

  const _LoadingPoster({required this.thumbnailPath, required this.progress});

  @override
  Widget build(BuildContext context) {
    final thumb = thumbnailPath;
    final hasThumb =
        thumb != null && thumb.isNotEmpty && File(thumb).existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasThumb)
          Center(child: Image.file(File(thumb), fit: BoxFit.contain)),
        Container(color: Colors.black.withValues(alpha: hasThumb ? 0.45 : 0)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  color: AppColors.accent,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                progress == null
                    ? AppStrings.videoPreparing
                    : AppStrings.videoDownloading((progress! * 100).round()),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
