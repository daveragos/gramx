import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';

/// Copies [post]'s t.me link and says so, or says it has none. Every share
/// button does this.
Future<void> copyPostLink(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  Post post,
) async {
  final link = await ref.read(feedRepositoryProvider).postLink(post);
  if (link != null) await Clipboard.setData(ClipboardData(text: link));
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        link == null ? AppStrings.postNotLinkable : AppStrings.postLinkCopied,
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
