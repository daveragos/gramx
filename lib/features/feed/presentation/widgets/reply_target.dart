import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/media_path.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/domain/reply_presentation.dart';

/// Where in a post's column a reply shape goes. The "Replying to" line sits
/// above the body; the quote card sits below it.
enum ReplySlot {
  /// Between the byline and the post's own words.
  aboveBody,

  /// Under the post's text and media.
  belowBody,
}

/// What a post replies to, drawn as the shape [replyPresentationFor] picks:
/// a bordered quote card or a single "Replying to" line.
class ReplyTarget extends StatelessWidget {
  final Post post;

  /// Opens the message being answered.
  final VoidCallback onOpenPost;

  /// Opens the author of the message being answered.
  final VoidCallback onOpenAuthor;

  /// Forces the one-line form, used for comments.
  final bool compact;

  /// The position this instance fills. A host draws [ReplyTarget] once in
  /// each slot, and each shape appears only in its own.
  final ReplySlot slot;

  const ReplyTarget({
    super.key,
    required this.post,
    required this.onOpenPost,
    required this.onOpenAuthor,
    this.compact = false,
    this.slot = ReplySlot.aboveBody,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final presentation = replyPresentationFor(post);
    if (presentation == ReplyPresentation.none) return const SizedBox.shrink();

    // The host draws a passage with [QuotedPassage].
    if (presentation == ReplyPresentation.passage && !compact) {
      return const SizedBox.shrink();
    }

    // Null when Telegram doesn't name the author; the card and line then
    // fall back to this channel.
    final authorTitle = post.replyToAuthorTitle;

    if (compact || presentation == ReplyPresentation.line) {
      if (slot != ReplySlot.aboveBody) return const SizedBox.shrink();
      return _ReplyingToLine(
        authorTitle: authorTitle ?? post.channelTitle,
        excerpt: compact ? post.replyToText : null,
        color: secondary,
        onTap: onOpenPost,
      );
    }

    if (slot != ReplySlot.belowBody) return const SizedBox.shrink();

    // Across chats, this channel's avatar and badge don't apply.
    final isSameChat = post.replyToChatId == null;

    return QuotedPostCard(
      authorTitle: authorTitle ?? post.channelTitle,
      authorUsername: isSameChat ? post.channelUsername : null,
      isAuthorVerified: isSameChat && post.isChannelVerified,
      avatarPath: isSameChat ? post.channelAvatarUrl : null,
      avatarFileId: isSameChat ? post.channelAvatarFileId : null,
      avatarColorHex: isSameChat ? post.channelAvatarColor : null,
      text: post.replyToText,
      thumbnailPath: post.replyToThumbnailUrl,
      thumbnailFileId: post.replyToThumbnailFileId,
      onTap: onOpenPost,
      onAuthorTap: onOpenAuthor,
    );
  }
}

/// One "Replying to" line, as X writes it: gray words and the name in the
/// accent. For a reply whose parent is already on screen or whose content
/// Telegram didn't send; tapping opens the parent.
class _ReplyingToLine extends StatelessWidget {
  final String authorTitle;

  /// The words answered, under the line. Only in comments, where the parent
  /// may be further up the thread and these words say which one it was.
  final String? excerpt;

  final Color color;
  final VoidCallback onTap;

  const _ReplyingToLine({
    required this.authorTitle,
    required this.excerpt,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xs,
      ),
      child: Semantics(
        button: true,
        label: AppStrings.chatReplyingToName(authorTitle),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  text: AppStrings.replyingToPrefix,
                  children: [
                    TextSpan(
                      text: authorTitle,
                      style: const TextStyle(color: AppColors.accent),
                    ),
                  ],
                ),
                style: AppTypography.timestamp(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (excerpt != null && excerpt!.trim().isNotEmpty)
                Text(
                  excerpt!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.timestamp(color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The passage a reply quoted, shown above the reply on a thread connector.
/// Only the quoted words are drawn, with no media and no action bar.
///
/// Drawn by the host rather than [ReplyTarget] because it spans the avatar
/// gutter, so the connector can run down to the reply's avatar.
class QuotedPassage extends StatelessWidget {
  /// The passage's author, or null when Telegram doesn't say (such as a
  /// private channel). The byline and avatar are then omitted.
  final String? authorTitle;
  final String? authorUsername;
  final bool isAuthorVerified;
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;

  final String passage;

  /// Matched to the host's avatar so the connector runs straight.
  final double avatarRadius;
  final double gutterGap;

  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  /// Minimum connector length, so a short passage still shows a visible line.
  static const double minConnectorRun = 26;

  const QuotedPassage({
    super.key,
    required this.passage,
    this.authorTitle,
    this.authorUsername,
    this.isAuthorVerified = false,
    this.avatarPath,
    this.avatarFileId,
    this.avatarColorHex,
    this.avatarRadius = AppSpacing.avatarSize / 2,
    this.gutterGap = AppSpacing.md,
    this.onTap,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final connector = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final title = authorTitle;

    return Semantics(
      button: true,
      label: title == null
          ? AppStrings.quotedPassageUnattributed
          : AppStrings.quotedPassageBy(title),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Stretched so the connector fills the passage's height.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: avatarRadius * 2 + AppSpacing.xs + minConnectorRun,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    if (title != null)
                      ChannelAvatar(
                        title: title,
                        avatarPath: avatarPath,
                        avatarFileId: avatarFileId,
                        avatarColorHex: avatarColorHex,
                        radius: avatarRadius,
                        onTap: onAuthorTap,
                      )
                    else
                      // Keeps the connector aligned with the reply's avatar.
                      SizedBox(
                        width: avatarRadius * 2,
                        height: avatarRadius * 2,
                      ),
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: AppSpacing.xs),
                        color: connector,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: gutterGap),
                Expanded(
                  child: Padding(
                    // Space for the connector before the reply's avatar.
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null) ...[
                          _byline(title, primary, secondary),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(
                          passage,
                          style: AppTypography.body(color: secondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _byline(String title, Color primary, Color secondary) {
    return Row(
      children: [
        Flexible(
          child: GestureDetector(
            onTap: onAuthorTap,
            child: Text(
              title,
              style: AppTypography.displayName(color: primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (isAuthorVerified) ...[
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.verified, color: AppColors.verified, size: 16),
        ],
        if (authorUsername != null && authorUsername!.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              '@$authorUsername',
              style: AppTypography.username(color: secondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// The post being answered, embedded as a bordered card with its avatar,
/// byline, text and picture. No fill; the media runs to the card's edge.
class QuotedPostCard extends ConsumerWidget {
  final String authorTitle;
  final String? authorUsername;
  final bool isAuthorVerified;
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;

  /// The selected quote if any, otherwise the target's text or caption.
  final String? text;

  final String? thumbnailPath;
  final int? thumbnailFileId;

  /// Opens the quoted post. Every caller should pass one.
  final VoidCallback? onTap;

  /// Opens the author, when that differs from [onTap].
  final VoidCallback? onAuthorTap;

  const QuotedPostCard({
    super.key,
    required this.authorTitle,
    this.authorUsername,
    this.isAuthorVerified = false,
    this.avatarPath,
    this.avatarFileId,
    this.avatarColorHex,
    this.text,
    this.thumbnailPath,
    this.thumbnailFileId,
    this.onTap,
    this.onAuthorTap,
  });

  bool get _hasThumbnail =>
      (thumbnailFileId != null && thumbnailFileId != 0) ||
      (thumbnailPath != null && thumbnailPath!.isNotEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final body = text?.trim();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Semantics(
        button: true,
        label: AppStrings.quotedPostBy(authorTitle),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            // Clips the picture to the card's radius.
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.mediaRadius),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _byline(primary, secondary),
                      if (body != null && body.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          body,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(color: primary),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
                // Inset with its own corners, as on X.
                if (_hasThumbnail)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      child: _QuotedMedia(
                        path: thumbnailPath,
                        fileId: thumbnailFileId,
                        isDark: isDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Avatar, name, badge and handle on one line.
  Widget _byline(Color primary, Color secondary) {
    return Row(
      children: [
        ChannelAvatar(
          title: authorTitle,
          avatarPath: avatarPath,
          avatarFileId: avatarFileId,
          avatarColorHex: avatarColorHex,
          radius: 12,
          onTap: onAuthorTap,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            authorTitle,
            style: AppTypography.displayName(color: primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isAuthorVerified) ...[
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.verified, color: AppColors.verified, size: 14),
        ],
        if (authorUsername != null && authorUsername!.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              '@$authorUsername',
              style: AppTypography.username(color: secondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// The quoted post's picture at the bottom of the card. Kept short because
/// Telegram only sends a small thumbnail for a reply target.
class _QuotedMedia extends ConsumerWidget {
  final String? path;
  final int? fileId;
  final bool isDark;

  const _QuotedMedia({
    required this.path,
    required this.fileId,
    required this.isDark,
  });

  static const double _height = 140;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = resolveMediaPath(ref, fileId: fileId, rawPath: path);
    final placeholder = Container(
      height: _height,
      width: double.infinity,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );

    if (resolved == null || resolved.isEmpty) return placeholder;

    return Image.file(
      // Keyed by path so a late download replaces the placeholder.
      key: ValueKey(resolved),
      File(resolved),
      height: _height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}
