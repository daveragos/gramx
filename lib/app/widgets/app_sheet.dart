import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

///
/// Returns whatever the tapped row's [AppSheetRow.onTap] does not — rows pop
/// the sheet themselves with a value, so a caller that wants an answer passes
/// `value` and reads the future. Rows that act directly close the sheet first
/// and then act with the *caller's* context, because the sheet's own is gone
/// by the time anything asynchronous answers.
///
/// Through the root navigator: the shell's bottom bar is painted over each
/// tab's navigator, so a sheet attached to the tab's would open under it.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required List<Widget> children,
  String? title,
  bool haptic = true,
}) {
  if (haptic) HapticFeedback.mediumImpact();
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
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
          ...children,
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// One row of an [showAppSheet]: an icon, a label, an optional second line.
///
/// The row closes the sheet before calling [onTap], handing back [value] if
/// there is one. That order is the point — see [showAppSheet].
class AppSheetRow<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  /// What the sheet's future completes with when this row is tapped.
  final T? value;

  /// Red: the row that cannot be undone.
  final bool isDestructive;

  /// A tick at the end, for a row that is a choice already made.
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
