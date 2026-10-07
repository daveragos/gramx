import 'dart:io';
import 'dart:math' as math;

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
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/infrastructure/telegram/chat_identity.dart';
import 'package:gramx/core/time/time_utils.dart';

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
      authorChatId: post.replyToChatId,
      date: post.replyToDate,
      text: post.replyToText,
      thumbnailPath: post.replyToThumbnailUrl,
      thumbnailFileId: post.replyToThumbnailFileId,
      mediaWidth: post.replyToMediaWidth,
      mediaHeight: post.replyToMediaHeight,
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
class QuotedPassage extends ConsumerWidget {
  /// The passage's author, or null when Telegram doesn't say (such as a
  /// private channel). The byline and avatar are then omitted.
  final String? authorTitle;

  /// The passage's chat, when it is another one. Its name, picture, handle
  /// and badge come from TDLib's copy of that chat, as for [QuotedPostCard].
  final int? authorChatId;
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
    this.authorChatId,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final connector = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final other = authorChatId == null
        ? null
        : ref.watch(chatIdentityProvider(authorChatId!));
    final title = other?.title ?? authorTitle;
    final username = authorUsername ?? other?.username;
    final isVerified = isAuthorVerified || (other?.isVerified ?? false);

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
                        avatarPath: other?.avatarPath ?? avatarPath,
                        avatarFileId: other?.avatarFileId ?? avatarFileId,
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
                          _byline(
                            title,
                            username,
                            isVerified,
                            primary,
                            secondary,
                          ),
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

  Widget _byline(
    String title,
    String? username,
    bool isVerified,
    Color primary,
    Color secondary,
  ) {
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
        if (isVerified) ...[
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.verified, color: AppColors.verified, size: 16),
        ],
        if (username != null && username.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              '@$username',
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

  /// The quoted post's chat, when it is another one. Its picture, handle and
  /// badge come from TDLib's copy of that chat.
  final int? authorChatId;

  /// When the quoted post was sent, if known.
  final DateTime? date;

  /// The selected quote if any, otherwise the target's text or caption.
  final String? text;

  final String? thumbnailPath;
  final int? thumbnailFileId;

  /// The picture's size in pixels, so it's drawn at its own shape.
  final int? mediaWidth;
  final int? mediaHeight;

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
    this.authorChatId,
    this.date,
    this.text,
    this.thumbnailPath,
    this.thumbnailFileId,
    this.mediaWidth,
    this.mediaHeight,
    this.onTap,
    this.onAuthorTap,
  });

  /// The picture's box, for tests.
  static const Key mediaKey = ValueKey('quoted-post-media');

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

    // Another chat's picture, handle and badge come from TDLib's copy of it.
    final other = authorChatId == null
        ? null
        : ref.watch(chatIdentityProvider(authorChatId!));
    final author = (
      title: other?.title ?? authorTitle,
      avatarPath: other?.avatarPath ?? avatarPath,
      avatarFileId: other?.avatarFileId ?? avatarFileId,
      username: authorUsername ?? other?.username,
      isVerified: isAuthorVerified || (other?.isVerified ?? false),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Semantics(
        button: true,
        label: AppStrings.quotedPostBy(author.title),
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
                      _byline(author, primary, secondary),
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
                        aspectRatio: _mediaAspectRatio,
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

  /// The picture's shape, within limits, or null when unknown.
  double? get _mediaAspectRatio {
    final width = mediaWidth, height = mediaHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return (width / height).clamp(0.75, 2.0);
  }

  /// Avatar, name, badge, handle and time on one line, as on X.
  Widget _byline(ChatIdentity author, Color primary, Color secondary) {
    final username = author.username;
    return Row(
      children: [
        ChannelAvatar(
          title: author.title ?? authorTitle,
          avatarPath: author.avatarPath,
          avatarFileId: author.avatarFileId,
          avatarColorHex: avatarColorHex,
          radius: 12,
          onTap: onAuthorTap,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            author.title ?? authorTitle,
            style: AppTypography.displayName(color: primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (author.isVerified) ...[
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.verified, color: AppColors.verified, size: 14),
        ],
        if (username != null && username.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              '@$username',
              style: AppTypography.username(color: secondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (date != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '· ${TimeUtils.relativeTime(date!)}',
            style: AppTypography.timestamp(color: secondary),
            maxLines: 1,
          ),
        ],
      ],
    );
  }
}

/// The quoted post's picture at the bottom of the card, at its own shape
/// when that's known, as X draws it.
class _QuotedMedia extends ConsumerWidget {
  final String? path;
  final int? fileId;
  final double? aspectRatio;
  final bool isDark;

  const _QuotedMedia({
    required this.path,
    required this.fileId,
    required this.aspectRatio,
    required this.isDark,
  });

  /// The height when the shape isn't known.
  static const double _height = 140;

  /// The tallest a picture gets, so a portrait can't take over the card.
  static const double _maxHeight = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // With auto-download off, only a picture already on the device shows.
    final waits =
        fileId != null &&
        fileId != 0 &&
        !ref.watch(settingsProvider.select((s) => s.autoDownloadImagesEnabled));
    final resolved = waits
        ? ref.watch(fileDownloadStatusProvider(fileId!)).value?.localPath
        : resolveMediaPath(ref, fileId: fileId, rawPath: path);
    final placeholder = ColoredBox(
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );

    final Widget image = resolved == null || resolved.isEmpty
        ? placeholder
        : Image.file(
            // Keyed by path so a late download replaces the placeholder.
            key: ValueKey(resolved),
            File(resolved),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => placeholder,
          );

    final ratio = aspectRatio;
    if (ratio == null) {
      return SizedBox(
        key: QuotedPostCard.mediaKey,
        height: _height,
        width: double.infinity,
        child: image,
      );
    }
    // The card's full width at the picture's shape, cropped once too tall.
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: QuotedPostCard.mediaKey,
        width: constraints.maxWidth,
        height: math.min(constraints.maxWidth / ratio, _maxHeight),
        child: image,
      ),
    );
  }
}
