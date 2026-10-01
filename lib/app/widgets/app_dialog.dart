import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/pill_button.dart';

/// One button in an [AppDialog]. [value] is what [showAppDialog] returns when
/// it is tapped; [AppDialogAction.cancel] returns null, like dismissing.
class AppDialogAction<T> {
  final String label;
  final T? value;

  /// Drawn filled.
  final bool isPrimary;

  /// Drawn red, for an irreversible answer.
  final bool isDestructive;

  const AppDialogAction({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  /// An outlined button that returns null.
  const AppDialogAction.cancel(this.label)
    : value = null,
      isPrimary = false,
      isDestructive = false;

  PillStyle get _style => switch ((isPrimary, isDestructive)) {
    (true, true) => PillStyle.danger,
    (true, false) => PillStyle.filled,
    (false, true) => PillStyle.dangerOutlined,
    (false, false) => PillStyle.outlined,
  };
}

/// Shows the app's confirmation dialog with actions stacked as full-width
/// pills. Returns the tapped action's value, or null when dismissed.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? body,
  Widget? content,
  required List<AppDialogAction<T>> actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AppDialog<T>(
      title: title,
      body: body,
      content: content,
      actions: actions,
    ),
  );
}

/// The dialog widget, for callers that hold their own state in it (such as an
/// edit field). Prefer [showAppDialog] otherwise.
class AppDialog<T> extends StatelessWidget {
  final String title;
  final String? body;

  /// Shown between the body and the buttons.
  final Widget? content;
  final List<AppDialogAction<T>> actions;

  /// A caller-built button drawn above [actions], for a dialog whose result
  /// is not known up front (such as typed text).
  final Widget? primary;

  const AppDialog({
    super.key,
    required this.title,
    required this.actions,
    this.body,
    this.content,
    this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.xxl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.heading(
                color: primaryColor,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(body!, style: AppTypography.body(color: secondary)),
            ],
            if (content != null) ...[
              const SizedBox(height: AppSpacing.lg),
              content!,
            ],
            const SizedBox(height: AppSpacing.xxl),
            if (primary != null) ...[
              primary!,
              const SizedBox(height: AppSpacing.md),
            ],
            for (final (index, action) in actions.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.md),
              PillButton(
                label: action.label,
                style: action._style,
                expand: true,
                onPressed: () => Navigator.of(context).pop(action.value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
