import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/trok/data/trok_mention.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';

/// Offers Trok above a comment or group-message box while "@trok" is being
/// typed in [controller], and completes it when tapped.
class TrokMentionSuggestion extends ConsumerWidget {
  final TextEditingController controller;

  const TrokMentionSuggestion({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trok said this reader may not use it.
    if (ref.watch(trokControllerProvider.select((s) => s.blocked != null))) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        if (TrokMention.typing(value) == null) return const SizedBox.shrink();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.onSurface;
        final secondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
        // Part of the field, so a tap keeps the keyboard up for the rest of
        // the question.
        return TextFieldTapRegion(
          child: InkWell(
            onTap: () => controller.value = TrokMention.complete(value),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const TrokMark(size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.trokName,
                          style: AppTypography.username(
                            color: primary,
                          ).copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppStrings.trokMentionHint,
                          style: AppTypography.timestamp(color: secondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
