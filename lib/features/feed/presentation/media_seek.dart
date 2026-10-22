import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/full_screen_video_viewer.dart';

/// A request to play a track from a point, made by tapping a timestamp such
/// as "1:23" in a caption or reply.
class MediaSeekRequest {
  final int fileId;
  final Duration position;

  const MediaSeekRequest(this.fileId, this.position);
}

/// Carries timestamp taps to the audio players under it: a post card, a
/// post with its comments, a conversation. A tap plays the track beside the
/// text, not every copy of that file, such as a repost of it or the feed
/// under an open post.
class MediaSeekScope extends StatefulWidget {
  final Widget child;

  const MediaSeekScope({super.key, required this.child});

  /// The requests made in the nearest scope, or null outside any.
  static ValueListenable<MediaSeekRequest?>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SeekScope>()?.requests;

  @override
  State<MediaSeekScope> createState() => _MediaSeekScopeState();
}

class _MediaSeekScopeState extends State<MediaSeekScope> {
  // Each request is a new object, so the same timestamp tapped twice seeks
  // twice.
  final _requests = ValueNotifier<MediaSeekRequest?>(null);

  @override
  void dispose() {
    _requests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SeekScope(requests: _requests, child: widget.child);
}

class _SeekScope extends InheritedWidget {
  final ValueNotifier<MediaSeekRequest?> requests;

  const _SeekScope({required this.requests, required super.child});

  @override
  bool updateShouldNotify(_SeekScope oldWidget) =>
      !identical(oldWidget.requests, requests);
}

/// The first video, music track or voice message in [media], which is what
/// a timestamp in its caption points at.
MediaItem? timestampTarget(List<MediaItem> media) {
  for (final item in media) {
    final hasFile = item.fileId != null && item.fileId != 0;
    switch (item.type) {
      case MediaType.video:
        if (hasFile || (item.url?.isNotEmpty ?? false)) return item;
      case MediaType.audio || MediaType.voice:
        if (hasFile) return item;
      default:
        break;
    }
  }
  return null;
}

/// What a timestamp tap does for text about [media]: play it from that
/// second. Null when there is nothing to play, so timestamps stay plain text.
///
/// A video opens in the viewer at that point. A track asks its player to
/// seek and play, through the [MediaSeekScope] above [context], so
/// [context] must be inside the scope that holds the player.
ValueChanged<int>? playFromTimestamp(
  BuildContext context,
  List<MediaItem> media, {
  Post? post,
}) {
  final target = timestampTarget(media);
  if (target == null) return null;
  return (seconds) {
    final position = Duration(seconds: seconds);
    if (target.type == MediaType.video) {
      FullScreenVideoViewer.show(
        context,
        videoPath: target.localPath,
        fileId: target.fileId,
        thumbnailPath: target.thumbnailUrl,
        remoteUrl: target.url,
        post: post,
        startAt: position,
      );
      return;
    }
    final requests = context
        .getInheritedWidgetOfExactType<_SeekScope>()
        ?.requests;
    requests?.value = MediaSeekRequest(target.fileId!, position);
  };
}
