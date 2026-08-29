import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:gramx/app/theme/app_spacing.dart';

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2F3336)
        : const Color(0xFFEFF3F4);
    final highlightColor = isDark
        ? const Color(0xFF3E4144)
        : const Color(0xFFF7F9F9);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.postPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: AppSpacing.avatarSize,
              height: AppSpacing.avatarSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.avatarGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + username row
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 80,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Text lines
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Media placeholder
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.mediaRadius,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      5,
                      (_) => Container(
                        width: 40,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
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

class FeedSkeleton extends StatelessWidget {
  final int itemCount;

  /// Space the header is covering, so the first card starts below it rather
  /// than under it.
  final EdgeInsets padding;

  const FeedSkeleton({
    super.key,
    this.itemCount = 5,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) => const PostSkeleton(),
    );
  }
}

/// The folder strip while the folders are still being worked out.
///
/// The feed's header used to be absent entirely during the first load — the
/// bottom bar was already drawn, the wordmark and the tab strip were not, so
/// the app opened looking like it had lost its navigation and then grew it
/// back. The header is real from the first frame now; only the part that is
/// genuinely unknown — which folders this account has — is a skeleton.
class FolderTabsSkeleton extends StatelessWidget {
  /// Placeholder pill widths. Uneven on purpose: four identical blocks read as
  /// a loading bar, and varied ones read as words that have not arrived.
  static const List<double> _widths = [34, 68, 52, 80];

  const FolderTabsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2F3336)
        : const Color(0xFFEFF3F4);
    final highlightColor = isDark
        ? const Color(0xFF3E4144)
        : const Color(0xFFF7F9F9);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final width in _widths)
                Container(
                  width: width,
                  height: 14,
                  margin: const EdgeInsets.only(right: AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
