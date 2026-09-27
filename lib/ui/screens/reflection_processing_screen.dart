import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/reflection_session.dart';
import '../../services/reflection_service.dart';
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
          MaterialPageRoute(
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
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF), // Canvas Base
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Contemplative breathing animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFD4A76A), // Muted amber center
                    Color(0xFF756A91), // Dusk violet outer
                  ],
                  stops: [0.2, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF756A91).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOutSine,
            ).fade(
              begin: 0.7,
              end: 1.0,
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOutSine,
            ),
            
            const SizedBox(height: 64),
            
            // Dynamic calm status message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: Text(
                _statusMessages[_currentMessageIndex],
                key: ValueKey<int>(_currentMessageIndex),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF49454D), // Text Secondary
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
