import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/activity/data/activity_repository.dart';
import 'package:gramx/features/activity/domain/activity_item.dart';
import 'package:gramx/features/chats/presentation/chats_providers.dart';

/// The number on the bell, summed from the chat cache rather than the Activity
/// list so the badge never costs a request.
final activityBadgeProvider = Provider<int>((ref) {
  return ActivityPlan.badgeCount(ref.watch(chatListProvider));
});

/// The Activity list, newest first. Costs requests, so it refreshes only on
/// invalidation. Loading marks the listed chats as seen, which clears the
/// bell without rebuilding this list.
final activityFeedProvider = FutureProvider<List<ActivityItem>>((ref) async {
  // Read, not watched: unread counts change constantly, and marking seen
  // below changes them too.
  final chats = ref.read(chatListProvider);
  final repository = ref.read(activityRepositoryProvider);
  final items = await repository.load(chats);
  unawaited(repository.markSeen(chats));
  return items;
});
