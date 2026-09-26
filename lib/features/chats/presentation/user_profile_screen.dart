import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/text/plain_text_links.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/chats/data/chats_repository.dart';
import 'package:gramx/features/chats/domain/chat_summary.dart';
import 'package:gramx/features/chats/domain/user_profile.dart';
import 'package:gramx/features/chats/presentation/chats_screen.dart';
import 'package:gramx/features/chats/presentation/widgets/block_user.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/app_sheet.dart';
import 'package:gramx/app/widgets/pill_button.dart';

/// One person, in the shape the channel screen uses for a channel.
///
/// gramX has had somewhere to put a channel since the beginning and nowhere at
/// all to put a person: a mention resolved to a conversation, an avatar in a
/// group went nowhere, and a commenter's name was not a link to anything. This
/// is that missing screen — who somebody is, what they say about themselves,
/// the channel they run, and the one action that follows from all of it.
///
/// Deliberately not the settings profile screen with a different id in it.
/// That one is *your* account and is mostly rows of your own details; this is
/// somebody else's, and the only thing you can do here is write to them.
class UserProfileScreen extends ConsumerWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  static String routeFor(int userId) => '/user/$userId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.onSurface;
    final profileAsync = ref.watch(userProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.profileUserTitle,
          style: AppTypography.heading(color: primary),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (_, _) => _Notice(text: AppStrings.profileUserMissing),
        data: (profile) => profile == null
            ? _Notice(text: AppStrings.profileUserMissing)
            : _Body(profile: profile),
      ),
    );
  }
}

/// One person's profile. Auto-disposed, so leaving the screen drops it and
/// coming back asks Telegram again rather than showing a stale bio.
final userProfileProvider = FutureProvider.autoDispose
    .family<UserProfile?, int>((ref, userId) {
      return ref.watch(chatsRepositoryProvider).userProfile(userId);
    });

class _Body extends ConsumerWidget {
  final UserProfile profile;

  const _Body({required this.profile});

  /// Opens an end-to-end chat with this person, asking first.
  ///
  /// The confirmation is not ceremony: a secret chat is a *different chat* with
  /// the same person, its messages never reach the Telegram cloud, and it dies
  /// with the device. Somebody who lands in one by a mis-tap and writes there
  /// has written somewhere they will not find it again.
  Future<void> _startSecretChat(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context,
      title: AppStrings.secretChatStart,
      body: AppStrings.secretChatStartBody,
      actions: const [
        AppDialogAction(
          label: AppStrings.secretChatStartConfirm,
          value: true,
          isPrimary: true,
        ),
        AppDialogAction.cancel(AppStrings.chatCancel),
      ],
    );
    if (confirmed != true || !context.mounted) return;

    final chatId = await ref
        .read(chatsRepositoryProvider)
        .createSecretChat(profile.userId);
    if (!context.mounted) return;

    if (chatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.secretChatFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.push(ChatsScreen.routeFor(chatId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        // The channel page's shape: a band, the avatar over its edge, and the
        // controls on the row beneath, opposite the avatar.
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: _bannerHeight,
              width: double.infinity,
              color: _bannerTint(profile.avatarColorHex, isDark),
            ),
            Positioned(
              left: AppSpacing.postPadding,
              bottom: -_avatarRadius,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: ChannelAvatar(
                  title: profile.displayName,
                  avatarPath: profile.avatarPath,
                  avatarFileId: profile.avatarFileId,
                  avatarColorHex: profile.avatarColorHex,
                  radius: _avatarRadius,
                ),
              ),
            ),
          ],
        ),

        // the screen is for. Stacked full-width buttons used to take a third
        // of the screen to say the same two things.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.postPadding,
            AppSpacing.sm,
            AppSpacing.postPadding,
            0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!profile.isDeleted) ...[
                RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: AppStrings.profileMoreTooltip,
                  onPressed: () => _showMore(context, ref),
                ),
                const SizedBox(width: AppSpacing.sm),
                PillButton(
                  label: AppStrings.profileMessageAction,
                  icon: Icons.mail_outline_rounded,
                  compact: true,
                  onPressed: () =>
                      context.push(ChatsScreen.routeFor(profile.chatId)),
                ),
              ] else
                // Keeps the avatar's overhang clear even with nothing to
                // press, so the name does not climb into it.
                const SizedBox(height: 32),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.postPadding,
            AppSpacing.sm,
            AppSpacing.postPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      profile.displayName,
                      style: AppTypography.heading(color: primary).copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      color: AppColors.verified,
                      size: 19,
                      semanticLabel: AppStrings.a11yVerified,
                    ),
                  ],
                ],
              ),
              if (profile.username != null)
                Text(
                  '@${profile.username}',
                  style: AppTypography.username(color: secondary),
                ),
              if (_presenceLabel(profile) case final presence?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  presence,
                  style: AppTypography.timestamp(
                    color: profile.presence == ChatPresence.online
                        ? AppColors.accent
                        : secondary,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Badges say things the name cannot: software rather than a person,
        // somebody already in your contacts. Each is a fact, none is a control.
        if (profile.isBot ||
            profile.isPremium ||
            profile.isContact ||
            profile.groupsInCommon > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.postPadding,
              AppSpacing.md,
              AppSpacing.postPadding,
              0,
            ),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (profile.isBot)
                  _Badge(label: AppStrings.profileBotBadge, color: secondary),
                if (profile.isPremium)
                  _Badge(
                    label: AppStrings.profilePremiumBadge,
                    color: secondary,
                  ),
                if (profile.isContact)
                  _Badge(
                    label: AppStrings.profileContactBadge,
                    color: secondary,
                  ),
                if (profile.groupsInCommon > 0)
                  _Badge(
                    label: AppStrings.profileGroupsInCommon(
                      profile.groupsInCommon,
                    ),
                    color: secondary,
                  ),
              ],
            ),
          ),

        if (profile.isDeleted)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.postPadding),
            child: Text(
              AppStrings.profileUserDeleted,
              style: AppTypography.body(color: secondary),
            ),
          ),

        if (profile.bio case final bio?)
          _Section(
            heading: AppStrings.profileBioHeading,
            secondary: secondary,
            // Telegram hands a bio over as bare text with no entities, exactly
            // as it does a channel's description, so the links in it are
            // re-derived the same way rather than left as grey prose.
            child: TextEntityRenderer(
              text: bio,
              entities: linkifyPlainText(bio),
              style: AppTypography.body(color: primary),
            ),
          ),

        if (profile.username case final username?)
          _CopyableRow(
            heading: AppStrings.profileUsernameHeading,
            value: '@$username',
            primary: primary,
            secondary: secondary,
          ),

        if (profile.phoneNumber case final phone?)
          _CopyableRow(
            heading: AppStrings.profilePhoneHeading,
            value: phone,
            primary: primary,
            secondary: secondary,
          ),

        // Who they speak for. The same fact the chat list shows beside their
        // name, in the place there is room to say it properly.
        if (profile.personalChannelId case final channelId?)
          _Section(
            heading: AppStrings.profileChannelHeading,
            secondary: secondary,
            child: InkWell(
              onTap: () => NavigationUtils.openChannel(context, '$channelId'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.campaign_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        profile.personalChannelTitle ??
                            AppStrings.profileChannelUnnamed,
                        style: AppTypography.body(color: primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: secondary,
                      semanticLabel: AppStrings.profileOpenChannel,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static const double _bannerHeight = 110;
  static const double _avatarRadius = 38;

  /// A band in the person's own colour. Telegram gives an account no cover
  /// photo, and their avatar colour is the one thing about them that is
  /// already a colour.
  static Color _bannerTint(String? hex, bool isDark) {
    Color? base;
    if (hex != null && hex.isNotEmpty) {
      final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
      if (value != null) base = Color(0xFF000000 | value);
    }
    return Color.alphaBlend(
      (base ?? AppColors.accent).withValues(alpha: isDark ? 0.32 : 0.22),
      isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
    );
  }

  /// The "…" sheet: the two things you can do here besides write.
  ///
  /// Block's label is read when the sheet opens, not when the screen was
  /// built — a block lands on the chat record, which this screen does not
  /// watch, and a label read earlier went on saying "Block" after the block.
  Future<void> _showMore(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(chatsRepositoryProvider);
    final isBlocked = repository.isBlocked(profile.userId);

    final choice = await showAppSheet<_MoreChoice>(
      context,
      haptic: false,
      children: [
        // Telegram has no end-to-end chat with a bot.
        if (!profile.isBot)
          const AppSheetRow<_MoreChoice>(
            icon: Icons.lock_outline_rounded,
            label: AppStrings.secretChatStart,
            value: _MoreChoice.secretChat,
          ),
        AppSheetRow<_MoreChoice>(
          icon: Icons.block_rounded,
          label: isBlocked ? AppStrings.userUnblock : AppStrings.userBlock,
          value: _MoreChoice.toggleBlock,
          isDestructive: !isBlocked,
        ),
      ],
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case _MoreChoice.secretChat:
        await _startSecretChat(context, ref);
      case _MoreChoice.toggleBlock:
        await toggleBlock(
          context,
          repository,
          userId: profile.userId,
          name: profile.displayName,
        );
    }
  }

  /// Telegram's own hedged answer about when somebody was last around. Null
  /// where it will not say — a group, a bot, or a user it hasn't described.
  static String? _presenceLabel(UserProfile profile) =>
      switch (profile.presence) {
        ChatPresence.online => AppStrings.chatOnline,
        ChatPresence.offline => AppStrings.chatLastSeenOffline,
        ChatPresence.recently => AppStrings.chatLastSeenRecently,
        ChatPresence.lastWeek => AppStrings.chatLastSeenWeek,
        ChatPresence.lastMonth => AppStrings.chatLastSeenMonth,
        ChatPresence.unknown => null,
      };
}

class _Section extends StatelessWidget {
  final String heading;
  final Color secondary;
  final Widget child;

  const _Section({
    required this.heading,
    required this.secondary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.postPadding,
        AppSpacing.lg,
        AppSpacing.postPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading.toUpperCase(),
            style: AppTypography.timestamp(
              color: secondary,
            ).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// A detail worth having in the clipboard. Long-press copies it — the same
/// gesture the settings profile uses for the reader's own details.
class _CopyableRow extends StatelessWidget {
  final String heading;
  final String value;
  final Color primary;
  final Color secondary;

  const _CopyableRow({
    required this.heading,
    required this.value,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return _Section(
      heading: heading,
      secondary: secondary,
      child: InkWell(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: value));
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(AppStrings.profileCopied),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(value, style: AppTypography.body(color: primary)),
        ),
      ),
    );
  }
}

enum _MoreChoice { secretChat, toggleBlock }

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppTypography.timestamp(color: color)),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body(color: secondary),
        ),
      ),
    );
  }
}
