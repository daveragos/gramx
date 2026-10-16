import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_sheets.dart';

/// History and a new chat, at the end of Trok's headers.
class TrokHeaderActions extends ConsumerWidget {
  const TrokHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActive = ref.watch(
      trokControllerProvider.select((s) => s.activeId != null),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: AppStrings.trokHistory,
          icon: const Icon(Icons.history_rounded),
          onPressed: () => TrokHistorySheet.show(context, ref),
        ),
        IconButton(
          tooltip: AppStrings.trokNewChat,
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: hasActive
              ? () {
                  HapticFeedback.lightImpact();
                  ref.read(trokControllerProvider.notifier).startNew();
                }
              : null,
        ),
      ],
    );
  }
}
