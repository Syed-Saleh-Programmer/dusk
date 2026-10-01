import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';

/// Ambient glowing background with soft warm glow at top,
/// seamlessly blending into the active theme's canvas background.
class DuskAmbientBackground extends StatelessWidget {
  final Widget child;

  const DuskAmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.background,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.ambientGlowTop,
            p.ambientGlowMid,
            p.background,
          ],
          stops: const [0.0, 0.28, 0.65],
        ),
      ),
      child: child,
    );
  }
}

/// Circular surface button with soft diffusion shadow,
/// matching the back/search/options buttons in the design.
class DuskCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final String? tooltip;

  const DuskCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 42,
    this.iconSize = 20,
    this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: p.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: p.outline,
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? p.onSurface,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Pill-shaped tag badge with soft pastel backgrounds,
/// adapting to the active color theme's primary, secondary, tertiary, and neutral containers.
enum DuskBadgeVariant {
  blue,    // Secondary theme accent
  peach,   // Primary container accent
  green,   // Tertiary theme accent
  orange,  // Vibrant primary accent
  neutral, // Soft warm neutral
}

class DuskPillBadge extends StatelessWidget {
  final String text;
  final DuskBadgeVariant variant;
  final IconData? icon;
  final VoidCallback? onTap;

  const DuskPillBadge({
    super.key,
    required this.text,
    this.variant = DuskBadgeVariant.peach,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    Color bg;
    Color fg;

    switch (variant) {
      case DuskBadgeVariant.blue:
        bg = p.secondaryContainer;
        fg = p.onSecondaryContainer;
        break;
      case DuskBadgeVariant.peach:
        bg = p.primaryContainer;
        fg = p.onPrimaryContainer;
        break;
      case DuskBadgeVariant.green:
        bg = p.tertiaryContainer;
        fg = p.onTertiaryContainer;
        break;
      case DuskBadgeVariant.orange:
        bg = p.primary.withValues(alpha: 0.14);
        fg = p.primary;
        break;
      case DuskBadgeVariant.neutral:
        bg = p.surfaceVariant;
        fg = p.onSurfaceVariant;
        break;
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      );
    }
    return content;
  }
}

/// Segmented pill tabs that use full width with proper individual tab paddings,
/// and scroll horizontally if the combined tabs exceed the available width.
class DuskPillTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const DuskPillTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: p.outline,
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availWidth = constraints.maxWidth;
          final textScaler = MediaQuery.textScalerOf(context);
          final textDirection = Directionality.of(context);
          final baseTextStyle = DefaultTextStyle.of(context).style;
          const double minHorizontalPad = 14.0;
          const double gap = 4.0;

          double totalNaturalTextWidth = 0;
          for (final tab in tabs) {
            final tp = TextPainter(
              text: TextSpan(
                text: tab,
                style: baseTextStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              maxLines: 1,
              textDirection: textDirection,
              textScaler: textScaler,
            )..layout();
            // Add 2px safety margin per tab for subpixel/font rendering variance
            totalNaturalTextWidth += tp.width.ceilToDouble() + 2.0;
          }

          final double totalGaps =
              tabs.length > 1 ? (tabs.length - 1) * gap : 0.0;
          final double minRequiredWidth =
              totalNaturalTextWidth + (tabs.length * minHorizontalPad * 2) + totalGaps;

          final double safeAvailWidth = math.max(0.0, availWidth - 2.0);
          final bool needsScroll =
              !availWidth.isFinite || minRequiredWidth > safeAvailWidth;

          final double horizontalPad = needsScroll
              ? 18.0
              : math.max(
                  8.0,
                  (safeAvailWidth - totalNaturalTextWidth - totalGaps) /
                      (tabs.length * 2),
                );

          final row = Row(
            mainAxisSize: needsScroll ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(tabs.length, (index) {
              final isSelected = selectedIndex == index;
              return Padding(
                padding: EdgeInsets.only(
                  right: index < tabs.length - 1 ? gap : 0,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTabSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPad,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? p.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tabs[index],
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: isSelected
                            ? p.onSurface
                            : p.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );

          if (needsScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: row,
            );
          }

          return row;
        },
      ),
    );
  }
}

/// Semi-circular arched gauge, reproducing the "Updates 75% Done" gauge on Screen 1!
class DuskArcGauge extends StatelessWidget {
  final double percentage; // 0.0 to 1.0
  final String centerTitle;
  final String centerSubtitle;
  final List<DuskLegendItem> legends;

  const DuskArcGauge({
    super.key,
    required this.percentage,
    required this.centerTitle,
    required this.centerSubtitle,
    this.legends = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 125,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CustomPaint(
                size: const Size(220, 110),
                painter: _ArcGaugePainter(
                  percentage: percentage.clamp(0.0, 1.0),
                  startColor: p.tertiary,
                  midColor: p.primaryLight,
                  endColor: p.primary,
                  trackColor: p.surfaceVariant,
                ),
              ),
              Positioned(
                bottom: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerTitle,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: p.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      centerSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: p.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (legends.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: legends.map((item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: p.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class DuskLegendItem {
  final String label;
  final Color color;

  const DuskLegendItem({required this.label, required this.color});
}

class _ArcGaugePainter extends CustomPainter {
  final double percentage;
  final Color startColor;
  final Color midColor;
  final Color endColor;
  final Color trackColor;

  _ArcGaugePainter({
    required this.percentage,
    required this.startColor,
    required this.midColor,
    required this.endColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 14;

    const startAngle = math.pi;
    const sweepAngle = math.pi;
    const strokeWidth = 14.0;

    // Track background
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    if (percentage > 0) {
      // Progress gradient arc
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: [
          startColor,
          midColor,
          endColor,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * percentage,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.startColor != startColor ||
        oldDelegate.midColor != midColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Segmented horizontal dashes, seen on the cards on Screen 2.
class DuskSegmentedDashes extends StatelessWidget {
  final int totalSegments;
  final int completedSegments;
  final Color? activeColor;
  final Color? inactiveColor;

  const DuskSegmentedDashes({
    super.key,
    this.totalSegments = 3,
    this.completedSegments = 2,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final active = activeColor ?? p.onSurface;
    final inactive = inactiveColor ?? p.outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSegments, (index) {
        final isActive = index < completedSegments;
        return Container(
          width: 26,
          height: 5,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isActive ? active : inactive,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// Primary action pill button, adapting to the active color theme.
class DuskPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const DuskPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          shadowColor: p.primary.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(p.onPrimary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Data segment for capture breakdown analytics.
class DuskChartSegment {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final String filterKey;

  const DuskChartSegment({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.filterKey,
  });
}

/// Bar item for [DuskActivityBarChart].
class DuskBarData {
  final String label;
  final int count;
  final bool isHighlighted;

  const DuskBarData({
    required this.label,
    required this.count,
    this.isHighlighted = false,
  });
}

/// Spacious full-width 7-day activity bar chart with subtle horizontal guide lines.
class DuskActivityBarChart extends StatelessWidget {
  final List<DuskBarData> bars;
  final double height;

  const DuskActivityBarChart({
    super.key,
    required this.bars,
    this.height = 128,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    int maxCount = 1;
    for (final b in bars) {
      if (b.count > maxCount) maxCount = b.count;
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Subtle horizontal reference lines across the chart area
          Positioned.fill(
            bottom: 24,
            top: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (_) => Container(
                  height: 1,
                  color: p.surfaceVariant,
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: bars.map((bar) {
              final double normalized =
                  maxCount > 0 ? (bar.count / maxCount).clamp(0.0, 1.0) : 0.0;

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availH = math.max(20.0, constraints.maxHeight);
                          final maxBarH = math.max(12.0, availH - 22.0);
                          final double barHeight = bar.count == 0
                              ? 6.0
                              : (12.0 +
                                      normalized *
                                          math.max(0.0, maxBarH - 12.0))
                                  .clamp(8.0, maxBarH);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (bar.count > 0 && availH > 28)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${bar.count}',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.0,
                                      fontWeight: FontWeight.w800,
                                      color: bar.isHighlighted
                                          ? p.primary
                                          : p.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: 22,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: bar.isHighlighted
                                      ? LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            p.primaryLight,
                                            p.primary,
                                          ],
                                        )
                                      : null,
                                  color: bar.isHighlighted
                                      ? null
                                      : (bar.count > 0
                                          ? p.primaryLight
                                              .withValues(alpha: 0.55)
                                          : p.surfaceVariant),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: bar.isHighlighted
                            ? p.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bar.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.1,
                          fontWeight: bar.isHighlighted
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: bar.isHighlighted
                              ? p.onPrimaryContainer
                              : p.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Clean full-width stacked distribution bar and interactive breakdown list.
class DuskTypeBreakdownChart extends StatelessWidget {
  final List<DuskChartSegment> segments;
  final int totalCount;
  final String selectedType;
  final ValueChanged<String> onSelectType;

  const DuskTypeBreakdownChart({
    super.key,
    required this.segments,
    required this.totalCount,
    required this.selectedType,
    required this.onSelectType,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final activeSegments = segments.where((s) => s.count > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Proportional Horizontal Segmented Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: totalCount == 0
                ? Container(color: p.surfaceVariant)
                : Row(
                    children: [
                      for (int i = 0; i < activeSegments.length; i++) ...[
                        Expanded(
                          flex: math.max(1, activeSegments[i].count * 100),
                          child: Container(color: activeSegments[i].color),
                        ),
                        if (i < activeSegments.length - 1)
                          const SizedBox(width: 3),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),
        // Clean 3-column interactive breakdown cards
        Row(
          children: List.generate(segments.length, (i) {
            final seg = segments[i];
            final isSelected =
                selectedType.toLowerCase() == seg.filterKey.toLowerCase();
            final int pct = totalCount > 0
                ? ((seg.count / totalCount) * 100).round()
                : 0;

            return Expanded(
              child: GestureDetector(
                onTap: () => onSelectType(seg.filterKey),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(
                    right: i < segments.length - 1 ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? seg.color.withValues(alpha: 0.12)
                        : p.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? seg.color : p.outline,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(seg.icon, size: 16, color: seg.color),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: seg.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${seg.count}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: p.onSurface,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        seg.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Stylish bottom navigation bar with straight top edges at the ends, a contrast top border,
/// and a smooth carved circular cut (notch) around the Plus button.
class DuskNotchedBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final int pendingTasksCount;
  final double notchCenterRatio;

  const DuskNotchedBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.pendingTasksCount = 0,
    this.notchCenterRatio = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const double barHeight = 68.0;

    return CustomPaint(
      painter: _NotchedBottomBarPainter(
        cornerRadius: 0.0,
        notchRadius: 38.0,
        shoulderRadius: 12.0,
        fabCenterY: 6.0,
        notchCenterRatio: notchCenterRatio,
        accentColor: p.primary,
        borderColor: p.outlineVariant,
        surfaceColor: p.surface,
      ),
      child: SizedBox(
        height: barHeight + bottomInset,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Row(
            children: [
              Expanded(
                flex: 20,
                child: _buildNavItem(
                  palette: p,
                  index: 0,
                  icon: Icons.grid_view_rounded,
                  label: 'Captures',
                  isSelected: currentIndex == 0,
                ),
              ),
              Expanded(
                flex: 20,
                child: _buildNavItem(
                  palette: p,
                  index: 1,
                  icon: Icons.task_alt_rounded,
                  label: 'Tasks',
                  isSelected: currentIndex == 1,
                  badgeCount: pendingTasksCount,
                ),
              ),
              const Expanded(
                flex: 20,
                child: SizedBox.shrink(), // Centered carved circular notch & FAB
              ),
              Expanded(
                flex: 20,
                child: _buildNavItem(
                  palette: p,
                  index: 2,
                  icon: Icons.auto_stories_rounded,
                  label: 'Archive',
                  isSelected: currentIndex == 2,
                ),
              ),
              Expanded(
                flex: 20,
                child: _buildNavItem(
                  palette: p,
                  index: 3,
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: currentIndex == 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required DuskColorPalette palette,
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    int badgeCount = 0,
  }) {
    final color = isSelected ? palette.primary : palette.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTabSelected(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? palette.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                    decoration: BoxDecoration(
                      color: palette.tertiary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? palette.onSurface : color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotchedBottomBarPainter extends CustomPainter {
  final double cornerRadius;
  final double notchRadius;
  final double shoulderRadius;
  final double fabCenterY;
  final double notchCenterRatio;
  final Color accentColor;
  final Color borderColor;
  final Color surfaceColor;

  _NotchedBottomBarPainter({
    required this.cornerRadius,
    required this.notchRadius,
    required this.shoulderRadius,
    required this.fabCenterY,
    this.notchCenterRatio = 0.5,
    required this.accentColor,
    required this.borderColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w * notchCenterRatio;
    final double cy = fabCenterY;
    final double R = notchRadius;
    final double r = shoulderRadius;

    // Horizontal distance from cx to the shoulder circle centers
    final double dy = r - cy;
    final double dx = math.sqrt(math.max(0.0, (R + r) * (R + r) - dy * dy));

    // Tangency points between the shoulder circles and the main carved circle
    final double txLeft = cx - dx * (R / (R + r));
    final double txRight = cx + dx * (R / (R + r));
    final double ty = cy + dy * (R / (R + r));

    // Top contour path (from left straight corner, across carved circular notch, to right straight corner)
    final Path topEdgePath = Path();
    if (cornerRadius > 0) {
      topEdgePath
        ..moveTo(0, cornerRadius)
        ..arcToPoint(
          Offset(cornerRadius, 0),
          radius: Radius.circular(cornerRadius),
          clockwise: true,
        );
    } else {
      topEdgePath.moveTo(0, 0);
    }

    topEdgePath
      ..lineTo(cx - dx, 0)
      ..arcToPoint(
        Offset(txLeft, ty),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..arcToPoint(
        Offset(txRight, ty),
        radius: Radius.circular(R),
        clockwise: false,
      )
      ..arcToPoint(
        Offset(cx + dx, 0),
        radius: Radius.circular(r),
        clockwise: true,
      );

    if (cornerRadius > 0) {
      topEdgePath
        ..lineTo(w - cornerRadius, 0)
        ..arcToPoint(
          Offset(w, cornerRadius),
          radius: Radius.circular(cornerRadius),
          clockwise: true,
        );
    } else {
      topEdgePath.lineTo(w, 0);
    }

    // Full filled shape path
    final Path fillPath = Path.from(topEdgePath)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    // 1. Soft upward ambient shadow
    final Paint shadowPaint = Paint()
      ..color = const Color(0xFF1B1A19).withValues(alpha: 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.save();
    canvas.translate(0, -3);
    canvas.drawPath(fillPath, shadowPaint);
    canvas.restore();

    // 2. Crisp white surface fill
    final Paint surfacePaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, surfacePaint);

    // 3. Contrast border on top (following straight edges and carved circular notch)
    final Rect borderRect = Rect.fromLTWH(0, 0, w, R + cy + 10);
    final double leftStop = (notchCenterRatio - 0.16).clamp(0.05, 0.90);
    final double rightStop = (notchCenterRatio + 0.16).clamp(0.10, 0.95);
    final Paint borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          borderColor,
          borderColor.withValues(alpha: 0.7),
          accentColor, // Active theme accent highlight around the carved circular cut
          borderColor.withValues(alpha: 0.7),
          borderColor,
        ],
        stops: [0.0, leftStop, notchCenterRatio, rightStop, 1.0],
      ).createShader(borderRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = cornerRadius > 0 ? StrokeCap.round : StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(topEdgePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBottomBarPainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.shoulderRadius != shoulderRadius ||
        oldDelegate.fabCenterY != fabCenterY ||
        oldDelegate.notchCenterRatio != notchCenterRatio ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}

/// Interactive tag selector & custom tag creator widget used across Dumps and Tasks.
class DuskTagSelector extends StatefulWidget {
  final List<String> availableTags;
  final List<String> selectedTags;
  final ValueChanged<List<String>> onChanged;
  final Future<String?> Function(String newTag)? onCreateCustomTag;
  final bool wrap;
  final String? label;

  const DuskTagSelector({
    super.key,
    required this.availableTags,
    required this.selectedTags,
    required this.onChanged,
    this.onCreateCustomTag,
    this.wrap = false,
    this.label,
  });

  @override
  State<DuskTagSelector> createState() => _DuskTagSelectorState();
}

class _DuskTagSelectorState extends State<DuskTagSelector> {
  bool _isAdding = false;
  final TextEditingController _customTagController = TextEditingController();
  final FocusNode _customTagFocus = FocusNode();

  @override
  void dispose() {
    _customTagController.dispose();
    _customTagFocus.dispose();
    super.dispose();
  }

  bool _isSelected(String tag) {
    final lower = tag.toLowerCase();
    return widget.selectedTags.any((t) => t.toLowerCase() == lower);
  }

  void _toggleTag(String tag) {
    final lower = tag.toLowerCase();
    final current = List<String>.from(widget.selectedTags);
    final idx = current.indexWhere((t) => t.toLowerCase() == lower);
    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.add(tag);
    }
    widget.onChanged(current);
  }

  Future<void> _submitCustomTag() async {
    final raw = _customTagController.text.replaceAll('#', '').trim();
    if (raw.isEmpty) {
      setState(() => _isAdding = false);
      return;
    }

    String resolved = raw.length > 1 && raw == raw.toLowerCase()
        ? raw[0].toUpperCase() + raw.substring(1)
        : raw;

    if (widget.onCreateCustomTag != null) {
      final created = await widget.onCreateCustomTag!(resolved);
      if (created != null && created.trim().isNotEmpty) {
        resolved = created.trim();
      }
    }

    if (!mounted) return;
    _customTagController.clear();
    setState(() => _isAdding = false);

    if (!_isSelected(resolved)) {
      widget.onChanged([...widget.selectedTags, resolved]);
    }
  }

  List<String> _buildOrderedTags() {
    final seen = <String>{};
    final result = <String>[];
    // Keep any selected tags that might be newly added visible first if not in availableTags
    for (final t in [...widget.availableTags, ...widget.selectedTags]) {
      final clean = t.trim();
      if (clean.isEmpty) continue;
      if (seen.add(clean.toLowerCase())) {
        result.add(clean);
      }
    }
    return result;
  }

  Widget _buildAddChip(DuskColorPalette p) {
    if (_isAdding) {
      return Container(
        height: 32,
        constraints: const BoxConstraints(minWidth: 130, maxWidth: 190),
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.primary, width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag_rounded, size: 13, color: p.primary),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _customTagController,
                focusNode: _customTagFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitCustomTag(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'New tag...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: p.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
            GestureDetector(
              onTap: _submitCustomTag,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: p.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () {
                _customTagController.clear();
                setState(() => _isAdding = false);
              },
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: p.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() => _isAdding = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _customTagFocus.requestFocus();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        decoration: BoxDecoration(
          color: p.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: p.primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: p.primary),
            const SizedBox(width: 3),
            Text(
              'New Tag',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagPill(String tag, DuskColorPalette p) {
    final selected = _isSelected(tag);
    return GestureDetector(
      onTap: () => _toggleTag(tag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        decoration: BoxDecoration(
          color: selected ? p.onSurface : p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? p.onSurface : p.outline,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#$tag',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? p.surface : p.onSurfaceVariant,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_rounded,
                size: 12,
                color: p.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final allTags = _buildOrderedTags();

    final chips = <Widget>[
      _buildAddChip(p),
      for (final tag in allTags) _buildTagPill(tag, p),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Row(
            children: [
              Icon(
                Icons.sell_outlined,
                size: 13,
                color: p.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
              if (widget.selectedTags.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.selectedTags.length}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: p.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (widget.wrap)
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: chips,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  chips[i],
                  if (i < chips.length - 1) const SizedBox(width: 7),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Displays an auto-dismissing, floating SnackBar that dismisses
/// immediately after 1.5 - 2s (default: 1800ms) and never shifts or blocks the UI layout.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showDuskSnackBar(
  BuildContext context, {
  required dynamic content,
  SnackBarAction? action,
  Duration duration = const Duration(milliseconds: 1800),
  Color? backgroundColor,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();

  final widgetContent = content is Widget ? content : Text(content.toString());

  final controller = messenger.showSnackBar(
    SnackBar(
      content: widgetContent,
      duration: duration,
      action: action,
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );

  // Guarantee immediate removal after duration even if an action or system accessibility service tries to hold it open
  Future.delayed(duration, () {
    try {
      controller.close();
    } catch (_) {}
  });

  return controller;
}

/// Quick theme switcher button designed for top app bars across Capture and Home screens.
/// Features a palette icon with a live indicator swatch of the active theme color.
/// Tapping opens a sleek quick theme picker sheet; long-pressing cycles to the next theme.
class DuskQuickThemeButton extends StatelessWidget {
  final double size;
  final double iconSize;

  const DuskQuickThemeButton({
    super.key,
    this.size = 40,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeTheme = appState.colorTheme;
    final p = AppTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          showDuskQuickThemeModal(context);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          final nextIndex = (AppColorThemeId.values.indexOf(activeTheme) + 1) % AppColorThemeId.values.length;
          final nextTheme = AppColorThemeId.values[nextIndex];
          appState.setColorTheme(nextTheme);
          showDuskSnackBar(
            context,
            content: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: nextTheme.palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Switched to ${nextTheme.name}'),
              ],
            ),
            duration: const Duration(milliseconds: 1400),
          );
        },
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: p.surface,
            shape: BoxShape.circle,
            border: Border.all(color: p.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.palette_outlined,
                size: iconSize,
                color: p.onSurface,
              ),
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: activeTheme.palette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens an interactive bottom sheet to quickly preview and switch between all 7 Dusk color themes.
void showDuskQuickThemeModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Consumer<AppState>(
        builder: (context, appState, _) {
          final activeTheme = appState.colorTheme;
          final p = AppTheme.of(context);

          return Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: p.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: p.primarySoftBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.palette_outlined, color: p.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Theme Switcher',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: p.onSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  'Current: ${activeTheme.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: p.onSurfaceVariant),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Themes Grid / List
                    SizedBox(
                      height: 125,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: AppColorThemeId.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final theme = AppColorThemeId.values[index];
                          final isSelected = theme == activeTheme;
                          final tp = theme.palette;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              appState.setColorTheme(theme);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 105,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? tp.primarySoftBg : tp.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected ? tp.primary : p.outline,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: tp.primary.withValues(alpha: 0.18),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: tp.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: tp.secondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: tp.tertiary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    theme.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? tp.primaryDark : p.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tp.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// A floating AI trigger button that keeps its size constant and smoothly
/// rotates its gradient colors continuously.
class DuskAiRotatingGradientButton extends StatefulWidget {
  final DuskColorPalette palette;
  final VoidCallback onTap;
  final double size;
  final bool animateRotation;

  const DuskAiRotatingGradientButton({
    super.key,
    required this.palette,
    required this.onTap,
    this.size = 56.0,
    this.animateRotation = true,
  });

  @override
  State<DuskAiRotatingGradientButton> createState() =>
      _DuskAiRotatingGradientButtonState();
}

class _DuskAiRotatingGradientButtonState
    extends State<DuskAiRotatingGradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.animateRotation) {
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chat with Dusk Buddy',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              final angle = _rotationController.value * 2 * math.pi;
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      widget.palette.primary,
                      widget.palette.tertiary,
                      const Color(0xFF68B06D),
                      widget.palette.primary,
                    ],
                    transform: GradientRotation(angle),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.palette.primary.withValues(alpha: 0.38),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: widget.palette.tertiary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}
