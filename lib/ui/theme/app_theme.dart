import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../navigation/dusk_navigation.dart';
export '../navigation/dusk_navigation.dart';

/// Available app-wide color themes for Dusk.
enum AppColorThemeId {
  duskSunset(
    id: 'dusk_sunset',
    name: 'Dusk Sunset',
    subtitle: 'Warm Amber & Sky',
    icon: Icons.wb_twilight_rounded,
  ),
  oceanBreeze(
    id: 'ocean_breeze',
    name: 'Coastal Tide',
    subtitle: 'Cobalt, Teal & Coral',
    icon: Icons.waves_rounded,
  ),
  botanicalSage(
    id: 'botanical_sage',
    name: 'Botanical Sage',
    subtitle: 'Emerald & Terracotta',
    icon: Icons.spa_rounded,
  ),
  twilightLavender(
    id: 'twilight_lavender',
    name: 'Twilight Amethyst',
    subtitle: 'Violet, Rose & Mint',
    icon: Icons.auto_awesome_rounded,
  ),
  roseQuartz(
    id: 'rose_quartz',
    name: 'Rose Horizon',
    subtitle: 'Crimson Rose & Indigo',
    icon: Icons.filter_vintage_rounded,
  ),
  espressoGold(
    id: 'espresso_gold',
    name: 'Espresso & Bronze',
    subtitle: 'Warm Bronze & Slate',
    icon: Icons.local_cafe_rounded,
  ),
  midnightDark(
    id: 'midnight_dark',
    name: 'Midnight Dark',
    subtitle: 'Deep Obsidian & Amber',
    icon: Icons.dark_mode_rounded,
  );

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;

  const AppColorThemeId({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  String get displayName => name;

  static AppColorThemeId fromId(String? id) {
    if (id == null || id.isEmpty) return AppColorThemeId.duskSunset;
    return AppColorThemeId.values.firstWhere(
      (e) => e.id == id,
      orElse: () => AppColorThemeId.duskSunset,
    );
  }

  DuskColorPalette get palette {
    switch (this) {
      case AppColorThemeId.duskSunset:
        return DuskColorPalette.duskSunset;
      case AppColorThemeId.oceanBreeze:
        return DuskColorPalette.oceanBreeze;
      case AppColorThemeId.botanicalSage:
        return DuskColorPalette.botanicalSage;
      case AppColorThemeId.twilightLavender:
        return DuskColorPalette.twilightLavender;
      case AppColorThemeId.roseQuartz:
        return DuskColorPalette.roseQuartz;
      case AppColorThemeId.espressoGold:
        return DuskColorPalette.espressoGold;
      case AppColorThemeId.midnightDark:
        return DuskColorPalette.midnightDark;
    }
  }

  bool get isDark => palette.isDark;
}

/// Complete color palette for an app color theme, registered as a [ThemeExtension]
/// so any widget reading [Theme.of(context)] or [AppTheme.of(context)] automatically
/// rebuilds and animates when the user selects a new theme.
@immutable
class DuskColorPalette extends ThemeExtension<DuskColorPalette> {
  final AppColorThemeId themeId;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primarySoftBg;
  final Color primaryContainer;
  final Color onPrimary;
  final Color onPrimaryContainer;

  final Color secondary;
  final Color secondaryLight;
  final Color secondaryContainer;
  final Color onSecondary;
  final Color onSecondaryContainer;

  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiary;
  final Color onTertiaryContainer;

  final Color background;
  final Color ambientGlowTop;
  final Color ambientGlowMid;
  final Color surface;
  final Color surfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final bool isDark;

  const DuskColorPalette({
    required this.themeId,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primarySoftBg,
    required this.primaryContainer,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryLight,
    required this.secondaryContainer,
    required this.onSecondary,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiary,
    required this.onTertiaryContainer,
    required this.background,
    required this.ambientGlowTop,
    required this.ambientGlowMid,
    required this.surface,
    required this.surfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    this.isDark = false,
  });

  /// 1. Dusk Sunset (Default Signature Warm Modern Palette)
  static const DuskColorPalette duskSunset = DuskColorPalette(
    themeId: AppColorThemeId.duskSunset,
    primary: Color(0xFFFF7A1A),
    primaryLight: Color(0xFFFF9646),
    primaryDark: Color(0xFFE56304),
    primarySoftBg: Color(0xFFFFF8F2),
    primaryContainer: Color(0xFFFDE8D7),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFFC75505),
    secondary: Color(0xFF4A84D8),
    secondaryLight: Color(0xFF639BF0),
    secondaryContainer: Color(0xFFE8F1FC),
    onSecondary: Colors.white,
    onSecondaryContainer: Color(0xFF205295),
    tertiary: Color(0xFF389F7F),
    tertiaryContainer: Color(0xFFE5F5F0),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFF1E7E60),
    background: Color(0xFFF9F7F2),
    ambientGlowTop: Color(0xFFFDEFD9),
    ambientGlowMid: Color(0xFFFAF6F0),
    surface: Colors.white,
    surfaceVariant: Color(0xFFF3EFE9),
    outline: Color(0xFFEBE5DC),
    outlineVariant: Color(0xFFBEB7AC),
    onSurface: Color(0xFF1B1A19),
    onSurfaceVariant: Color(0xFF6E6862),
  );

  /// 2. Coastal Tide (Ocean Cobalt, Seafoam Teal & Warm Coral)
  static const DuskColorPalette oceanBreeze = DuskColorPalette(
    themeId: AppColorThemeId.oceanBreeze,
    primary: Color(0xFF2563EB),
    primaryLight: Color(0xFF4F83F5),
    primaryDark: Color(0xFF1D4ED8),
    primarySoftBg: Color(0xFFF2F6FE),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF1E40AF),
    secondary: Color(0xFF0D9488),
    secondaryLight: Color(0xFF2DD4BF),
    secondaryContainer: Color(0xFFCCFBF1),
    onSecondary: Colors.white,
    onSecondaryContainer: Color(0xFF115E59),
    tertiary: Color(0xFFE86A4A),
    tertiaryContainer: Color(0xFFFFE6DF),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFFB54124),
    background: Color(0xFFF4F7FA),
    ambientGlowTop: Color(0xFFD9EAFC),
    ambientGlowMid: Color(0xFFEEF4FA),
    surface: Colors.white,
    surfaceVariant: Color(0xFFEAEFF5),
    outline: Color(0xFFDCE4EE),
    outlineVariant: Color(0xFFAAB7C7),
    onSurface: Color(0xFF131B26),
    onSurfaceVariant: Color(0xFF566376),
  );

  /// 3. Botanical Sage (Forest Emerald, Warm Terracotta & Golden Honey)
  static const DuskColorPalette botanicalSage = DuskColorPalette(
    themeId: AppColorThemeId.botanicalSage,
    primary: Color(0xFF288262),
    primaryLight: Color(0xFF43A482),
    primaryDark: Color(0xFF1C664C),
    primarySoftBg: Color(0xFFF2FAF6),
    primaryContainer: Color(0xFFDDF3EA),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF15543E),
    secondary: Color(0xFFD46845),
    secondaryLight: Color(0xFFE88464),
    secondaryContainer: Color(0xFFFAE6DF),
    onSecondary: Colors.white,
    onSecondaryContainer: Color(0xFF9C3E1E),
    tertiary: Color(0xFFD18E26),
    tertiaryContainer: Color(0xFFFDF0D5),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFF8C5A08),
    background: Color(0xFFF5F7F4),
    ambientGlowTop: Color(0xFFD9EFE3),
    ambientGlowMid: Color(0xFFEEF4F0),
    surface: Colors.white,
    surfaceVariant: Color(0xFFE8EFEA),
    outline: Color(0xFFDCE5DF),
    outlineVariant: Color(0xFFA8B8AD),
    onSurface: Color(0xFF16201B),
    onSurfaceVariant: Color(0xFF57655E),
  );

  /// 4. Twilight Amethyst (Royal Violet, Twilight Rose & Celestial Mint)
  static const DuskColorPalette twilightLavender = DuskColorPalette(
    themeId: AppColorThemeId.twilightLavender,
    primary: Color(0xFF7546E8),
    primaryLight: Color(0xFF946CF5),
    primaryDark: Color(0xFF5A2EC7),
    primarySoftBg: Color(0xFFF6F2FE),
    primaryContainer: Color(0xFFEDE5FF),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF471EB5),
    secondary: Color(0xFFDE4E7E),
    secondaryLight: Color(0xFFF06E99),
    secondaryContainer: Color(0xFFFCE4EC),
    onSecondary: Colors.white,
    onSecondaryContainer: Color(0xFF9E224D),
    tertiary: Color(0xFF2EA188),
    tertiaryContainer: Color(0xFFE0F5F0),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFF186957),
    background: Color(0xFFF7F5FA),
    ambientGlowTop: Color(0xFFE6DCF8),
    ambientGlowMid: Color(0xFFF2EFF8),
    surface: Colors.white,
    surfaceVariant: Color(0xFFEEEAF5),
    outline: Color(0xFFE2DCEE),
    outlineVariant: Color(0xFFB5ACCB),
    onSurface: Color(0xFF1B1724),
    onSurfaceVariant: Color(0xFF635B73),
  );

  /// 5. Rose Horizon (Crimson Rose, Slate Indigo & Meadow Teal)
  static const DuskColorPalette roseQuartz = DuskColorPalette(
    themeId: AppColorThemeId.roseQuartz,
    primary: Color(0xFFE0486B),
    primaryLight: Color(0xFFF06C8B),
    primaryDark: Color(0xFFC22D50),
    primarySoftBg: Color(0xFFFEF3F5),
    primaryContainer: Color(0xFFFCE2E8),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF9B1C3A),
    secondary: Color(0xFF5663D4),
    secondaryLight: Color(0xFF7480E8),
    secondaryContainer: Color(0xFFE6E9FC),
    onSecondary: Colors.white,
    onSecondaryContainer: Color(0xFF2E3A8C),
    tertiary: Color(0xFF329980),
    tertiaryContainer: Color(0xFFE2F5F0),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFF1B6956),
    background: Color(0xFFFAF5F6),
    ambientGlowTop: Color(0xFFFADCE3),
    ambientGlowMid: Color(0xFFF8EFF1),
    surface: Colors.white,
    surfaceVariant: Color(0xFFF4EAEB),
    outline: Color(0xFFEBDCE0),
    outlineVariant: Color(0xFFC4AEB4),
    onSurface: Color(0xFF21171A),
    onSurfaceVariant: Color(0xFF6E5C61),
  );

  /// 6. Espresso & Bronze (Warm Bronze, Nordic Slate & Olive Sage)
  static const DuskColorPalette espressoGold = DuskColorPalette(
    themeId: AppColorThemeId.espressoGold,
    primary: Color(0xFFB8702E),
    primaryLight: Color(0xFFD48E4D),
    primaryDark: Color(0xFF96571D),
    primarySoftBg: Color(0xFFFCF6EE),
    primaryContainer: Color(0xFFF8E8D6),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF6E3E11),
    secondary: Color(0xFF45698A),
    secondaryLight: Color(0xFF6287A8),
    secondaryContainer: Color(0xFFE4ECF2),
    onSecondary: Colors.white,
    onSecondaryContainer: Color(0xFF25425C),
    tertiary: Color(0xFF52876A),
    tertiaryContainer: Color(0xFFE5F0EA),
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFF2E5942),
    background: Color(0xFFF7F4EE),
    ambientGlowTop: Color(0xFFF2E2CA),
    ambientGlowMid: Color(0xFFF5F0E6),
    surface: Colors.white,
    surfaceVariant: Color(0xFFEDE7DC),
    outline: Color(0xFFE3DBCE),
    outlineVariant: Color(0xFFB8AEA0),
    onSurface: Color(0xFF1F1C18),
    onSurfaceVariant: Color(0xFF665F56),
  );

  /// 7. Midnight Dark (Deep Obsidian, Warm Amber & Celestial Slate)
  static const DuskColorPalette midnightDark = DuskColorPalette(
    themeId: AppColorThemeId.midnightDark,
    isDark: true,
    primary: Color(0xFFFF8C38),
    primaryLight: Color(0xFFFFA764),
    primaryDark: Color(0xFFE56E1A),
    primarySoftBg: Color(0xFF251C15),
    primaryContainer: Color(0xFF382516),
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFFFFB885),
    secondary: Color(0xFF5E9CFF),
    secondaryLight: Color(0xFF8DB8FF),
    secondaryContainer: Color(0xFF1B2840),
    onSecondary: Colors.white,
    onSecondaryContainer: Color(0xFFB8D5FF),
    tertiary: Color(0xFF3CC49B),
    tertiaryContainer: Color(0xFF14382E),
    onTertiary: Colors.black,
    onTertiaryContainer: Color(0xFF7FE5C6),
    background: Color(0xFF121316),
    ambientGlowTop: Color(0xFF251C15),
    ambientGlowMid: Color(0xFF18191E),
    surface: Color(0xFF1C1D22),
    surfaceVariant: Color(0xFF24262E),
    outline: Color(0xFF2E313C),
    outlineVariant: Color(0xFF4C5061),
    onSurface: Color(0xFFF3F4F6),
    onSurfaceVariant: Color(0xFFA1A5B4),
  );

  @override
  DuskColorPalette copyWith({
    AppColorThemeId? themeId,
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? primarySoftBg,
    Color? primaryContainer,
    Color? onPrimary,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? secondaryLight,
    Color? secondaryContainer,
    Color? onSecondary,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? tertiaryContainer,
    Color? onTertiary,
    Color? onTertiaryContainer,
    Color? background,
    Color? ambientGlowTop,
    Color? ambientGlowMid,
    Color? surface,
    Color? surfaceVariant,
    Color? outline,
    Color? outlineVariant,
    Color? onSurface,
    Color? onSurfaceVariant,
    bool? isDark,
  }) {
    return DuskColorPalette(
      themeId: themeId ?? this.themeId,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoftBg: primarySoftBg ?? this.primarySoftBg,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimary: onPrimary ?? this.onPrimary,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      secondaryLight: secondaryLight ?? this.secondaryLight,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondary: onSecondary ?? this.onSecondary,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiary: onTertiary ?? this.onTertiary,
      onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer,
      background: background ?? this.background,
      ambientGlowTop: ambientGlowTop ?? this.ambientGlowTop,
      ambientGlowMid: ambientGlowMid ?? this.ambientGlowMid,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  DuskColorPalette lerp(ThemeExtension<DuskColorPalette>? other, double t) {
    if (other is! DuskColorPalette) return this;
    return DuskColorPalette(
      themeId: t < 0.5 ? themeId : other.themeId,
      isDark: t < 0.5 ? isDark : other.isDark,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoftBg: Color.lerp(primarySoftBg, other.primarySoftBg, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      onPrimaryContainer:
          Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryLight: Color.lerp(secondaryLight, other.secondaryLight, t)!,
      secondaryContainer:
          Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      onSecondaryContainer:
          Color.lerp(onSecondaryContainer, other.onSecondaryContainer, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      tertiaryContainer:
          Color.lerp(tertiaryContainer, other.tertiaryContainer, t)!,
      onTertiary: Color.lerp(onTertiary, other.onTertiary, t)!,
      onTertiaryContainer:
          Color.lerp(onTertiaryContainer, other.onTertiaryContainer, t)!,
      background: Color.lerp(background, other.background, t)!,
      ambientGlowTop: Color.lerp(ambientGlowTop, other.ambientGlowTop, t)!,
      ambientGlowMid: Color.lerp(ambientGlowMid, other.ambientGlowMid, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
    );
  }
}

class AppTheme {
  static AppColorThemeId _activeThemeId = AppColorThemeId.duskSunset;

  static AppColorThemeId get activeThemeId => _activeThemeId;
  static DuskColorPalette get palette => _activeThemeId.palette;

  static void setActiveTheme(AppColorThemeId themeId) {
    _activeThemeId = themeId;
  }

  /// Retrieves the active [DuskColorPalette] from [BuildContext] (subscribing the widget
  /// to theme changes), falling back to [AppTheme.palette].
  static DuskColorPalette of(BuildContext context) {
    return Theme.of(context).extension<DuskColorPalette>() ?? palette;
  }

  // Dynamic theme variables (always reflect the currently selected theme)
  static Color get primaryColor => palette.primary;
  static Color get primaryLight => palette.primaryLight;
  static Color get primaryDark => palette.primaryDark;
  static Color get primarySoftBg => palette.primarySoftBg;
  static Color get primaryContainer => palette.primaryContainer;
  static Color get onPrimary => palette.onPrimary;
  static Color get onPrimaryContainer => palette.onPrimaryContainer;

  static Color get secondaryColor => palette.secondary;
  static Color get secondaryLight => palette.secondaryLight;
  static Color get secondaryContainer => palette.secondaryContainer;
  static Color get onSecondary => palette.onSecondary;
  static Color get onSecondaryContainer => palette.onSecondaryContainer;

  static Color get tertiaryColor => palette.tertiary;
  static Color get tertiaryContainer => palette.tertiaryContainer;
  static Color get onTertiary => palette.onTertiary;
  static Color get onTertiaryContainer => palette.onTertiaryContainer;

  static Color get backgroundColor => palette.background;
  static Color get ambientGlowTop => palette.ambientGlowTop;
  static Color get ambientGlowMid => palette.ambientGlowMid;
  static Color get surfaceColor => palette.surface;
  static Color get surfaceVariant => palette.surfaceVariant;
  static Color get outline => palette.outline;
  static Color get outlineVariant => palette.outlineVariant;
  static Color get onSurface => palette.onSurface;
  static Color get onSurfaceVariant => palette.onSurfaceVariant;

  static ThemeData get lightTheme => themeFor(_activeThemeId);

  static ThemeData themeFor(AppColorThemeId themeId) {
    final p = themeId.palette;

    final textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
        color: p.onSurface,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.015,
        color: p.onSurface,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01,
        color: p.onSurface,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.005,
        color: p.onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: p.onSurface,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: p.onSurface,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: p.onSurface,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: p.onSurfaceVariant,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: p.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: p.onSurface,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: p.onSurfaceVariant,
      ),
    );

    final colorScheme = p.isDark
        ? ColorScheme.dark(
            primary: p.primary,
            primaryContainer: p.primaryContainer,
            onPrimary: p.onPrimary,
            onPrimaryContainer: p.onPrimaryContainer,
            secondary: p.secondary,
            secondaryContainer: p.secondaryContainer,
            onSecondary: p.onSecondary,
            onSecondaryContainer: p.onSecondaryContainer,
            tertiary: p.tertiary,
            tertiaryContainer: p.tertiaryContainer,
            onTertiary: p.onTertiary,
            onTertiaryContainer: p.onTertiaryContainer,
            surface: p.surface,
            surfaceContainerHighest: p.surfaceVariant,
            outline: p.outline,
            outlineVariant: p.outlineVariant,
            onSurface: p.onSurface,
            onSurfaceVariant: p.onSurfaceVariant,
          )
        : ColorScheme.light(
            primary: p.primary,
            primaryContainer: p.primaryContainer,
            onPrimary: p.onPrimary,
            onPrimaryContainer: p.onPrimaryContainer,
            secondary: p.secondary,
            secondaryContainer: p.secondaryContainer,
            onSecondary: p.onSecondary,
            onSecondaryContainer: p.onSecondaryContainer,
            tertiary: p.tertiary,
            tertiaryContainer: p.tertiaryContainer,
            onTertiary: p.onTertiary,
            onTertiaryContainer: p.onTertiaryContainer,
            surface: p.surface,
            surfaceContainerHighest: p.surfaceVariant,
            outline: p.outline,
            outlineVariant: p.outlineVariant,
            onSurface: p.onSurface,
            onSurfaceVariant: p.onSurfaceVariant,
          );

    return ThemeData(
      extensions: <ThemeExtension<dynamic>>[p],
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? const Color(0xFF2B2E38) : const Color(0xFF1E1E1E),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.outline, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: p.isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: p.background,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: p.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: p.onSurface),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.outline, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          shadowColor: p.primary.withValues(alpha: 0.25),
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
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.onSurface,
          side: BorderSide(color: p.outline, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return p.primary.withValues(alpha: 0.35);
          }
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return null;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.primaryContainer,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        thumbColor: p.primary,
        inactiveTrackColor: p.primaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: p.outlineVariant,
          fontSize: 14,
        ),
      ),
    );
  }
}
