import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/presentation/widgets/post_card.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/guest/presentation/widgets/guest_banner.dart';

/// The guest's feed: every added public channel, newest first.
///
/// Plainly chronological, unlike the signed-in feed. That feed weaves unread
/// backlog into the new posts, and "unread" is a property of a Telegram
/// account — a guest has none, so there is nothing to weave and no cadence to
/// keep. Nothing here is marked read, either: see `ReaderCapabilities`.
///
/// No "N new posts" pill and no live updates. `t.me/s/` is a page, not a
/// stream; the only way to learn something arrived is to ask again, which is
/// what pulling to refresh does.
class GuestFeedScreen extends ConsumerWidget {
  const GuestFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(guestFeedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return ChromeScaffold(
      header: const ChromeHeaderRow(title: AppStrings.appName),
      body: (context, topPadding, bottomPadding) {
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(guestFeedProvider);
            await ref.read(guestFeedProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(padding: EdgeInsets.only(top: topPadding)),
              const SliverToBoxAdapter(child: GuestBanner()),
              ...feedAsync.when(
                loading: () => const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                ],
                error: (err, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Empty(
                      icon: Icons.cloud_off_rounded,
                      title: AppStrings.channelLoadFailed,
                      body: err.toString(),
                      secondary: secondary,
                    ),
                  ),
                ],
                data: (posts) {
                  if (posts.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(
                          icon: Icons.add_circle_outline,
                          title: AppStrings.guestFeedEmptyTitle,
                          body: AppStrings.guestFeedEmptyBody,
                          secondary: secondary,
                          action: (
                            label: AppStrings.guestAddAction,
                            onPressed: () => context.push('/guest/channels'),
                          ),
                        ),
                      ),
                    ];
                  }

                  return [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => PostCard(
                          post: posts[index],
                          // No PostVisibilityReporter: there is no account to
                          // acknowledge a read against.
                          onTap: () => context.push('/post/${posts[index].id}'),
                        ),
                        childCount: posts.length,
                      ),
                    ),
                  ];
                },
              ),
              SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color secondary;
  final ({String label, VoidCallback onPressed})? action;

  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    required this.secondary,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: secondary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTypography.subheading(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: AppTypography.body(color: secondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                ),
                onPressed: action!.onPressed,
                child: Text(action!.label, style: AppTypography.button()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
