import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class NavigationUtils {
  /// Opens a channel route safely, preventing pushing the same channel detail route
  /// on top of itself in an endless loop.
  static void openChannel(BuildContext context, String channelId) {
    if (channelId.isEmpty) return;
    try {
      final currentUri = GoRouterState.of(context).uri.toString();
      final targetPath = '/channel/$channelId';
      if (currentUri == targetPath || currentUri.endsWith(targetPath)) {
        // Already on this channel's screen — do not push duplicate route
        return;
      }
      context.push(targetPath);
    } catch (_) {
      context.push('/channel/$channelId');
    }
  }

  /// Opens a post route safely.
  static void openPost(BuildContext context, String postId) {
    if (postId.isEmpty) return;
    try {
      final currentUri = GoRouterState.of(context).uri.toString();
      final targetPath = '/post/$postId';
      if (currentUri == targetPath || currentUri.endsWith(targetPath)) {
        return;
      }
      context.push(targetPath);
    } catch (_) {
      context.push('/post/$postId');
    }
  }
}
