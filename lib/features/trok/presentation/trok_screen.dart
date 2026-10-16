import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/drawer_avatar_button.dart';
import 'package:gramx/app/widgets/sliding_chrome.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/trok_conversation_view.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_header_actions.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_style.dart';

/// The Trok tab: a chat with Trok above the tab bar.
class TrokScreen extends ConsumerWidget {
  static const route = '/trok';

  const TrokScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trok answers through the reader's Telegram account.
    if (!ref.watch(readerCapabilitiesProvider).canMessage) {
      return const _GuestPlaceholder();
    }

    final answering = ref.watch(
      trokControllerProvider.select((s) => s.isAnswering),
    );
    // The bar stays under the keyboard, so the composer sits on the keyboard.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return ChromeScaffold(
      // A chat keeps its header and bar while it scrolls.
      observeScroll: false,
      header: ChromeHeaderRow(
        titleWidget: TrokWordmark(
          motion: answering ? TrokMarkMotion.thinking : TrokMarkMotion.still,
        ),
        centerTitle: true,
        leading: const DrawerAvatarButton(),
        actions: const [TrokHeaderActions()],
      ),
      body: (context, topPadding, bottomPadding) => TrokConversationView(
        topPadding: topPadding,
        bottomInset: keyboardUp ? 0 : bottomPadding,
      ),
    );
  }
}

/// What the tab shows a guest, who has no account for Trok to answer through.
class _GuestPlaceholder extends StatelessWidget {
  const _GuestPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = TrokStyle.secondary(theme);

    return ChromeScaffold(
      header: const ChromeHeaderRow(
        titleWidget: TrokWordmark(),
        centerTitle: true,
      ),
      body: (context, topPadding, bottomPadding) => Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TrokMark(size: 64, motion: TrokMarkMotion.idle),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.trokGuestTitle,
                  style: AppTypography.subheading(
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.trokGuestBody,
                  style: AppTypography.body(color: secondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  onPressed: () => context.push('/auth'),
                  child: Text(
                    AppStrings.trokGuestAction,
                    style: AppTypography.button(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
