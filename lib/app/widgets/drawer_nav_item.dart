import 'package:flutter/material.dart';
import 'package:gramx/app/theme/app_typography.dart';

/// A drawer entry: a large bold label after its icon, or, [compact], a
/// smaller one for the entries at the drawer's foot.
class DrawerNavItem extends StatelessWidget {
  final IconData? icon;

  /// Drawn in place of [icon], such as Trok's mark.
  final Widget? leading;
  final String title;
  final VoidCallback onTap;
  final bool compact;

  const DrawerNavItem({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    required this.onTap,
    this.compact = false,
  }) : assert(icon != null || leading != null);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final iconSize = compact ? 20.0 : 24.0;
    final style = compact
        ? AppTypography.body(color: color).copyWith(fontSize: 16.5)
        : AppTypography.displayName(color: color).copyWith(fontSize: 20);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: compact ? 40 : 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: iconSize,
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: leading ?? Icon(icon, size: iconSize, color: color),
                ),
              ),
              SizedBox(width: compact ? 12.8 : 12),
              Expanded(
                child: Text(
                  title,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
