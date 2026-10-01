import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Defines the structured spatial transition taxonomy across Dusk.
///
/// Each navigation relationship in the app maps to a specific physical 3D
/// motion pattern rather than a generic fade:
/// - [perspectiveSlide]: Hierarchical drill-down (parent -> detail/sub-setting).
///   Full-bleed horizontal slide with 3D Y-axis perspective rotation, dynamic
///   rounded leading corners, cast shadow, and a 3D recessed background card.
/// - [modalSheetWithDepth]: Creation, capture, studio & paywall flows.
///   Vertical spring elevation with 3D X-axis pitch while the underlying screen
///   scales and tilts backward into a recessed stacked card.
/// - [ritualPortal3D]: Evening Reflection Ritual progression.
///   3D journal-page perspective rotation and depth arc between ritual stages.
/// - [flowProgression3D]: Onboarding, Auth, Profile & Schedule setup journey.
///   Spatial forward Z-depth + lateral 3D perspective glide.
/// - [sharedAxisVertical3D]: Full-screen alarm/notification elevation.
///   Vertical 3D perspective rise with depth scaling.
enum DuskTransitionType {
  perspectiveSlide,
  modalSheetWithDepth,
  ritualPortal3D,
  flowProgression3D,
  sharedAxisVertical3D,
}

/// Coordinates active transition types between primary (incoming) and
/// secondary (outgoing/underneath) routes so both screens move in
/// synchronized 3D space even when mixed route types are on the stack.
class DuskTransitionCoordinator {
  DuskTransitionCoordinator._();

  static DuskTransitionType currentSecondaryType =
      DuskTransitionType.perspectiveSlide;
}

/// Custom [MaterialPageRoute] that carries semantic [DuskTransitionType]
/// metadata, custom timing, and ensures the underlying route's
/// `secondaryAnimation` always runs in synchronized 3D space.
class DuskPageRoute<T> extends MaterialPageRoute<T> {
  final DuskTransitionType transitionType;
  final Duration? customDuration;
  final Duration? customReverseDuration;

  DuskTransitionType? _nextRouteTransitionType;

  DuskPageRoute({
    required super.builder,
    this.transitionType = DuskTransitionType.perspectiveSlide,
    this.customDuration,
    this.customReverseDuration,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  });

  /// Named constructor for hierarchical drill-down screens
  /// (e.g., DumpDetail, PastReflection, CycleTimeline, Settings sub-pages).
  factory DuskPageRoute.perspectiveSlide({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return DuskPageRoute<T>(
      builder: builder,
      transitionType: DuskTransitionType.perspectiveSlide,
      settings: settings,
    );
  }

  /// Named constructor for capture studios, paywalls, and modal sheets
  /// (e.g., TextCapture, VoiceCapture, PhotoCapture, Paywall, ShareInsight).
  factory DuskPageRoute.modalSheet({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return DuskPageRoute<T>(
      builder: builder,
      transitionType: DuskTransitionType.modalSheetWithDepth,
      settings: settings,
    );
  }

  /// Named constructor for the Evening Reflection Ritual sequence
  /// (e.g., Alarm -> ReflectionReady -> AiCycleSummary -> ReflectionFlow -> Processing -> InsightCard).
  factory DuskPageRoute.ritual({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return DuskPageRoute<T>(
      builder: builder,
      transitionType: DuskTransitionType.ritualPortal3D,
      settings: settings,
    );
  }

  /// Named constructor for sequential onboarding & account setup flows
  /// (e.g., Onboarding -> Auth -> ProfileSetup -> ReflectionScheduleSetup -> Home).
  factory DuskPageRoute.flowProgression({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return DuskPageRoute<T>(
      builder: builder,
      transitionType: DuskTransitionType.flowProgression3D,
      settings: settings,
    );
  }

  /// Named constructor for vertical 3D elevation (e.g., Alarm trigger).
  factory DuskPageRoute.vertical3D({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return DuskPageRoute<T>(
      builder: builder,
      transitionType: DuskTransitionType.sharedAxisVertical3D,
      settings: settings,
    );
  }

  DuskTransitionType get effectiveSecondaryTransitionType =>
      _nextRouteTransitionType ?? DuskTransitionCoordinator.currentSecondaryType;

  @override
  Duration get transitionDuration {
    if (customDuration != null) return customDuration!;
    switch (transitionType) {
      case DuskTransitionType.perspectiveSlide:
        return const Duration(milliseconds: 430);
      case DuskTransitionType.modalSheetWithDepth:
        return const Duration(milliseconds: 470);
      case DuskTransitionType.ritualPortal3D:
        return const Duration(milliseconds: 520);
      case DuskTransitionType.flowProgression3D:
        return const Duration(milliseconds: 480);
      case DuskTransitionType.sharedAxisVertical3D:
        return const Duration(milliseconds: 460);
    }
  }

  @override
  Duration get reverseTransitionDuration {
    if (customReverseDuration != null) return customReverseDuration!;
    switch (transitionType) {
      case DuskTransitionType.perspectiveSlide:
        return const Duration(milliseconds: 350);
      case DuskTransitionType.modalSheetWithDepth:
        return const Duration(milliseconds: 370);
      case DuskTransitionType.ritualPortal3D:
        return const Duration(milliseconds: 400);
      case DuskTransitionType.flowProgression3D:
        return const Duration(milliseconds: 380);
      case DuskTransitionType.sharedAxisVertical3D:
        return const Duration(milliseconds: 360);
    }
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    if (nextRoute is DuskPageRoute) {
      _nextRouteTransitionType = nextRoute.transitionType;
      DuskTransitionCoordinator.currentSecondaryType = nextRoute.transitionType;
      return true;
    }
    if (nextRoute is PageRoute) {
      _nextRouteTransitionType = nextRoute.fullscreenDialog
          ? DuskTransitionType.modalSheetWithDepth
          : DuskTransitionType.perspectiveSlide;
      DuskTransitionCoordinator.currentSecondaryType =
          _nextRouteTransitionType!;
      return true;
    }
    return super.canTransitionTo(nextRoute);
  }

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) {
    DuskTransitionCoordinator.currentSecondaryType = transitionType;
    return previousRoute is PageRoute;
  }

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    if (nextRoute is DuskPageRoute) {
      _nextRouteTransitionType = nextRoute.transitionType;
      DuskTransitionCoordinator.currentSecondaryType = nextRoute.transitionType;
    } else if (nextRoute is PageRoute) {
      _nextRouteTransitionType = nextRoute.fullscreenDialog
          ? DuskTransitionType.modalSheetWithDepth
          : DuskTransitionType.perspectiveSlide;
      DuskTransitionCoordinator.currentSecondaryType =
          _nextRouteTransitionType!;
    }
    super.didChangeNext(nextRoute);
  }
}

/// Global [PageTransitionsBuilder] registered in [AppTheme] that renders
/// Dusk's 3D spatial transitions for both [DuskPageRoute] and standard [PageRoute]s.
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
    // Fast-path when route is completely at rest on screen
    if (animation.value == 1.0 && secondaryAnimation.value == 0.0) {
      return child;
    }

    final DuskTransitionType primaryType;
    final DuskTransitionType secondaryType;

    if (route is DuskPageRoute<T>) {
      primaryType = route.transitionType;
      secondaryType = route.effectiveSecondaryTransitionType;
    } else {
      primaryType = route.fullscreenDialog
          ? DuskTransitionType.modalSheetWithDepth
          : DuskTransitionType.perspectiveSlide;
      secondaryType = DuskTransitionCoordinator.currentSecondaryType;
    }

    return _DuskSpatialTransitionStage(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      primaryType: primaryType,
      secondaryType: secondaryType,
      child: child,
    );
  }
}

class _DuskSpatialTransitionStage extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final DuskTransitionType primaryType;
  final DuskTransitionType secondaryType;
  final Widget child;

  const _DuskSpatialTransitionStage({
    required this.animation,
    required this.secondaryAnimation,
    required this.primaryType,
    required this.secondaryType,
    required this.child,
  });

  static const Cubic _springOutCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Cubic _sheetSpringCurve = Cubic(0.19, 1.0, 0.22, 1.0);
  static const Cubic _ritualCurve = Cubic(0.25, 1.0, 0.30, 1.0);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, _) {
        Widget current = child;

        // 1. Apply Secondary (Outgoing / Underlying Screen) 3D Transformation
        if (secondaryAnimation.value > 0.0001) {
          current = _buildSecondaryTransition(
            context: context,
            size: size,
            rawSecondary: secondaryAnimation.value,
            type: secondaryType,
            child: current,
          );
        }

        // 2. Apply Primary (Incoming / Foreground Screen) 3D Transformation
        if (animation.value < 0.9999) {
          current = _buildPrimaryTransition(
            context: context,
            size: size,
            rawPrimary: animation.value,
            type: primaryType,
            child: current,
          );
        }

        return current;
      },
    );
  }

  Widget _buildPrimaryTransition({
    required BuildContext context,
    required Size size,
    required double rawPrimary,
    required DuskTransitionType type,
    required Widget child,
  }) {
    switch (type) {
      case DuskTransitionType.perspectiveSlide:
        final t = _springOutCurve.transform(rawPrimary.clamp(0.0, 1.0));
        final inv = 1.0 - t;

        // Full horizontal slide from right + 3D Y-axis perspective rotation
        final dx = inv * size.width;
        final scale = 0.95 + (0.05 * t);
        final angleY = -0.11 * inv; // 3D swing into plane
        final radius = 28.0 * inv;
        final shadowAlpha = (0.18 * math.sin(t * math.pi)).clamp(0.0, 0.22);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..translateByDouble(dx, 0.0, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateY(angleY);

        return Transform(
          alignment: Alignment.centerLeft,
          transform: matrix,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B1A19).withValues(alpha: shadowAlpha),
                  blurRadius: 34,
                  spreadRadius: -2,
                  offset: const Offset(-14, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          ),
        );

      case DuskTransitionType.modalSheetWithDepth:
        final t = _sheetSpringCurve.transform(rawPrimary.clamp(0.0, 1.0));
        final inv = 1.0 - t;

        // Vertical rise from bottom with 3D X-axis perspective pitch
        final dy = inv * size.height;
        final scale = 0.94 + (0.06 * t);
        final angleX = 0.08 * inv;
        final topRadius = 32.0 * inv;
        final shadowAlpha = (0.22 * math.sin(t * math.pi)).clamp(0.0, 0.25);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..translateByDouble(0.0, dy, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateX(angleX);

        return Transform(
          alignment: Alignment.bottomCenter,
          transform: matrix,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(topRadius),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B1A19).withValues(alpha: shadowAlpha),
                  blurRadius: 36,
                  spreadRadius: 0,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(topRadius),
              ),
              child: child,
            ),
          ),
        );

      case DuskTransitionType.ritualPortal3D:
        final t = _ritualCurve.transform(rawPrimary.clamp(0.0, 1.0));
        final inv = 1.0 - t;

        // 3D Journal Page-Turn / Portal Arc
        final dx = inv * size.width * 0.88;
        final dy = inv * 18.0;
        final scale = 0.86 + (0.14 * t);
        final angleY = -0.20 * inv;
        final angleZ = 0.018 * inv;
        final radius = 30.0 * inv;
        final shadowAlpha = (0.22 * math.sin(t * math.pi)).clamp(0.0, 0.25);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..translateByDouble(dx, dy, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateY(angleY)
          ..rotateZ(angleZ);

        return Transform(
          alignment: Alignment.centerRight,
          transform: matrix,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A1A).withValues(
                    alpha: shadowAlpha * 0.45,
                  ),
                  blurRadius: 40,
                  offset: const Offset(-12, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF1B1A19).withValues(alpha: shadowAlpha),
                  blurRadius: 32,
                  offset: const Offset(-10, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          ),
        );

      case DuskTransitionType.flowProgression3D:
        final t = _springOutCurve.transform(rawPrimary.clamp(0.0, 1.0));
        final inv = 1.0 - t;

        // Spatial forward Z-depth + lateral 3D perspective glide
        final dx = inv * size.width * 0.72;
        final scale = 0.88 + (0.12 * t);
        final angleY = -0.14 * inv;
        final radius = 26.0 * inv;
        final shadowAlpha = (0.16 * math.sin(t * math.pi)).clamp(0.0, 0.20);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translateByDouble(dx, 0.0, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateY(angleY);

        return Transform(
          alignment: Alignment.centerLeft,
          transform: matrix,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B1A19).withValues(alpha: shadowAlpha),
                  blurRadius: 30,
                  offset: const Offset(-10, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          ),
        );

      case DuskTransitionType.sharedAxisVertical3D:
        final t = _springOutCurve.transform(rawPrimary.clamp(0.0, 1.0));
        final inv = 1.0 - t;

        final dy = inv * size.height * 0.78;
        final scale = 0.88 + (0.12 * t);
        final angleX = 0.12 * inv;
        final radius = 30.0 * inv;

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translateByDouble(0.0, dy, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateX(angleX);

        return Transform(
          alignment: Alignment.bottomCenter,
          transform: matrix,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: child,
          ),
        );
    }
  }

  Widget _buildSecondaryTransition({
    required BuildContext context,
    required Size size,
    required double rawSecondary,
    required DuskTransitionType type,
    required Widget child,
  }) {
    final s = _springOutCurve.transform(rawSecondary.clamp(0.0, 1.0));

    switch (type) {
      case DuskTransitionType.perspectiveSlide:
        // Underlying screen shifts left with parallax, scales down in 3D depth,
        // and tilts slightly away on the Y-axis like a recessed physical card.
        final dx = -0.28 * s * size.width;
        final scale = 1.0 - (0.085 * s);
        final angleY = 0.065 * s;
        final radius = 24.0 * s;
        final scrimAlpha = (0.18 * s).clamp(0.0, 0.30);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..translateByDouble(dx, 0.0, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateY(angleY);

        return Transform(
          alignment: Alignment.centerRight,
          transform: matrix,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                child,
                IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFF1B1A19).withValues(alpha: scrimAlpha),
                  ),
                ),
              ],
            ),
          ),
        );

      case DuskTransitionType.modalSheetWithDepth:
        // Underlying screen recedes into a stacked card at the top with 3D X-tilt
        final dy = -0.028 * s * size.height;
        final scale = 1.0 - (0.095 * s);
        final angleX = -0.05 * s;
        final radius = 26.0 * s;
        final scrimAlpha = (0.26 * s).clamp(0.0, 0.35);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..translateByDouble(0.0, dy, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateX(angleX);

        return Transform(
          alignment: Alignment.topCenter,
          transform: matrix,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                child,
                IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFF1B1A19).withValues(alpha: scrimAlpha),
                  ),
                ),
              ],
            ),
          ),
        );

      case DuskTransitionType.ritualPortal3D:
        // Outgoing ritual stage turns away to the left in 3D perspective
        final dx = -0.62 * s * size.width;
        final dy = 12.0 * s;
        final scale = 1.0 - (0.15 * s);
        final angleY = 0.17 * s;
        final radius = 28.0 * s;
        final scrimAlpha = (0.22 * s).clamp(0.0, 0.35);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..translateByDouble(dx, dy, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateY(angleY);

        return Transform(
          alignment: Alignment.centerLeft,
          transform: matrix,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                child,
                IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFF1B1A19).withValues(alpha: scrimAlpha),
                  ),
                ),
              ],
            ),
          ),
        );

      case DuskTransitionType.flowProgression3D:
        final dx = -0.52 * s * size.width;
        final scale = 1.0 - (0.12 * s);
        final angleY = 0.12 * s;
        final radius = 24.0 * s;
        final scrimAlpha = (0.16 * s).clamp(0.0, 0.30);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translateByDouble(dx, 0.0, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateY(angleY);

        return Transform(
          alignment: Alignment.centerLeft,
          transform: matrix,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                child,
                IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFF1B1A19).withValues(alpha: scrimAlpha),
                  ),
                ),
              ],
            ),
          ),
        );

      case DuskTransitionType.sharedAxisVertical3D:
        final dy = -0.22 * s * size.height;
        final scale = 1.0 - (0.10 * s);
        final angleX = -0.07 * s;
        final radius = 24.0 * s;
        final scrimAlpha = (0.22 * s).clamp(0.0, 0.35);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translateByDouble(0.0, dy, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0)
          ..rotateX(angleX);

        return Transform(
          alignment: Alignment.topCenter,
          transform: matrix,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                child,
                IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFF1B1A19).withValues(alpha: scrimAlpha),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

/// Direction-aware 3D Parallax Tab Switcher for [HomeScreen]'s bottom navigation bar.
///
/// Keeps all tab children alive in memory (preserving scroll positions and state
/// identically to [IndexedStack]) while animating lateral switches with a
/// 3D perspective slide + scale based on whether the user is moving left-to-right
/// (`newIndex > oldIndex`) or right-to-left (`newIndex < oldIndex`).
class DuskDirectionalTabSwitcher extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;
  final Duration duration;

  const DuskDirectionalTabSwitcher({
    super.key,
    required this.currentIndex,
    required this.children,
    this.duration = const Duration(milliseconds: 380),
  });

  @override
  State<DuskDirectionalTabSwitcher> createState() =>
      _DuskDirectionalTabSwitcherState();
}

class _DuskDirectionalTabSwitcherState extends State<DuskDirectionalTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _activeIndex;
  int? _outgoingIndex;
  double _direction = 1.0; // +1.0 when moving right, -1.0 when moving left

  static const Cubic _tabCurve = Cubic(0.22, 1.0, 0.36, 1.0);

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _outgoingIndex != null) {
          setState(() {
            _outgoingIndex = null;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant DuskDirectionalTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _activeIndex) {
      _direction = widget.currentIndex > _activeIndex ? 1.0 : -1.0;
      _outgoingIndex = _activeIndex;
      _activeIndex = widget.currentIndex;
      _controller.duration = widget.duration;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isAnimating =
            _controller.isAnimating && _outgoingIndex != null;
        final t = _tabCurve.transform(_controller.value.clamp(0.0, 1.0));
        final inv = 1.0 - t;

        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (index) {
            final isCurrent = index == _activeIndex;
            final isOutgoing = isAnimating && index == _outgoingIndex;
            final isVisible = isCurrent || isOutgoing;

            Widget tabChild = widget.children[index];

            if (isOutgoing) {
              // Outgoing tab glides to the opposite side with 3D perspective & depth recession
              final dx = -0.34 * _direction * t * width;
              final scale = 1.0 - (0.065 * t);
              final angleY = 0.065 * _direction * t;

              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..translateByDouble(dx, 0.0, 0.0, 1.0)
                ..scaleByDouble(scale, scale, 1.0, 1.0)
                ..rotateY(angleY);

              tabChild = IgnorePointer(
                child: Transform(
                  alignment: _direction > 0
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  transform: matrix,
                  child: tabChild,
                ),
              );
            } else if (isCurrent && isAnimating) {
              // Incoming tab glides in from the target side with 3D perspective & elevation shadow
              final dx = 0.42 * _direction * inv * width;
              final scale = 0.94 + (0.06 * t);
              final angleY = -0.075 * _direction * inv;
              final radius = 22.0 * inv;
              final shadowAlpha = (0.12 * math.sin(t * math.pi)).clamp(0.0, 0.16);

              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..translateByDouble(dx, 0.0, 0.0, 1.0)
                ..scaleByDouble(scale, scale, 1.0, 1.0)
                ..rotateY(angleY);

              tabChild = Transform(
                alignment: _direction > 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                transform: matrix,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B1A19)
                            .withValues(alpha: shadowAlpha),
                        blurRadius: 24,
                        offset: Offset(-8.0 * _direction, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: tabChild,
                  ),
                ),
              );
            }

            return Offstage(
              offstage: !isVisible,
              child: TickerMode(
                enabled: isVisible,
                child: tabChild,
              ),
            );
          }),
        );
      },
    );
  }
}

/// 3D Perspective Card Step Transition for in-screen multi-step flows
/// (e.g., advancing through reflection questions in [ReflectionFlowScreen]).
class DuskStepCardTransition extends StatefulWidget {
  final int stepIndex;
  final Widget child;
  final Duration duration;

  const DuskStepCardTransition({
    super.key,
    required this.stepIndex,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<DuskStepCardTransition> createState() => _DuskStepCardTransitionState();
}

class _DuskStepCardTransitionState extends State<DuskStepCardTransition> {
  int _previousStep = 0;
  double _direction = 1.0;

  @override
  void initState() {
    super.initState();
    _previousStep = widget.stepIndex;
  }

  @override
  void didUpdateWidget(covariant DuskStepCardTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stepIndex != _previousStep) {
      _direction = widget.stepIndex >= _previousStep ? 1.0 : -1.0;
      _previousStep = widget.stepIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return AnimatedSwitcher(
      duration: widget.duration,
      switchInCurve: const Cubic(0.22, 1.0, 0.36, 1.0),
      switchOutCurve: const Cubic(0.22, 1.0, 0.36, 1.0),
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final isEntering = child.key == ValueKey<int>(widget.stepIndex);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final inv = 1.0 - t;
            final dir = isEntering ? _direction : -_direction;

            final dx = dir * inv * width * 0.55;
            final scale = 0.90 + (0.10 * t);
            final angleY = -0.14 * dir * inv;

            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.0013)
              ..translateByDouble(dx, 0.0, 0.0, 1.0)
              ..scaleByDouble(scale, scale, 1.0, 1.0)
              ..rotateY(angleY);

            return Transform(
              alignment: dir > 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              transform: matrix,
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(widget.stepIndex),
        child: widget.child,
      ),
    );
  }
}
