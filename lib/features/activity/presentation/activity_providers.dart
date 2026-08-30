import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/activity/data/activity_repository.dart';
import 'package:gramx/features/activity/domain/activity_item.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';

/// The number on the bell.
///
/// Costs nothing: every term is already in the chat cache, pushed there by the
/// update stream. It is deliberately *not* derived from the Activity list —
/// that list costs requests and is only built when the screen is opened, and a
/// badge nobody can see must never be the reason to spend one.
final activityBadgeProvider = Provider<int>((ref) {
  return ActivityPlan.badgeCount(ref.watch(chatListProvider));
});

/// Everything that has happened, newest first.
///
/// A `FutureProvider` rather than a stream: this is built when the screen is
/// opened and refreshed when the reader pulls, because each build spends
/// requests. Invalidate it to refresh.
final activityFeedProvider = FutureProvider<List<ActivityItem>>((ref) async {
  // Read, not watched. Watching would rebuild — and re-request — every time any
  // chat's unread count moved, which in a busy account is constantly.
  final chats = ref.read(chatListProvider);
  return ref.read(activityRepositoryProvider).load(chats);
});
