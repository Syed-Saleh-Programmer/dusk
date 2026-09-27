import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class DuskPageTransitionsBuilder extends PageTransitionsBuilder {
  const DuskPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Primary entrance transition: subtle slide right-to-left + soft fade
    final primarySlide = Tween<Offset>(
      begin: const Offset(0.12, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.2, 0.0, 0.0, 1.0),
        reverseCurve: const Cubic(0.2, 0.0, 0.0, 1.0),
      ),
    );

    final primaryFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
        reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeIn),
      ),
    );

    // Secondary exit transition: slight push back & soft fade out
    final secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.06, 0.0),
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Cubic(0.2, 0.0, 0.0, 1.0),
        reverseCurve: const Cubic(0.2, 0.0, 0.0, 1.0),
      ),
    );

    final secondaryFade = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    return SlideTransition(
      position: secondarySlide,
      child: FadeTransition(
        opacity: secondaryFade,
        child: SlideTransition(
          position: primarySlide,
          child: FadeTransition(
            opacity: primaryFade,
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppTheme {
  // Signature Warm Modern Palette matching the design
  static const Color primaryColor = Color(0xFFFF7A1A); // Vibrant Dusk Orange
  static const Color primaryContainer = Color(0xFFFDE8D7); // Soft Peach
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFFC75505);

  static const Color secondaryColor = Color(0xFF4A84D8); // Sky Blue
  static const Color secondaryContainer = Color(0xFFE8F1FC);
  static const Color onSecondary = Colors.white;
  static const Color onSecondaryContainer = Color(0xFF205295);

  static const Color tertiaryColor = Color(0xFF389F7F); // Sage Mint
  static const Color tertiaryContainer = Color(0xFFE5F5F0);
  static const Color onTertiary = Colors.white;

  static const Color backgroundColor = Color(0xFFF9F7F2); // Warm Cream/Canvas
  static const Color surfaceColor = Colors.white;
  static const Color surfaceVariant = Color(0xFFF3EFE9);
  static const Color outline = Color(0xFFEBE5DC);
  static const Color outlineVariant = Color(0xFFBEB7AC);
  static const Color onSurface = Color(0xFF1B1A19); // Deep Warm Charcoal
  static const Color onSurfaceVariant = Color(0xFF6E6862); // Warm Grey

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.015,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01,
        color: onSurface,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.005,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: onSurface,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: onSurfaceVariant,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: onSurface,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: onSurfaceVariant,
      ),
    );

    return ThemeData(
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryContainer,
        onPrimary: onPrimary,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondaryColor,
        secondaryContainer: secondaryContainer,
        onSecondary: onSecondary,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiaryColor,
        tertiaryContainer: tertiaryContainer,
        onTertiary: onTertiary,
        surface: surfaceColor,
        surfaceContainerHighest: surfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme,
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: DuskPageTransitionsBuilder(),
          TargetPlatform.iOS: DuskPageTransitionsBuilder(),
          TargetPlatform.windows: DuskPageTransitionsBuilder(),
          TargetPlatform.macOS: DuskPageTransitionsBuilder(),
          TargetPlatform.linux: DuskPageTransitionsBuilder(),
          TargetPlatform.fuchsia: DuskPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFF9F7F2),
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFF0EBE1), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFECE7DE), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFECE7DE), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFAAA398),
          fontSize: 14,
        ),
      ),
    );
  }
}
