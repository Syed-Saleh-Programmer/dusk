import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF5C5277);
  static const Color primaryContainer = Color(0xFF756A91);
  static const Color onPrimary = Colors.white;
  static const Color secondaryColor = Color(0xFF7B5822);
  static const Color backgroundColor = Color(0xFFFDF7FF);
  static const Color surfaceColor = Color(0xFFFDF7FF);
  static const Color surfaceVariant = Color(0xFFE6E0E9);
  static const Color outline = Color(0xFF7A757E);
  static const Color onSurface = Color(0xFF1D1B20);
  static const Color onSurfaceVariant = Color(0xFF49454D);

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryContainer,
        onPrimary: onPrimary,
        secondary: secondaryColor,
        surface: surfaceColor,
        surfaceContainerHighest: surfaceVariant,
        outline: outline,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        displayLarge: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w500, letterSpacing: -0.02),
        headlineLarge: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.015),
        headlineMedium: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.01),
        headlineSmall: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.005),
        bodyLarge: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0),
        bodyMedium: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.005),
        bodySmall: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.01),
        labelLarge: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.01),
        labelSmall: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.02),
      ),
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
    );
  }
}
