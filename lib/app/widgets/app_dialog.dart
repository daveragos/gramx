import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/pill_button.dart';

/// One answer a confirmation offers.
///
/// The value is what [showAppDialog] returns when this one is tapped. A
/// [AppDialogAction.cancel] answers null, the same as tapping outside — every
/// caller already treats null as "leave it".
class AppDialogAction<T> {
  final String label;
  final T? value;

  /// Drawn filled, first. The one thing the dialog exists to ask about.
  final bool isPrimary;

  /// Red: the answer that cannot be taken back.
  final bool isDestructive;

  const AppDialogAction({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  /// The way out. Always last, always outlined, always answers null.
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

/// explanation, and the answers stacked as full-width pills — the one being
/// asked about on top, the way out underneath.
///
/// Material's `AlertDialog` puts two text buttons side by side in the bottom
/// corner, in the framework's own font, and every screen in the app had its
/// own copy of that with its own idea of which button was red. This is the one
/// shape, and it is the one place that decides.
///
/// Returns the tapped action's value, or null when the dialog was dismissed
/// by tapping outside or with the back gesture.
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

/// The dialog itself, for callers that need to hold their own state in it —
/// an edit field, a validated input. Prefer [showAppDialog] otherwise.
class AppDialog<T> extends StatelessWidget {
  final String title;
  final String? body;

  /// Anything between the body and the buttons — a text field, a list.
  final Widget? content;
  final List<AppDialogAction<T>> actions;

  /// A first button the caller builds itself, drawn above [actions].
  ///
  /// For the dialog whose answer is not known when it opens — an edit field
  /// pops with whatever was typed — so the caller wires the pop and this
  /// widget keeps the shape.
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
              style: AppTypography.heading(color: primaryColor)
                  .copyWith(fontWeight: FontWeight.w800),
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
