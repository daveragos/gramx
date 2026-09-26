import 'package:flutter/material.dart';

/// Where the brand artwork lives, and which piece of it a given surface wants.
///
/// The launcher icons are not here — those are platform resources under
/// `android/app/src/main/res` and `ios/Runner/Assets.xcassets`, built from the
/// same delivery but never loaded through Flutter. These are the places the app
/// draws its own mark: the icon, framed, the mark animating, and the flat
/// glyph in the feed header.
abstract class BrandAssets {
  /// The mark drawing itself: roughly three seconds, and the file's own loop
  /// count is infinite, so nothing has to drive it.
  ///
  /// Animated WebP rather than the Lottie the designer also delivered. That
  /// export is not vector — it is 178 full-frame PNGs base64'd into the JSON,
  /// 3.3 MB on disk and around 84 MB of bitmaps once decoded. This is the same
  /// animation at 338 KB, and Flutter decodes it a frame at a time instead of
  /// holding all of them.
  static const String markAnimation = 'assets/brand/gramx_mark.webp';

  /// The mark as a flat glyph, for the feed header. Two of them, named for
  /// the surface they sit on: the designer's Look & Feel boards draw the
  /// header with a monochrome mark — pale on the dark screen, grey on the
  /// light one — not the coloured, glossy one the splash animates. On a row
  /// that also carries an avatar and a bell, the flat mark is the one that
  /// reads as a title rather than a fourth icon.
  static const String _glyphOnDark = 'assets/brand/glyph_on_dark.png';
  static const String _glyphOnLight = 'assets/brand/glyph_on_light.png';

  /// The flat glyph that reads against `brightness`; `dim` reports
  /// `Brightness.dark` and gets the pale one.
  static String glyphFor(Brightness brightness) =>
      brightness == Brightness.dark ? _glyphOnDark : _glyphOnLight;

  /// The icons are named for the surface they sit on, not for their own
  /// colour — the light-ground icon is the one that belongs on a dark screen,
  /// and reading it the other way round is how you end up with black on black.
  static const String _appIconOnDark = 'assets/brand/app_icon_on_dark.png';
  static const String _appIconOnLight = 'assets/brand/app_icon_on_light.png';

  /// The framed icon that reads against `brightness`. `dim` reports
  /// `Brightness.dark`, so the two cases cover all three themes.
  static String appIconFor(Brightness brightness) =>
      brightness == Brightness.dark ? _appIconOnDark : _appIconOnLight;
}
