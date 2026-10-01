import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:google_fonts/google_fonts.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/features/settings/data/app_settings.dart';

/// The palette one of the three themes is built from. Framework widgets
/// (dialogs, sheets, menus) take their colours from here.
class _Palette {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const _Palette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const light = _Palette(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceVariant: AppColors.lightSurfaceVariant,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
  );

  static const dim = _Palette(
    brightness: Brightness.dark,
    background: AppColors.dimBackground,
    surface: AppColors.dimSurface,
    surfaceVariant: AppColors.dimSurfaceVariant,
    border: AppColors.dimBorder,
    textPrimary: AppColors.dimTextPrimary,
    textSecondary: AppColors.dimTextSecondary,
  );

  static const dark = _Palette(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceVariant: AppColors.darkSurfaceVariant,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
  );
}

class AppTheme {
  static ThemeData light() => _build(_Palette.light);

  static ThemeData dark() => _build(_Palette.dark);

  static ThemeData dim() => _build(_Palette.dim);

  /// The theme for a chosen mode. `system` is resolved by `MaterialApp` (see
  /// `GramXApp`); asked for directly it returns dark, the default.
  static ThemeData getTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return light();
      case AppThemeMode.dim:
        return dim();
      case AppThemeMode.dark:
      case AppThemeMode.system:
        return dark();
    }
  }

  /// Builds every theme, so a widget theme cannot be added to only one.
  static ThemeData _build(_Palette p) {
    final isDark = p.brightness == Brightness.dark;

    // Inter for framework text (list tiles, dialogs, snackbars, menus, tabs),
    // which would otherwise fall back to Roboto.
    final baseText = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final textTheme = GoogleFonts.interTextTheme(
      baseText,
    ).apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.accent,
            secondary: AppColors.accent,
            surface: p.surface,
            onSurface: p.textPrimary,
            outline: p.border,
            error: AppColors.error,
          )
        : ColorScheme.light(
            primary: AppColors.accent,
            secondary: AppColors.accent,
            surface: p.surface,
            onSurface: p.textPrimary,
            outline: p.border,
            error: AppColors.error,
          );

    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      // Slide-in pages with an edge swipe back on every platform, instead of
      // Material's zoom.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.heading(color: p.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.background,
        selectedItemColor: p.textPrimary,
        unselectedItemColor: p.textSecondary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 0.5, space: 0),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(),
      ),
      iconTheme: IconThemeData(color: p.textSecondary, size: 20),
      // Accent-blue snackbar with white text, instead of Material's inverse
      // surface.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accent,
        contentTextStyle: AppTypography.body(color: Colors.white),
        actionTextColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
        ),
        titleTextStyle: AppTypography.heading(color: p.textPrimary),
        contentTextStyle: AppTypography.body(color: p.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.background,
        dragHandleColor: p.border,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.lg),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: AppTypography.body(color: p.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: BorderSide(color: p.border, width: 0.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textPrimary,
        textColor: p.textPrimary,
        titleTextStyle: AppTypography.body(color: p.textPrimary),
        subtitleTextStyle: AppTypography.actionCount(color: p.textSecondary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textSecondary,
        labelStyle: AppTypography.button(),
        unselectedLabelStyle: AppTypography.username(),
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
      // Every button is a pill; the families differ only in fill.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppTypography.button(),
          shape: pill,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: AppTypography.button(),
          shape: pill,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          textStyle: AppTypography.button(),
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.textSecondary.withValues(alpha: 0.6)),
          textStyle: AppTypography.button(),
          shape: pill,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppTypography.body(color: p.textSecondary),
        labelStyle: AppTypography.body(color: p.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}
