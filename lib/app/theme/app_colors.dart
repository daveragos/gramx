import 'dart:ui';

abstract class AppColors {
  // Brand colours come from the brand colour sheet. Surfaces, borders and
  // secondary text are not on the sheet.

  // Dark theme (default).
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF16181C);
  static const Color darkSurfaceVariant = Color(0xFF1D1F23);
  static const Color darkBorder = Color(0xFF2F3336);
  static const Color darkTextPrimary = Color(0xFFE7E9EA);
  static const Color darkTextSecondary = Color(0xFF71767B);

  // Light theme, using the sheet's off-white and near-black.
  static const Color lightBackground = Color(0xFFF9F9F9);
  static const Color lightSurface = Color(0xFFF9F9F9);
  static const Color lightSurfaceVariant = Color(0xFFF7F9F9);
  static const Color lightBorder = Color(0xFFEFF3F4);
  static const Color lightTextPrimary = Color(0xFF171717);
  static const Color lightTextSecondary = Color(0xFF536471);

  // Dim theme (blue-tinted dark).
  static const Color dimBackground = Color(0xFF15202B);
  static const Color dimSurface = Color(0xFF1E2732);
  static const Color dimSurfaceVariant = Color(0xFF263340);
  static const Color dimBorder = Color(0xFF38444D);
  static const Color dimTextPrimary = Color(0xFFF7F9F9);
  static const Color dimTextSecondary = Color(0xFF8B98A5);

  // The brand blue and its gradient ends.
  static const Color accent = Color(0xFF3CB8FF);
  static const Color accentDark = Color(0xFF167FBB);
  static const Color accentLight = Color(0xFFB5E4FF);

  // Action colours.
  static const Color like = Color(0xFFF91880);
  static const Color repost = Color(0xFF00BA7C);
  static const Color reply = accent;

  static const Color verified = accent;
  static const Color error = Color(0xFFF4212E);
  static const Color warning = Color(0xFFFFD400);
}
