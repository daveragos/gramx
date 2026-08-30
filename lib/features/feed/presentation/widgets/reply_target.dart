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

///
/// Two Telegram conventions had made their way into gramX and stayed: the
/// tinted block with an accent bar down its left edge for a reply, and the
/// and neither is a tinted block — a bordered card holding the quoted post
/// when there is one to hold, and one grey line naming the author when there
/// is not. [replyPresentationFor] picks between them; this draws the pick, so
/// the feed, the post screen and a comment all answer the question the same
/// way.
class ReplyTarget extends StatelessWidget {
  final Post post;

  /// Opens the message being answered.
  final VoidCallback onOpenPost;

  /// Opens whoever wrote it.
  final VoidCallback onOpenAuthor;

  /// Forces the one-line form.
  ///
  /// A comment already sits inside a thread, under a connector, inside the
  /// post screen. A card there is a box inside a box inside a box, so the
  /// line is the only shape that fits however much of the quoted post
  /// Telegram happened to send.
  final bool compact;

  const ReplyTarget({
    super.key,
    required this.post,
    required this.onOpenPost,
    required this.onOpenAuthor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final presentation = replyPresentationFor(post);
    if (presentation == ReplyPresentation.none) return const SizedBox.shrink();

    final authorTitle = post.replyToAuthorTitle ?? post.channelTitle;

    if (compact || presentation == ReplyPresentation.line) {
      return _ReplyingToLine(
        authorTitle: authorTitle,
        // Absent rather than invented: TDLib sends no excerpt for a reply
        // inside one channel, and a placeholder sentence in its place is a
        // line nobody wrote.
        excerpt: compact ? post.replyToText : null,
        color: secondary,
        onTap: onOpenPost,
      );
    }

    // A reply inside this channel is answering this channel, so the quoted
    // post's face and tick are the ones already on this card. Across chats
    // they belong to a channel this post never carried, and the avatar falls
    // back to its initial rather than borrowing the wrong picture.
    final isSameChat = post.replyToChatId == null;

    return QuotedPostCard(
      authorTitle: authorTitle,
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

///
/// For a reply whose parent is already on screen above it, or whose content
/// Telegram never sent. Nothing is drawn around it — the reply is the thing
/// being read.
class _ReplyingToLine extends StatelessWidget {
  final String authorTitle;
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
    final trimmed = excerpt?.trim();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs, bottom: AppSpacing.sm),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reply_rounded, size: 13, color: color),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      AppStrings.chatReplyingToName(authorTitle),
                      style: AppTypography.timestamp(
                        color: AppColors.accent,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (trimmed != null && trimmed.isNotEmpty)
                Text(
                  trimmed,
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

///
/// Telegram draws this as a tinted block with an accent bar down its left edge
/// puts a whole post inside it — avatar, byline, words, picture — so the thing
/// you are looking at reads as a post rather than as a decoration on this one.
/// quoted post is a post.
///
/// The border is the only thing separating it from the card around it, so it
/// carries the whole boundary: no fill, no accent bar, and the media runs to
/// the box's own edge rather than sitting inset with a second radius.
class QuotedPostCard extends ConsumerWidget {
  final String authorTitle;
  final String? authorUsername;
  final bool isAuthorVerified;
  final String? avatarPath;
  final int? avatarFileId;
  final String? avatarColorHex;

  /// The quoted words — Telegram's selected quote when the writer picked one,
  /// otherwise the target message's own text or a caption.
  final String? text;

  final String? thumbnailPath;
  final int? thumbnailFileId;

  /// Opens the quoted post. Null makes the card inert, which the hard rules
  /// forbid — every caller passes one.
  final VoidCallback? onTap;

  /// Opens whoever wrote it, when that is somewhere different from [onTap].
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
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
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
            // Antialiased so the picture is cut by the box's own radius
            // instead of needing a second one inset from it.
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
                    AppSpacing.sm,
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
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            color: primary,
                          ).copyWith(fontSize: 14, height: 1.3),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
                if (_hasThumbnail) _QuotedMedia(
                  path: thumbnailPath,
                  fileId: thumbnailFileId,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// the post header at a smaller size rather than a caption above a block.
  Widget _byline(Color primary, Color secondary) {
    return Row(
      children: [
        ChannelAvatar(
          title: authorTitle,
          avatarPath: avatarPath,
          avatarFileId: avatarFileId,
          avatarColorHex: avatarColorHex,
          radius: 10,
          onTap: onAuthorTap,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            authorTitle,
            style: AppTypography.displayName(
              color: primary,
            ).copyWith(fontSize: 14),
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
              style: AppTypography.username(
                color: secondary,
              ).copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// The quoted post's picture, filling the bottom of the card.
///
/// What Telegram sends for a reply target is its smallest thumbnail, so this
/// is capped short rather than given a post's full media height — a 90px file
/// stretched down the width of the screen is mush, and the picture here is
/// there to identify the quoted post, not to be looked at.
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
      // Keyed off the path so a late download replaces the placeholder rather
      // than being composited over a stale frame.
      key: ValueKey(resolved),
      File(resolved),
      height: _height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}
