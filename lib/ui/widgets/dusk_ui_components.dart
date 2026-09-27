import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ambient glowing background with soft warm peach/honey glow at top,
/// seamlessly blending into warm off-white canvas.
class DuskAmbientBackground extends StatelessWidget {
  final Widget child;

  const DuskAmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7F2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFDEFD9), // soft warm honey-peach glow
            Color(0xFFFAF6F0),
            Color(0xFFF9F7F2),
          ],
          stops: [0.0, 0.28, 0.65],
        ),
      ),
      child: child,
    );
  }
}

/// Circular white button with soft diffusion shadow,
/// exactly matching the back/search/options buttons in the design.
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
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFF0EBE1),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? const Color(0xFF1B1A19),
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
/// matching the Today/Upcoming/High/Ongoing badges in the design.
enum DuskBadgeVariant {
  blue,    // Soft sky blue (e.g. Today)
  peach,   // Soft warm peach (e.g. Upcoming / Thoughts)
  green,   // Soft sage mint (e.g. Done / Low / Moments)
  orange,  // Bright amber/orange (e.g. Ongoing)
  neutral, // Soft warm grey
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
    Color bg;
    Color fg;

    switch (variant) {
      case DuskBadgeVariant.blue:
        bg = const Color(0xFFE6F0FC);
        fg = const Color(0xFF3B7ED4);
        break;
      case DuskBadgeVariant.peach:
        bg = const Color(0xFFFDE8D7);
        fg = const Color(0xFFD66B1E);
        break;
      case DuskBadgeVariant.green:
        bg = const Color(0xFFE4F5EE);
        fg = const Color(0xFF2E9473);
        break;
      case DuskBadgeVariant.orange:
        bg = const Color(0xFFFFECE0);
        fg = const Color(0xFFFF7A1A);
        break;
      case DuskBadgeVariant.neutral:
        bg = const Color(0xFFF0EBE3);
        fg = const Color(0xFF6E6862);
        break;
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFEFE8DE),
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
                          ? const Color(0xFFFDE5D0)
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
                            ? const Color(0xFF1B1A19)
                            : const Color(0xFF88827A),
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
                painter: _ArcGaugePainter(percentage: percentage.clamp(0.0, 1.0)),
              ),
              Positioned(
                bottom: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerTitle,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      centerSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8E8880),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6E6862),
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

  _ArcGaugePainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 14;

    const startAngle = math.pi;
    const sweepAngle = math.pi;
    const strokeWidth = 14.0;

    // Track background
    final trackPaint = Paint()
      ..color = const Color(0xFFF1EBE2)
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
      // Progress gradient arc (Mint -> Amber -> Dusk Orange)
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: const [
          Color(0xFF2DC48D), // Mint Green
          Color(0xFFF6C343), // Sunny Amber
          Color(0xFFFF7A1A), // Dusk Warm Orange
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
    return oldDelegate.percentage != percentage;
  }
}

/// Segmented horizontal dashes, seen on the cards on Screen 2.
class DuskSegmentedDashes extends StatelessWidget {
  final int totalSegments;
  final int completedSegments;
  final Color activeColor;
  final Color inactiveColor;

  const DuskSegmentedDashes({
    super.key,
    this.totalSegments = 3,
    this.completedSegments = 2,
    this.activeColor = const Color(0xFF1B1A19),
    this.inactiveColor = const Color(0xFFE8E2D8),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSegments, (index) {
        final isActive = index < completedSegments;
        return Container(
          width: 26,
          height: 5,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// Primary action pill button, matching the "Create Task" button on Screen 3.
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
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7A1A),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: const Color(0x40FF7A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
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
                  color: const Color(0xFFF2ECE2),
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
                                          ? const Color(0xFFFF7A1A)
                                          : const Color(0xFF5E5850),
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
                                      ? const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFFFF9646),
                                            Color(0xFFFF7A1A),
                                          ],
                                        )
                                      : null,
                                  color: bar.isHighlighted
                                      ? null
                                      : (bar.count > 0
                                          ? const Color(0xFFFFB27A)
                                              .withValues(alpha: 0.65)
                                          : const Color(0xFFF0EAE0)),
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
                            ? const Color(0xFFFDE8D7)
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
                              ? const Color(0xFFD95F08)
                              : const Color(0xFF918A80),
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
                ? Container(color: const Color(0xFFF1ECE3))
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
                        : const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isSelected ? seg.color : const Color(0xFFEEE8DE),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        seg.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF88827A),
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

/// Stylish bottom navigation bar with rounded top corners, a contrast top border,
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const double barHeight = 68.0;

    return CustomPaint(
      painter: _NotchedBottomBarPainter(
        cornerRadius: 28.0,
        notchRadius: 38.0,
        shoulderRadius: 12.0,
        fabCenterY: 6.0,
        notchCenterRatio: notchCenterRatio,
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
                  index: 0,
                  icon: Icons.grid_view_rounded,
                  label: 'Captures',
                  isSelected: currentIndex == 0,
                ),
              ),
              Expanded(
                flex: 20,
                child: _buildNavItem(
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
                  index: 2,
                  icon: Icons.auto_stories_rounded,
                  label: 'Archive',
                  isSelected: currentIndex == 2,
                ),
              ),
              Expanded(
                flex: 20,
                child: _buildNavItem(
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
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    int badgeCount = 0,
  }) {
    final color = isSelected ? const Color(0xFFFF7A1A) : const Color(0xFF9E978E);

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
                      ? const Color(0xFFFF7A1A).withValues(alpha: 0.12)
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
                      color: const Color(0xFF389F7F),
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
              color: isSelected ? const Color(0xFF1B1A19) : color,
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

  _NotchedBottomBarPainter({
    required this.cornerRadius,
    required this.notchRadius,
    required this.shoulderRadius,
    required this.fabCenterY,
    this.notchCenterRatio = 0.5,
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

    // Top contour path (from left rounded corner, across carved circular notch, to right rounded corner)
    final Path topEdgePath = Path()
      ..moveTo(0, cornerRadius)
      ..arcToPoint(
        Offset(cornerRadius, 0),
        radius: Radius.circular(cornerRadius),
        clockwise: true,
      )
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
      )
      ..lineTo(w - cornerRadius, 0)
      ..arcToPoint(
        Offset(w, cornerRadius),
        radius: Radius.circular(cornerRadius),
        clockwise: true,
      );

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
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, surfacePaint);

    // 3. Contrast border on top (following rounded edges and carved circular notch)
    final Rect borderRect = Rect.fromLTWH(0, 0, w, R + cy + 10);
    final double leftStop = (notchCenterRatio - 0.16).clamp(0.05, 0.90);
    final double rightStop = (notchCenterRatio + 0.16).clamp(0.10, 0.95);
    final Paint borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFFC5B9A8), // Crisp warm contrast border on left rounded edge
          Color(0xFFD6C8B8),
          Color(0xFFFF7A1A), // Warm accent highlight around the carved circular cut
          Color(0xFFD6C8B8),
          Color(0xFFC5B9A8), // Crisp warm contrast border on right rounded edge
        ],
        stops: [0.0, leftStop, notchCenterRatio, rightStop, 1.0],
      ).createShader(borderRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(topEdgePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBottomBarPainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.shoulderRadius != shoulderRadius ||
        oldDelegate.fabCenterY != fabCenterY ||
        oldDelegate.notchCenterRatio != notchCenterRatio;
  }
}

