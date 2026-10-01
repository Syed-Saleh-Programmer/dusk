import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';

class CustomizationSettingsScreen extends StatelessWidget {
  const CustomizationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeTheme = appState.colorTheme;
    final p = AppTheme.of(context);
    const themes = AppColorThemeId.values;

    return Scaffold(
      backgroundColor: p.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    DuskCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 38,
                      iconSize: 17,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'App Customization',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: p.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (activeTheme != AppColorThemeId.duskSunset)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          appState.setColorTheme(AppColorThemeId.duskSunset);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: p.primary,
                          backgroundColor: p.primarySoftBg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: p.primary.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    // Section: Theme selection
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 15, color: p.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            'SELECT COLOR THEME',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: p.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. THEME CARDS GRID
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: themes.map((theme) {
                            final tp = theme.palette;
                            final isSelected = theme == activeTheme;

                            return SizedBox(
                              width: cardWidth,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    appState.setColorTheme(theme);
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected ? tp.primarySoftBg : tp.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? tp.primary : p.outline,
                                        width: isSelected ? 2.0 : 1.0,
                                      ),
                                      boxShadow: [
                                        if (isSelected)
                                          BoxShadow(
                                            color: tp.primary.withValues(alpha: 0.16),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          )
                                        else
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Mini Ambient gradient box
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [tp.ambientGlowTop, tp.background],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: tp.outline),
                                          ),
                                          child: Row(
                                            children: [
                                              _buildSwatchDot(tp.primary, size: 15),
                                              const SizedBox(width: 4),
                                              _buildSwatchDot(tp.secondary, size: 13),
                                              const SizedBox(width: 4),
                                              _buildSwatchDot(tp.tertiary, size: 13),
                                              const Spacer(),
                                              // Mini Pill Button
                                              Container(
                                                height: 14,
                                                width: 26,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [tp.primaryLight, tp.primary],
                                                  ),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Center(
                                                  child: Container(
                                                    width: 12,
                                                    height: 2.5,
                                                    decoration: BoxDecoration(
                                                      color: tp.onPrimary,
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                theme.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: p.onSurface,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              isSelected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.radio_button_unchecked_rounded,
                                              size: 17,
                                              color: isSelected ? tp.primary : p.outlineVariant,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          theme.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected ? tp.onPrimaryContainer : p.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ).animate().fadeIn(delay: 80.ms, duration: 280.ms),

                    const SizedBox(height: 28),

                    // 3. PALETTE TOKENS BREAKDOWN CARD
                    _buildPaletteTokensCard(activeTheme, p)
                        .animate()
                        .fadeIn(delay: 140.ms, duration: 280.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteTokensCard(AppColorThemeId theme, DuskColorPalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.outline),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Color Roles Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These semantic tokens adapt across buttons, charts, badges, and glows',
            style: TextStyle(
              fontSize: 12,
              color: p.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTokenItem('Primary', p.primary, p),
              _buildTokenItem('Secondary', p.secondary, p),
              _buildTokenItem('Accent', p.tertiary, p),
              _buildTokenItem('Container', p.primaryContainer, p),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenItem(String role, Color color, DuskColorPalette p) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.outline),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            role,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: p.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwatchDot(Color color, {double size = 14}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
