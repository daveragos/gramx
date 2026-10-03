import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

/// Shows a bottom sheet of actions above the shell's bottom bar and returns
/// the tapped row's [AppSheetRow.value]. Row callbacks run after the sheet
/// closes, so they should use the caller's context.
///
/// Rows scroll rather than overflow. A sheet stops at 9/16 of the screen
/// unless [tall], which lets a long list of choices use the full height.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required List<Widget> children,
  String? title,
  bool haptic = true,
  bool tall = false,
}) {
  if (haptic) HapticFeedback.mediumImpact();
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: tall,
    useSafeArea: tall,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text(
                title,
                style: AppTypography.subheading(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// One row of an [showAppSheet]. Closes the sheet with [value], then calls
/// [onTap].
class AppSheetRow<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  /// What the sheet's future completes with when this row is tapped.
  final T? value;

  /// Drawn red, for an irreversible action.
  final bool isDestructive;

  /// Shows a trailing check mark.
  final bool isSelected;

  const AppSheetRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.value,
    this.isDestructive = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final color = isDestructive ? AppColors.error : primary;

    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: AppTypography.body(
          color: color,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: AppTypography.actionCount(color: secondary)),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: primary, size: 20)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      onTap: () {
        Navigator.of(context).pop(value);
        onTap?.call();
      },
    );
  }
}

/// A hairline between groups of rows.
class AppSheetDivider extends StatelessWidget {
  const AppSheetDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Divider(),
  );
}
