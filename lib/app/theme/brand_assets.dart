import 'package:flutter/material.dart';

/// Paths to the brand artwork. Launcher icons are Android resources under
/// `android/app/src/main/res` and are not loaded through Flutter.
abstract class BrandAssets {
  /// The mark animation, about three seconds a loop, played by `MarkPlayer`.
  /// Animated WebP decodes a few frames at a time, keeping memory low.
  static const String markAnimation = 'assets/brand/gramx_mark.webp';

  /// The flat monochrome mark for the feed header.
  static const String _glyphOnDark = 'assets/brand/glyph_on_dark.png';
  static const String _glyphOnLight = 'assets/brand/glyph_on_light.png';

  /// The glyph that reads against `brightness` (`dim` counts as dark).
  static String glyphFor(Brightness brightness) =>
      brightness == Brightness.dark ? _glyphOnDark : _glyphOnLight;

  /// Named for the surface they sit on, not for their own colour.
  static const String _appIconOnDark = 'assets/brand/app_icon_on_dark.png';
  static const String _appIconOnLight = 'assets/brand/app_icon_on_light.png';

  /// The framed icon that reads against `brightness` (`dim` counts as dark).
  static String appIconFor(Brightness brightness) =>
      brightness == Brightness.dark ? _appIconOnDark : _appIconOnLight;
}
