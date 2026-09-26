import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_document_card.dart';

/// The Files tab: one row per document, newest first.
///
/// Reuses [PostDocumentCard] for the row itself — it already downloads on
/// demand, shows progress and hands the finished file to the system opener
/// (the opener added in `6e57816`). This adds only the two things a file
/// pulled out of its post loses: when it was posted, and a way back to it.
class ChannelFileList extends StatelessWidget {
  final List<Post> posts;

  const ChannelFileList({super.key, required this.posts});

  /// Flattens posts to their documents, keeping the post each came from.
  static List<({Post post, MediaItem item})> rowsFor(List<Post> posts) {
    return [
      for (final post in posts)
        for (final item in post.media)
          if (item.type == MediaType.document) (post: post, item: item),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = rowsFor(posts);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _FileRow(row: rows[index]),
        childCount: rows.length,
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final ({Post post, MediaItem item}) row;

  const _FileRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.postPadding,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostDocumentCard(item: row.item),
          const SizedBox(height: AppSpacing.xs),
          // A file lifted out of its post loses its context; this is the way
          // back to it, and it is a real control rather than a caption.
          InkWell(
            onTap: () => context.push('/post/${row.post.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    TimeUtils.relativeTime(row.post.publishedAt),
                    style: AppTypography.timestamp(color: secondary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.channelOpenPost,
                    style: AppTypography.actionCount(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
