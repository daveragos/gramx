import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/feed/presentation/widgets/poll_card.dart';

class PostDetailScreen extends ConsumerWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  Widget _buildAvatar(Post post) {
    if (post.channelAvatarUrl != null && post.channelAvatarUrl!.isNotEmpty) {
      final file = File(post.channelAvatarUrl!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: AppSpacing.avatarSizeLarge / 2,
          backgroundImage: FileImage(file),
        );
      }
    }
    return CircleAvatar(
      radius: AppSpacing.avatarSizeLarge / 2,
      backgroundColor: post.channelAvatarColor != null
          ? _parseColor(post.channelAvatarColor!)
          : AppColors.accent,
      child: Text(
        post.channelTitle.isNotEmpty ? post.channelTitle[0].toUpperCase() : '?',
        style: AppTypography.heading(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(postId));
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primaryColor = theme.colorScheme.onSurface;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markPostAsReadProvider(postId));
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Post', style: AppTypography.heading(color: primaryColor)),
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (post) {
          if (post == null) return Center(child: Text('Post not found', style: AppTypography.body(color: secondaryColor)));

          final totalReactions = post.reactions.values.fold<int>(0, (a, b) => a + b);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.postPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Channel header
                      Row(
                        children: [
                          _buildAvatar(post),
                          const SizedBox(width: AppSpacing.avatarGap),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(post.channelTitle, style: AppTypography.displayName(color: primaryColor)),
                                    if (post.isChannelVerified) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, color: AppColors.verified, size: 18),
                                    ],
                                  ],
                                ),
                                if (post.channelUsername != null)
                                  Text('@${post.channelUsername}', style: AppTypography.username(color: secondaryColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Post text
                      if (post.text != null && post.text!.isNotEmpty) ...[
                        TextEntityRenderer(
                          text: post.text!,
                          entities: post.entities,
                          style: AppTypography.bodyLarge(color: primaryColor),
                        ),
                      ],
                      // Poll display
                      if (post.poll != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        PollCard(
                          poll: post.poll!,
                          channelId: post.channelId,
                          messageId: post.messageId,
                        ),
                      ],
                      // Media
                      if (post.media.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        PostMediaGrid(media: post.media),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      // Full timestamp
                      Text(
                        TimeUtils.fullDateTime(post.publishedAt),
                        style: AppTypography.timestamp(color: secondaryColor),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.postPadding, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      if (post.forwardCount > 0) ...[
                        Text(TimeUtils.formatCount(post.forwardCount), style: AppTypography.displayName(color: primaryColor)),
                        const SizedBox(width: 4),
                        Text('Reposts', style: AppTypography.body(color: secondaryColor)),
                        const SizedBox(width: AppSpacing.lg),
                      ],
                      if (totalReactions > 0) ...[
                        Text(TimeUtils.formatCount(totalReactions), style: AppTypography.displayName(color: primaryColor)),
                        const SizedBox(width: 4),
                        Text('Likes', style: AppTypography.body(color: secondaryColor)),
                        const SizedBox(width: AppSpacing.lg),
                      ],
                      if (post.viewCount > 0) ...[
                        Text(TimeUtils.formatCount(post.viewCount), style: AppTypography.displayName(color: primaryColor)),
                        const SizedBox(width: 4),
                        Text('Views', style: AppTypography.body(color: secondaryColor)),
                      ],
                    ],
                  ),
                ),
                const Divider(),
                // Action bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl, vertical: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.chat_bubble_outline, color: secondaryColor, size: 22),
                      Icon(Icons.repeat, color: secondaryColor, size: 22),
                      Icon(
                        totalReactions > 0 ? Icons.favorite : Icons.favorite_border,
                        color: totalReactions > 0 ? AppColors.like : secondaryColor,
                        size: 22,
                      ),
                      Icon(
                        post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: post.isBookmarked ? AppColors.accent : secondaryColor,
                        size: 22,
                      ),
                      Icon(Icons.ios_share, color: secondaryColor, size: 22),
                    ],
                  ),
                ),
                const Divider(),
                // Comments placeholder
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.postPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Comments', style: AppTypography.subheading(color: primaryColor)),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: Text(
                          'Comments will be available after Telegram login',
                          style: AppTypography.body(color: secondaryColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}
