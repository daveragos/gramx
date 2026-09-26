import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';

/// How a [PillButton] is filled.
///
/// white-on-black one for the alternative, the outlined one for a state that
/// is already true ("Following"), and the red one for the way out.
enum PillStyle { filled, outlined, danger, dangerOutlined, ghost }

/// The one button shape in the app.
///
/// A rounded pill, weight 700, the same height everywhere it appears — Join
/// and Joined on a channel, Message on a person, Post on the composer, Log out
/// in settings, and both halves of every confirmation. Before this each of
/// those was its own `ElevatedButton.styleFrom`, and no two of them agreed on
/// a radius or a padding. One widget, one shape, and the shape is decided
/// here rather than at forty call sites.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PillStyle style;

  /// Drawn before the label, small. Optional: most pills are a word.
  final IconData? icon;

  /// Replaces the label with a spinner and disables the button, for the
  /// moment between a tap and Telegram's answer.
  final bool isBusy;

  /// Stretches to the width it is given. Off by default, because a pill is
  /// as wide as its word — full width is for the stacked buttons of a
  /// confirmation, where the two have to read as a column.
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

/// A round icon-only control, the size of a compact pill.
///
/// actions, the envelope that starts a conversation. Outlined, never filled —
/// the filled pill beside them is the one thing the row is asking you to do.
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
