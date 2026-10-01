import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../screens/tasks_screen.dart';
import '../screens/text_capture_screen.dart';
import '../screens/voice_capture_screen.dart';
import '../screens/photo_capture_screen.dart';
import '../screens/paywall_screen.dart';
import '../widgets/dusk_ui_components.dart';
import '../theme/app_theme.dart';

/// Round speed-dial FAB menu that fans out four icon buttons
/// (Quick Task, Text, Voice, Photo) in an arc above the Plus button.
class CaptureSpeedDial extends StatefulWidget {
  /// Angles in degrees from straight up (0° = top, negative = left, positive = right).
  /// Defaults to `[-72, -24, 24, 72]` for a symmetric 4-item arc above the FAB.
  final List<double> anglesDeg;

  const CaptureSpeedDial({
    super.key,
    this.anglesDeg = const [-72, -24, 24, 72],
  });

  @override
  State<CaptureSpeedDial> createState() => _CaptureSpeedDialState();
}

class _CaptureSpeedDialState extends State<CaptureSpeedDial>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portalController = OverlayPortalController();
  late final AnimationController _animController;
  bool _isOpen = false;

  List<double> get _effectiveAngles {
    if (widget.anglesDeg.length >= 4) return widget.anglesDeg;
    if (widget.anglesDeg.length >= 2) {
      final start = widget.anglesDeg.first;
      final end = widget.anglesDeg.last;
      final step = (end - start) / 3.0;
      return [start, start + step, start + step * 2, end];
    }
    return const [-72, -24, 24, 72];
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 190),
    );
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _portalController.isShowing) {
        _portalController.hide();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      setState(() => _isOpen = false);
      _animController.reverse();
    } else {
      setState(() => _isOpen = true);
      _portalController.show();
      _animController.forward();
    }
  }

  void _closeMenuImmediate() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _animController.reset();
    if (_portalController.isShowing) {
      _portalController.hide();
    }
  }

  void _showLimitReachedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2DED6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE8D7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFF7A1A),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Daily Limit Reached (20/20)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1A19),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You've captured 20 dumps today on the Free tier. Upgrade to Dusk Pro for unlimited daily captures, 10-minute voice notes, and encrypted cloud sync.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF767068),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            DuskPrimaryButton(
              label: 'Unlock Dusk Pro',
              icon: Icons.auto_awesome_rounded,
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  DuskPageRoute.modalSheet(builder: (_) => const PaywallScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Maybe Tomorrow',
                  style: TextStyle(
                    color: Color(0xFF88827A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCaptureScreen(Widget screen) {
    _closeMenuImmediate();
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.canCaptureDump) {
      _showLimitReachedSheet();
      return;
    }
    Navigator.of(context).push(
      DuskPageRoute.modalSheet(
        builder: (_) => screen,
      ),
    );
  }

  void _openQuickTaskSheet() {
    _closeMenuImmediate();
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.canCaptureDump) {
      _showLimitReachedSheet();
      return;
    }
    showQuickTaskSheet(context);
  }

  Widget _buildMainFab({required double rotationTurns}) {
    final p = AppTheme.palette;
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.primaryLight,
            p.primary,
            p.primaryDark,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: p.primary.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _toggleMenu,
          customBorder: const CircleBorder(),
          child: Center(
            child: Transform.rotate(
              angle: rotationTurns * 2 * math.pi,
              child: Icon(
                Icons.add_rounded,
                size: 30,
                color: p.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArcOption({
    required double center,
    required double buttonSize,
    required double angleDeg,
    required double radius,
    required double scale,
    required double opacity,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final p = AppTheme.palette;
    final rad = angleDeg * math.pi / 180.0;
    final dx = radius * math.sin(rad);
    final dy = -radius * math.cos(rad);

    return Positioned(
      left: center + dx - (buttonSize / 2),
      top: center + dy - (buttonSize / 2),
      width: buttonSize,
      height: buttonSize,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Tooltip(
            message: tooltip,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surface,
                border: Border.all(
                  color: p.outline,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 23,
                      color: iconColor ?? p.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    const double overlayBoxSize = 270.0;
    const double center = overlayBoxSize / 2;
    const double optionButtonSize = 50.0;
    const double maxRadius = 90.0;
    final angles = _effectiveAngles;

    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (overlayContext) {
        return AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            final fadeValue = CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOut,
            ).value.clamp(0.0, 1.0);

            final arcProgress = CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ).value;

            final rotationTurns = 0.125 * fadeValue;

            return Stack(
              children: [
                // Subtle dimmed background overlay
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleMenu,
                    child: Opacity(
                      opacity: fadeValue,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                ),
                // Arc menu & active FAB anchored to the target FAB
                CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.center,
                  followerAnchor: Alignment.center,
                  child: SizedBox(
                    width: overlayBoxSize,
                    height: overlayBoxSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Quick Task Option
                        _buildArcOption(
                          center: center,
                          buttonSize: optionButtonSize,
                          angleDeg: angles[0],
                          radius: maxRadius * arcProgress,
                          scale: arcProgress.clamp(0.0, 1.2),
                          opacity: fadeValue,
                          icon: Icons.add_task_rounded,
                          tooltip: 'Quick Task',
                          iconColor: p.tertiary,
                          onTap: _openQuickTaskSheet,
                        ),
                        // 2. Text Dump Option
                        _buildArcOption(
                          center: center,
                          buttonSize: optionButtonSize,
                          angleDeg: angles[1],
                          radius: maxRadius * arcProgress,
                          scale: arcProgress.clamp(0.0, 1.2),
                          opacity: fadeValue,
                          icon: Icons.edit_note_rounded,
                          tooltip: 'Text Capture',
                          iconColor: p.primary,
                          onTap: () =>
                              _openCaptureScreen(const TextCaptureScreen()),
                        ),
                        // 3. Voice Dump Option
                        _buildArcOption(
                          center: center,
                          buttonSize: optionButtonSize,
                          angleDeg: angles[2],
                          radius: maxRadius * arcProgress,
                          scale: arcProgress.clamp(0.0, 1.2),
                          opacity: fadeValue,
                          icon: Icons.mic_rounded,
                          tooltip: 'Voice Capture',
                          iconColor: p.secondary,
                          onTap: () =>
                              _openCaptureScreen(const VoiceCaptureScreen()),
                        ),
                        // 4. Photo Dump Option
                        _buildArcOption(
                          center: center,
                          buttonSize: optionButtonSize,
                          angleDeg: angles[3],
                          radius: maxRadius * arcProgress,
                          scale: arcProgress.clamp(0.0, 1.2),
                          opacity: fadeValue,
                          icon: Icons.photo_camera_rounded,
                          tooltip: 'Photo Capture',
                          iconColor: p.primary,
                          onTap: () =>
                              _openCaptureScreen(const PhotoCaptureScreen()),
                        ),
                        // Center FAB (rotated + -> x)
                        Positioned(
                          left: center - 30,
                          top: center - 30,
                          width: 60,
                          height: 60,
                          child: _buildMainFab(rotationTurns: rotationTurns),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: _buildMainFab(rotationTurns: 0),
      ),
    );
  }
}
