import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Sora — заголовки, Work Sans — текст. Та же пара шрифтов, что в макете.
class AppText {
  AppText._();

  static TextStyle sora({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.ink,
    double? letterSpacing,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle work({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
  }) =>
      GoogleFonts.workSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  // Готовые пресеты, которые чаще всего повторяются в макете
  static TextStyle get h1 => sora(size: 27, weight: FontWeight.w700);
  static TextStyle get h2 => sora(size: 22, weight: FontWeight.w700);
  static TextStyle get h3 => sora(size: 18, weight: FontWeight.w700);
  static TextStyle get h4 => sora(size: 15.5, weight: FontWeight.w700);

  static TextStyle get price => sora(
        size: 18,
        weight: FontWeight.w800,
        color: AppColors.teal,
      );

  static TextStyle get body => work(size: 14, color: AppColors.inkSoft);
  static TextStyle get caption => work(size: 12.5, color: AppColors.muted);
  static TextStyle get label => work(
        size: 12.5,
        weight: FontWeight.w600,
        color: AppColors.muted,
      );
}
