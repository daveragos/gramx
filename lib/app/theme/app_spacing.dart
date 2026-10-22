abstract class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  static const double postPadding = 12.0;
  static const double avatarSize = 40.0;
  static const double avatarSizeLarge = 48.0;
  static const double avatarSizeSmall = 32.0;
  static const double avatarGap = 12.0;
  static const double actionBarHeight = 40.0;
  static const double bottomNavHeight = 56.0;
  static const double mediaRadius = 16.0;

  /// A post's photos and videos, and the card of a post it quotes.
  static const double postMediaRadius = 8.0;
  static const double quoteRadius = 12.0;
  static const double mediaBorderWidth = 0.5;
  static const double mediaGap = 2.0;

  /// Larger than any button's height, so every button is a pill.
  static const double pillRadius = 999.0;
}

/// The timeline post's geometry, in logical pixels.
abstract class PostLayout {
  static const double insetStart = 8;
  static const double insetEnd = 12;
  static const double insetTop = 12;
  static const double avatarSize = 48;
  static const double avatarGap = 8;

  /// How far the name line starts above the picture.
  static const double nameRise = 1;

  /// Between the name line and the post text.
  static const double bodyGap = 4.5;

  /// Above media, a link preview or a poll.
  static const double blockGap = 7;

  /// The "⋮" and Trok buttons: their glyphs' centre below the picture's top,
  /// the gap from the card's edge, and their widths.
  static const double trailingCenter = 8.5;
  static const double trailingEnd = 4.4;
  static const double moreWidth = 32;
  static const double trokWidth = 26.2;

  /// What the name line leaves free at its end for those buttons.
  static const double trailingRoom = 20;
  static const double trailingRoomWithTrok = 48;
}
