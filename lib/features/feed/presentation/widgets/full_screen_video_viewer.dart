import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/features/guest/data/guest_media_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_file_server.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/media_viewer_chrome.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// Full-screen video playback.
///
/// Opens immediately, whether or not the file is on disk yet. A video the user
/// tapped should never be answered with "downloading, please wait" and no
/// screen — the viewer shows the poster frame straight away and fills in a real
/// progress bar while TDLib fetches the file.
class FullScreenVideoViewer extends ConsumerStatefulWidget {
  /// Local file, if it has already been downloaded.
  final String? videoPath;

  /// TDLib file id, so the viewer can request and track the download itself.
  final int? fileId;

  /// Poster frame shown while the video is still arriving.
  final String? thumbnailPath;

  /// A guest post's video lives at a `t.me` URL rather than behind a TDLib file
  /// id. Carried so the viewer can fetch it through the guest cache — passing
  /// only an already-resolved path meant a video the grid had not cached yet
  /// opened onto "unavailable" and stayed there.
  final String? remoteUrl;

  /// Whether Telegram flagged the video as streamable.
  ///
  /// Only a `faststart`-muxed video can play from a prefix; anything else has
  /// its index at the end of the file, so a player given the first megabyte
  /// finds nothing to play. Those fall back to downloading in full.
  final bool supportsStreaming;

  /// The post this video belongs to, so the viewer can carry its identity and
  /// actions rather than stranding the reader on a bare black screen.
  final Post? post;

  const FullScreenVideoViewer({
    super.key,
    this.videoPath,
    this.fileId,
    this.thumbnailPath,
    this.remoteUrl,
    this.post,
    this.supportsStreaming = false,
  });

  static Future<void> show(
    BuildContext context, {
    String? videoPath,
    int? fileId,
    String? thumbnailPath,
    String? remoteUrl,
    Post? post,
    bool supportsStreaming = false,
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
          supportsStreaming: supportsStreaming,
        ),
      ),
    );
  }

  @override
  ConsumerState<FullScreenVideoViewer> createState() =>
      _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends ConsumerState<FullScreenVideoViewer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _startedPlayback = false;
  bool _showControls = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final path = widget.videoPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      _initializePlayer(path);
      return;
    }

    final fileId = widget.fileId;
    if (fileId == null || fileId == 0) {
      // No TDLib file — a guest video. Fetch it through the guest cache and
      // play the file that lands. There is no streaming path here: t.me serves
      // the whole file, and gramX has no prefix to play from.
      final url = widget.remoteUrl;
      if (url != null && url.isNotEmpty) {
        _fetchGuestVideo(url);
        return;
      }
      _hasError = true;
      _errorMessage = AppStrings.videoUnavailable;
      return;
    }

    // Not on disk yet. If Telegram says the video can be streamed, play it
    // through the loopback file server instead of waiting for the download —
    // that is the difference between "starts now" and "starts in a minute".
    if (widget.supportsStreaming) {
      _startStreaming(fileId);
      return;
    }

    // Otherwise ask for the whole thing at viewer priority: this is the file
    // the user is actively waiting on, so it outranks background prefetching.
    ref
        .read(syncServiceProvider)
        .downloadFileWithPriority(fileId, priority: 32);
  }

  /// Downloads a guest video to the media cache, then plays it.
  Future<void> _fetchGuestVideo(String url) async {
    if (_startedPlayback) return;
    _startedPlayback = true;

    try {
      final path = await ref.read(guestMediaCacheProvider).pathFor(url);
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = AppStrings.videoUnavailable;
        });
        return;
      }
      await _initializePlayer(path);
    } catch (e) {
      debugPrint('[VideoViewer] guest video failed: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = AppStrings.videoUnavailable;
      });
    }
  }

  /// Plays from the loopback server, falling back to the download path.
  ///
  /// The fallback matters: streaming depends on a local socket, a Range-aware
  /// player and a prefix arriving in time. If any of that fails the reader
  /// should get their video a little later, not an error.
  Future<void> _startStreaming(int fileId) async {
    if (_isInitialized || _startedPlayback) return;
    _startedPlayback = true;

    try {
      final url = await ref.read(tdlibFileServerProvider).urlFor(fileId);
      _controller = VideoPlayerController.networkUrl(url);
      await _controller.initialize();
      _controller.addListener(_onPlayerStateChanged);
      await _controller.play();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('[VideoViewer] streaming failed, downloading instead: $e');
      _startedPlayback = false;
      if (!mounted) return;
      ref
          .read(syncServiceProvider)
          .downloadFileWithPriority(fileId, priority: 32);
    }
  }

  Future<void> _initializePlayer(String path) async {
    if (_isInitialized || _startedPlayback) return;
    _startedPlayback = true;

    try {
      final file = File(path);
      if (!file.existsSync()) {
        setState(() {
          _hasError = true;
          _errorMessage = AppStrings.videoUnavailable;
        });
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller.initialize();
      _controller.addListener(_onPlayerStateChanged);
      await _controller.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: $e';
        });
      }
    }
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.removeListener(_onPlayerStateChanged);
      _controller.dispose();
    }
    super.dispose();
  }

  /// Download progress, or null while TDLib hasn't reported a size yet.
  double? _downloadProgress() {
    final fileId = widget.fileId;
    if (fileId == null || fileId == 0) return null;
    final state = ref.watch(fileDownloadProgressProvider(fileId)).value;
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
    // Start playback the moment the download lands, without the user tapping
    // again — they already asked for this video once.
    final fileId = widget.fileId;
    // The file on disk, once there is one. Also what the "open with" button
    // hands out, which is why it is read even when playback is already going.
    String? downloadedPath = widget.videoPath;
    if (fileId != null && fileId != 0) {
      final download = ref.watch(fileDownloadProgressProvider(fileId)).value;
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

    return MediaViewerChrome(
      post: widget.post,
      showChrome: _showControls,
      localPath: downloadedPath,
      controls: _isInitialized ? _buildScrubber() : null,
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
                : _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio > 0
                        ? _controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(_controller),
                  )
                : _LoadingPoster(
                    thumbnailPath: widget.thumbnailPath,
                    progress: _downloadProgress(),
                  ),
          ),
        ),
      ),
    );
  }

  /// under the video.
  Widget _buildScrubber() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VideoProgressIndicator(
          _controller,
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
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
              tooltip: _controller.value.isPlaying
                  ? AppStrings.videoPause
                  : AppStrings.videoPlay,
              onPressed: () => setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              }),
            ),
            const SizedBox(width: 12),
            Text(
              '${_formatDuration(_controller.value.position)}'
              ' / ${_formatDuration(_controller.value.duration)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                _controller.value.volume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: _controller.value.volume == 0
                  ? AppStrings.videoUnmute
                  : AppStrings.videoMute,
              onPressed: () => setState(() {
                _controller.setVolume(
                  _controller.value.volume == 0 ? 1.0 : 0.0,
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}

/// The poster frame and progress shown while a video is still downloading.
///
/// A real thumbnail plus a determinate bar tells the reader what they're
/// waiting for and how long is left; a bare spinner tells them neither.
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
