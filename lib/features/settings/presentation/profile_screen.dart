import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/navigation_utils.dart';
import 'package:gramx/core/text/plain_text_links.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/bookmarks/presentation/bookmark_providers.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/chats/presentation/user_profile_screen.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/infrastructure/database/database.dart';

/// The signed-in user's own profile: banner, avatar, name, handle, bio,
/// channel and folder counts, and tabs for bookmarks and channels.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(activeAccountProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.onSurface;

    return accountAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.profileTitle)),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.profileTitle)),
        body: Center(
          child: Text(
            AppStrings.profileError(err),
            style: AppTypography.body(color: AppColors.error),
          ),
        ),
      ),
      data: (account) => account == null
          ? const _GuestProfile()
          : _AccountProfile(account: account, primary: primary),
    );
  }
}

/// The two tabs under the header.
enum _ProfileTab {
  bookmarks,
  channels;

  String get label => switch (this) {
    _ProfileTab.bookmarks => AppStrings.profileTabBookmarks,
    _ProfileTab.channels => AppStrings.profileTabChannels,
  };
}

class _AccountProfile extends ConsumerWidget {
  final Account account;
  final Color primary;

  const _AccountProfile({required this.account, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final displayName = account.displayName ?? AppStrings.drawerAccountFallback;

    // The accounts table has no bio, so it comes from the same cached user
    // lookup the person screen uses.
    final selfId = ref.watch(selfUserIdProvider);
    final bio = selfId == null
        ? null
        : ref.watch(userProfileProvider(selfId)).value?.bio;

    final channelCount = ref.watch(channelsProvider).value?.length ?? 0;
    final folderCount = ref.watch(foldersProvider).value?.length ?? 0;

    return DefaultTabController(
      length: _ProfileTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          // The collapsed bar shows the name rather than "Profile".
          title: Text(displayName, overflow: TextOverflow.ellipsis),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                displayName: displayName,
                username: account.username,
                avatarPath: account.avatarPath,
                bio: bio,
                phone: account.phoneNumber,
                channelCount: channelCount,
                folderCount: folderCount,
                primary: primary,
                secondary: secondary,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabBar(
                background: theme.scaffoldBackgroundColor,
                controller: DefaultTabController.of(context),
              ),
            ),
          ],
          body: const TabBarView(children: [_BookmarksTab(), _ChannelsTab()]),
        ),
      ),
    );
  }
}

/// Banner, avatar over its edge, name, handle, bio, details, counts.
class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String? username;
  final String? avatarPath;
  final String? bio;
  final String? phone;
  final int channelCount;
  final int folderCount;
  final Color primary;
  final Color secondary;

  static const double _bannerHeight = 110;
  static const double _avatarRadius = 38;

  const _ProfileHeader({
    required this.displayName,
    required this.username,
    required this.avatarPath,
    required this.bio,
    required this.phone,
    required this.channelCount,
    required this.folderCount,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Telegram accounts have no cover photo, so the banner is an
            // accent wash, like a channel without a photo.
            Container(
              height: _bannerHeight,
              width: double.infinity,
              color: Color.alphaBlend(
                AppColors.accent.withValues(alpha: isDark ? 0.32 : 0.22),
                isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
              ),
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
                  title: displayName,
                  avatarPath: avatarPath,
                  radius: _avatarRadius,
                ),
              ),
            ),
          ],
        ),
        // The row the avatar overhangs, left empty.
        const SizedBox(height: _avatarRadius + AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.postPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: AppTypography.heading(
                  color: primary,
                ).copyWith(fontSize: 21, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
              if (username != null) ...[
                const SizedBox(height: 1),
                Text(
                  '@$username',
                  style: AppTypography.username(color: secondary),
                ),
              ],
              if (bio case final bio? when bio.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                TextEntityRenderer(
                  text: bio,
                  entities: linkifyPlainText(bio),
                  style: AppTypography.body(color: primary),
                ),
              ],
              if (phone case final phone? when phone.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _PhoneLine(phone: phone, secondary: secondary),
              ],
              const SizedBox(height: AppSpacing.md),
              // Counts row: each figure opens what it counts.
              Row(
                children: [
                  _Count(
                    count: channelCount,
                    label: AppStrings.drawerChannelsCount,
                    primary: primary,
                    secondary: secondary,
                    // The Channels tab below, as X's counts open their
                    // lists. Pushing the shell's Channels route over this
                    // screen put that tab's navigator in the tree twice.
                    onTap: () => DefaultTabController.of(
                      context,
                    ).animateTo(_ProfileTab.channels.index),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _Count(
                    count: folderCount,
                    label: AppStrings.drawerFoldersCount,
                    primary: primary,
                    secondary: secondary,
                    onTap: () => context.push('/folders'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ],
    );
  }
}

/// The phone number as a small grey detail line. Tapping copies it.
class _PhoneLine extends StatelessWidget {
  final String phone;
  final Color secondary;

  const _PhoneLine({required this.phone, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.profilePhone,
      child: InkWell(
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          await Clipboard.setData(ClipboardData(text: phone));
          HapticFeedback.lightImpact();
          messenger.showSnackBar(
            const SnackBar(content: Text(AppStrings.profileCopied)),
          );
        },
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_outlined, size: 16, color: secondary),
              const SizedBox(width: AppSpacing.xs),
              Text(phone, style: AppTypography.body(color: secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final int count;
  final String label;
  final Color primary;
  final Color secondary;
  final VoidCallback onTap;

  const _Count({
    required this.count,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              TimeUtils.formatCount(count),
              style: AppTypography.body(
                color: primary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTypography.body(color: secondary)),
          ],
        ),
      ),
    );
  }
}

/// The tab strip, pinned under the app bar once the header scrolls away.
class _ProfileTabBar extends SliverPersistentHeaderDelegate {
  final Color background;
  final TabController controller;

  static const double _height = 46;

  _ProfileTabBar({required this.background, required this.controller});

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: _height,
      color: background,
      child: Column(
        children: [
          Expanded(
            child: TabBar(
              controller: controller,
              tabs: [
                for (final tab in _ProfileTab.values) Tab(text: tab.label),
              ],
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_ProfileTabBar oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.controller != controller;
}

/// The same list the Bookmarks screen shows, as a tab.
class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final bookmarks = ref.watch(bookmarkedPostsProvider);

    return bookmarks.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (err, _) =>
          _TabNotice(text: AppStrings.bookmarksError(err), color: secondary),
      data: (posts) {
        if (posts.isEmpty) {
          return _TabNotice(
            text: AppStrings.bookmarksEmptyBody,
            color: secondary,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(
              post: post,
              onTap: () {
                ref.read(markPostAsReadProvider(post.id));
                context.push('/post/${post.id}');
              },
              onChannelTap: () =>
                  NavigationUtils.openChannel(context, post.channelId),
              onBookmarkTap: () =>
                  ref.read(bookmarkControllerProvider.notifier).toggle(post),
            );
          },
        );
      },
    );
  }
}

/// The channels this account reads, one row each.
class _ChannelsTab extends ConsumerWidget {
  const _ChannelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final channels = ref.watch(channelsProvider);

    return channels.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (err, _) =>
          _TabNotice(text: AppStrings.channelsError(err), color: secondary),
      data: (list) {
        if (list.isEmpty) {
          return _TabNotice(
            text: AppStrings.channelsEmptyBody,
            color: secondary,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) => _ChannelRow(
            channel: list[index],
            primary: primary,
            secondary: secondary,
          ),
        );
      },
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final Channel channel;
  final Color primary;
  final Color secondary;

  const _ChannelRow({
    required this.channel,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final handle = channel.username != null ? '@${channel.username}' : null;
    final subscribers = channel.subscriberCount > 0
        ? AppStrings.subscriberCountShort(
            TimeUtils.formatCount(channel.subscriberCount),
          )
        : null;
    final line = [
      handle,
      subscribers,
    ].nonNulls.join(AppStrings.inlineSeparator);

    return InkWell(
      onTap: () => NavigationUtils.openChannel(context, channel.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.postPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            ChannelAvatar(
              title: channel.title,
              avatarPath: channel.avatarUrl,
              avatarFileId: channel.avatarFileId,
              avatarColorHex: channel.avatarColor,
              radius: AppSpacing.avatarSizeLarge / 2,
            ),
            const SizedBox(width: AppSpacing.avatarGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.title,
                          style: AppTypography.displayName(color: primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: AppColors.verified,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  if (line.isNotEmpty)
                    Text(
                      line,
                      style: AppTypography.username(color: secondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabNotice extends StatelessWidget {
  final String text;
  final Color color;

  const _TabNotice({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body(color: color),
        ),
      ),
    );
  }
}

/// A guest has no account to show: the mark, a word, and the way in.
class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.accent,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.profileGuestName,
                style: AppTypography.heading(color: primary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.profileStatusOffline,
                style: AppTypography.body(color: secondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              PillButton(
                label: AppStrings.profileLogIn,
                onPressed: () => context.push('/auth'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
