import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/reflection_session.dart';
import '../../services/reflection_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';
import 'insight_card_screen.dart';

class ReflectionProcessingScreen extends StatefulWidget {
  final String sessionId;
  final List<ReflectionAnswer> answers;

  const ReflectionProcessingScreen({
    super.key,
    required this.sessionId,
    required this.answers,
  });

  @override
  State<ReflectionProcessingScreen> createState() => _ReflectionProcessingScreenState();
}

class _ReflectionProcessingScreenState extends State<ReflectionProcessingScreen> {
  final ReflectionService _reflectionService = ReflectionService();
  final List<String> _statusMessages = [
    "Synthesizing your reflection...",
    "Distilling patterns & lessons...",
    "Finding the underlying meaning...",
    "Creating your insight..."
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _startMessageCycle();
    _processInsight();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _startMessageCycle() {
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _statusMessages.length;
        });
      }
    });
  }

  Future<void> _processInsight() async {
    try {
      final insight = await _reflectionService.generateInsightCard(
        widget.sessionId,
        widget.answers,
      );
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          DuskPageRoute.ritual(
            builder: (_) => InsightCardScreen(insight: insight),
          ),
        );
      }
    } catch (e) {
      // In a real app we'd handle this more gracefully, but for now fallback to pop
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating insight: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Top navigation header bar
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DuskCircleButton(
                      icon: Icons.close_rounded,
                      size: 40,
                      iconSize: 18,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const DuskPillBadge(
                      text: "Step 3 of 3: Synthesis",
                      variant: DuskBadgeVariant.peach,
                      icon: Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Contemplative glowing animated orb with multi-layer breathing ripples
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing glow ring
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.primary.withValues(alpha: 0.12),
                              ),
                            ).animate(
                              onPlay: (controller) => controller.repeat(reverse: true),
                            ).scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.25, 1.25),
                              duration: const Duration(seconds: 3),
                              curve: Curves.easeInOutSine,
                            ).fade(
                              begin: 0.2,
                              end: 0.6,
                              duration: const Duration(seconds: 3),
                            ),

                            // Middle secondary glow ring
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.secondary.withValues(alpha: 0.2),
                              ),
                            ).animate(
                              onPlay: (controller) => controller.repeat(reverse: true),
                            ).scale(
                              begin: const Offset(0.85, 0.85),
                              end: const Offset(1.15, 1.15),
                              duration: const Duration(seconds: 2, milliseconds: 500),
                              curve: Curves.easeInOutSine,
                            ),

                            // Core gradient orb with radial glow
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    p.primaryLight,
                                    p.primary,
                                    p.secondary,
                                  ],
                                  stops: const [0.1, 0.6, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: p.primary.withValues(alpha: 0.45),
                                    blurRadius: 36,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: p.secondary.withValues(alpha: 0.3),
                                    blurRadius: 50,
                                    spreadRadius: 15,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 42,
                                  color: p.onPrimary,
                                ),
                              ),
                            ).animate(
                              onPlay: (controller) => controller.repeat(reverse: true),
                            ).scale(
                              begin: const Offset(0.92, 0.92),
                              end: const Offset(1.08, 1.08),
                              duration: const Duration(seconds: 3, milliseconds: 500),
                              curve: Curves.easeInOutSine,
                            ).fade(
                              begin: 0.85,
                              end: 1.0,
                              duration: const Duration(seconds: 3, milliseconds: 500),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 52),

                      // Dynamic calm status message with fade/slide transition
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _statusMessages[_currentMessageIndex],
                          key: ValueKey<int>(_currentMessageIndex),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: p.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "Please keep the app open while AI synthesizes your patterns.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: p.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
