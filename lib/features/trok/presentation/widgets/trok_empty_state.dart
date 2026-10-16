import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_style.dart';

/// A way into a first question. A [prompt] ending in a space is left in the
/// composer for the reader to finish; the rest are asked at once.
class TrokStarter {
  final IconData icon;
  final String title;
  final String prompt;

  const TrokStarter(this.icon, this.title, this.prompt);

  bool get needsTopic => prompt.endsWith(' ');

  static const all = [
    TrokStarter(
      Icons.bolt_rounded,
      AppStrings.trokStarterCatchUp,
      AppStrings.trokStarterCatchUpPrompt,
    ),
    TrokStarter(
      Icons.local_fire_department_outlined,
      AppStrings.trokStarterToday,
      AppStrings.trokStarterTodayPrompt,
    ),
    TrokStarter(
      Icons.travel_explore_rounded,
      AppStrings.trokStarterChannels,
      AppStrings.trokStarterChannelsPrompt,
    ),
    TrokStarter(
      Icons.school_outlined,
      AppStrings.trokStarterExplain,
      AppStrings.trokStarterExplainPrompt,
    ),
  ];
}

/// A new chat: the eye, a greeting, and starters.
class TrokEmptyState extends StatelessWidget {
  final ValueChanged<TrokStarter> onStarter;

  const TrokEmptyState({super.key, required this.onStarter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = TrokStyle.secondary(theme);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: TrokStyle.gutter),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              const TrokMark(size: 76, motion: TrokMarkMotion.idle),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.trokGreeting,
                style: AppTypography.heading(
                  color: theme.colorScheme.onSurface,
                ).copyWith(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.trokIntro,
                style: AppTypography.body(
                  color: secondary,
                ).copyWith(fontWeight: FontWeight.w400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _StarterGrid(onStarter: onStarter),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.trokDisclosure,
                style: AppTypography.actionCount(color: secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarterGrid extends StatelessWidget {
  final ValueChanged<TrokStarter> onStarter;

  const _StarterGrid({required this.onStarter});

  @override
  Widget build(BuildContext context) {
    const starters = TrokStarter.all;
    return Column(
      children: [
        for (var row = 0; row < starters.length; row += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StarterCard(
                      starter: starters[row],
                      onTap: () => onStarter(starters[row]),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: row + 1 < starters.length
                        ? _StarterCard(
                            starter: starters[row + 1],
                            onTap: () => onStarter(starters[row + 1]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StarterCard extends StatelessWidget {
  final TrokStarter starter;
  final VoidCallback onTap;

  const _StarterCard({required this.starter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = TrokStyle.secondary(theme);

    return Material(
      color: TrokStyle.fill(theme),
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(starter.icon, size: 20, color: theme.colorScheme.onSurface),
              const SizedBox(height: AppSpacing.sm),
              Text(
                starter.title,
                style: AppTypography.body(
                  color: theme.colorScheme.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                starter.prompt.trim(),
                style: AppTypography.actionCount(
                  color: secondary,
                ).copyWith(height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
