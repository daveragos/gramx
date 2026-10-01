import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

/// How a [PillButton] is filled. Outlined suits a state that is already true,
/// such as "Joined".
enum PillStyle { filled, outlined, danger, dangerOutlined, ghost }

/// The app's standard button: a bold rounded pill with a consistent height.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PillStyle style;

  /// A small icon before the label.
  final IconData? icon;

  /// Replaces the label with a spinner and disables the button.
  final bool isBusy;

  /// Stretches to the available width, as in stacked dialog buttons.
  final bool expand;

  /// A smaller pill, for a row of controls beside an avatar.
  final bool compact;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PillStyle.filled,
    this.icon,
    this.isBusy = false,
    this.expand = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final (
      Color background,
      Color foreground,
      BorderSide? side,
    ) = switch (style) {
      PillStyle.filled => (AppColors.accent, Colors.white, null),
      PillStyle.outlined => (
        Colors.transparent,
        primary,
        BorderSide(color: secondary.withValues(alpha: 0.6)),
      ),
      PillStyle.danger => (AppColors.error, Colors.white, null),
      PillStyle.dangerOutlined => (
        Colors.transparent,
        AppColors.error,
        BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
      ),
      PillStyle.ghost => (Colors.transparent, primary, null),
    };

    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 11);

    final child = isBusy
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 16 : 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.button(
                    color: foreground,
                  ).copyWith(fontSize: compact ? 14 : 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(
          alpha: background.a == 0 ? 0 : 0.5,
        ),
        disabledForegroundColor: foreground.withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: padding,
        minimumSize: Size(0, compact ? 32 : 40),
        side: side,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        ),
      ),
      onPressed: isBusy ? null : onPressed,
      child: child,
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// A round, outlined icon-only button the size of a compact pill.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: CircleBorder(
            side: BorderSide(color: secondary.withValues(alpha: 0.6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(icon, size: 18, color: primary),
            ),
          ),
        ),
      ),
    );
  }
}
