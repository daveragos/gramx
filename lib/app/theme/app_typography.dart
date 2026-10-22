import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTypography {
  // Names, handles and post text share one size. Inter is narrower than
  // Chirp, so it is tracked out a little to set the same line lengths, and
  // its regular is a step too light for post text, which is set medium.
  static const double _textSize = 15.5;

  static TextStyle displayName({Color? color}) => GoogleFonts.inter(
    fontSize: _textSize,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
    letterSpacing: 0.25,
  );

  static TextStyle username({Color? color}) => GoogleFonts.inter(
    fontSize: _textSize,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.2,
    letterSpacing: 0.3,
  );

  /// Post text, with lines 1.38 apart.
  static TextStyle body({Color? color}) => GoogleFonts.inter(
    fontSize: _textSize,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1.38,
    letterSpacing: 0.25,
  );

  /// A post's text on its own page: larger, its lines closer.
  static TextStyle detailBody({Color? color}) => GoogleFonts.inter(
    fontSize: 17.5,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1.24,
    letterSpacing: 0.25,
  );

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1.33,
  );

  static TextStyle timestamp({Color? color}) => GoogleFonts.inter(
    fontSize: _textSize,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.2,
    letterSpacing: 0.3,
  );

  static TextStyle actionCount({Color? color}) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.2,
  );

  /// The counts beside a post's actions, a size below [actionCount].
  static TextStyle actionBarCount({Color? color}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static TextStyle heading({Color? color}) => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
  );

  /// A pushed page's title in its app bar.
  static TextStyle pageTitle({Color? color}) => GoogleFonts.inter(
    fontSize: 17.5,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static TextStyle subheading({Color? color}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
  );

  static TextStyle navLabel({Color? color}) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: color,
  );

  /// Tab labels, at the size of post text.
  static TextStyle tabLabel({Color? color}) => GoogleFonts.inter(
    fontSize: _textSize,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
    letterSpacing: 0.25,
  );

  static TextStyle button({Color? color}) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
  );
}
