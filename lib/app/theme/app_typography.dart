import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTypography {
  static TextStyle displayName({Color? color}) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
  );

  static TextStyle username({Color? color}) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.2,
  );

  static TextStyle body({Color? color}) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.4,
  );

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.4,
  );

  static TextStyle timestamp({Color? color}) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.2,
  );

  static TextStyle actionCount({Color? color}) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.2,
  );

  static TextStyle heading({Color? color}) => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
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

  static TextStyle button({Color? color}) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
  );
}
