import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/telegram_app.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/live/data/live_stream_session.dart';
import 'package:gramx/features/live/presentation/live_row.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:video_player/video_player.dart';

/// A chat's live stream, full screen. Joins as a muted viewer on open and
/// leaves on close, or when the app goes to the background.
class LiveScreen extends ConsumerStatefulWidget {
  static const route = '/live/:chatId';
  static String routeFor(int chatId) => '/live/$chatId';

  final int chatId;

  const LiveScreen({super.key, required this.chatId});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen>
    with WidgetsBindingObserver {
  LiveStreamSession? _session;
  VideoPlayerController? _player;
  bool _muted = false;

  /// True when the chat has no live to join.
  bool _noLive = false;

  /// Left because the app went to the background; rejoined on return.
  bool _leftForBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _session != null) {
      _leftForBackground = true;
      setState(_stop);
    } else if (state == AppLifecycleState.resumed && _leftForBackground) {
      _leftForBackground = false;
      setState(_start);
    }
  }

  void _start() {
    final chat = ref.read(chatCacheProvider).chat(widget.chatId);
    final groupCallId = chat?.videoChat.groupCallId ?? 0;
    if (groupCallId == 0) {
      _noLive = true;
      return;
    }
    _noLive = false;
    final session = LiveStreamSession(
      ref.read(tdlibServiceProvider),
      groupCallId: groupCallId,
    );
    _session = session;
    session.addListener(_onSession);
    unawaited(session.start());
  }

  void _stop() {
    final player = _player;
    _player = null;
    player?.removeListener(_onPlayer);
    unawaited(player?.dispose());
    final session = _session;
    _session = null;
    session?.removeListener(_onSession);
    session?.dispose();
  }

  void _retry() => setState(() {
    _stop();
    _start();
  });

  void _onSession() {
    final session = _session;
    if (session == null || !mounted) return;
    final url = session.playlistUrl;
    if (session.status == LiveStreamStatus.playing &&
        url != null &&
        _player == null) {
      unawaited(_play(url));
    } else if (session.status != LiveStreamStatus.playing && _player != null) {
      final player = _player;
      _player = null;
      player?.removeListener(_onPlayer);
      unawaited(player?.dispose());
    }
    setState(() {});
  }

  Future<void> _play(Uri url) async {
    final player = VideoPlayerController.networkUrl(
      url,
      formatHint: VideoFormat.hls,
    );
    _player = player;
    player.addListener(_onPlayer);
    try {
      await player.initialize();
      if (!identical(_player, player)) return;
      await player.setVolume(_muted ? 0 : 1);
      await player.play();
    } catch (e) {
      debugPrint('[Live] player: $e');
    }
    if (mounted) setState(() {});
  }

  /// Restarts the player when it fails, such as after falling behind the
  /// few seconds the playlist keeps.
  void _onPlayer() {
    final player = _player;
    final url = _session?.playlistUrl;
    if (player == null || url == null || !player.value.hasError) return;
    _player = null;
    player.removeListener(_onPlayer);
    unawaited(player.dispose());
    unawaited(_play(url));
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    unawaited(_player?.setVolume(_muted ? 0 : 1));
  }

  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(chatCacheProvider);
    final chat = cache.chat(widget.chatId);
    final channel = chat == null
        ? null
        : TdlibMappers.mapChatToChannel(
            chat,
            supergroup: cache.supergroupForChat(chat),
          );
    final session = _session;
    final status = _noLive
        ? LiveStreamStatus.ended
        : (session?.status ?? LiveStreamStatus.joining);
    final player = _player;
    final showsVideo =
        status == LiveStreamStatus.playing &&
        player != null &&
        player.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showsVideo)
            Center(
              child: AspectRatio(
                aspectRatio: player.value.aspectRatio,
                child: VideoPlayer(player),
              ),
            ),
          if (showsVideo && player.value.isBuffering ||
              status == LiveStreamStatus.joining ||
              status == LiveStreamStatus.buffering ||
              (status == LiveStreamStatus.playing && !showsVideo))
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          if (status == LiveStreamStatus.unsupported)
            _Notice(
              title: AppStrings.liveUnsupportedTitle,
              body: AppStrings.liveUnsupportedBody,
              action: channel?.username == null
                  ? null
                  : (
                      label: AppStrings.liveOpenInTelegram,
                      onTap: () => _openInTelegram(channel!.username!),
                    ),
            ),
          if (status == LiveStreamStatus.ended)
            const _Notice(title: AppStrings.liveEndedTitle),
          if (status == LiveStreamStatus.failed)
            _Notice(
              title: AppStrings.liveFailedTitle,
              action: (label: AppStrings.liveRetry, onTap: _retry),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: _TopBar(
                title: chat?.title ?? '',
                avatarPath: channel?.avatarUrl,
                avatarFileId: channel?.avatarFileId,
                avatarColorHex: channel?.avatarColor,
                viewers: session?.viewerCount,
                isLive:
                    status != LiveStreamStatus.ended &&
                    status != LiveStreamStatus.failed,
                muted: _muted,
                onClose: () => Navigator.of(context).maybePop(),
                onToggleMute: showsVideo ? _toggleMute : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInTelegram(String username) async {
    final opened = await openInTelegramApp(
      Uri.parse('https://t.me/$username?livestream'),
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.liveTelegramMissing)),
      );
    }
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;
  final int? viewers;
  final bool isLive;
  final bool muted;
  final VoidCallback onClose;
  final VoidCallback? onToggleMute;

  const _TopBar({
    required this.title,
    required this.avatarPath,
    required this.avatarFileId,
    required this.avatarColorHex,
    required this.viewers,
    required this.isLive,
    required this.muted,
    required this.onClose,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          _Disc(
            icon: Icons.close_rounded,
            tooltip: AppStrings.liveClose,
            onTap: onClose,
          ),
          const SizedBox(width: 4),
          ChannelAvatar(
            title: title,
            avatarPath: avatarPath,
            avatarFileId: avatarFileId,
            avatarColorHex: avatarColorHex,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (isLive)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        const LiveBadge(),
                        if (viewers != null && viewers! > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.liveViewers(
                              TimeUtils.formatCount(viewers!),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (onToggleMute != null)
            _Disc(
              icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              tooltip: muted ? AppStrings.liveUnmute : AppStrings.liveMute,
              onTap: onToggleMute!,
            ),
        ],
      ),
    );
  }
}

/// A dark disc button that shows against video, as in the media viewer.
class _Disc extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _Disc({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Container(
        padding: const EdgeInsets.all(9),
        decoration: const BoxDecoration(
          color: Color(0xCC0F1419),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String title;
  final String? body;
  final ({String label, VoidCallback onTap})? action;

  const _Notice({required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.35,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: action!.onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  action!.label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
