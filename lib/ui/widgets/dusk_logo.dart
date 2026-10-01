import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays the official Dusk "Folded Page & Setting Sun" logo mark.
class DuskLogo extends StatelessWidget {
  final double size;
  final bool showBadgeContainer;

  const DuskLogo({
    super.key,
    this.size = 88.0,
    this.showBadgeContainer = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final logoImage = Image.asset(
      'assets/icons/dusk_icon_foreground_1024.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Dusk Logo',
    );

    if (!showBadgeContainer) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: logoImage),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: p.outline,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: p.onSurface.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: logoImage,
      ),
    );
  }
}
