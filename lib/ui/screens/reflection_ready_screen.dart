import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/notification_service.dart';
import 'ai_cycle_summary_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';

class ReflectionReadyScreen extends StatefulWidget {
  final String cycleId;

  const ReflectionReadyScreen({super.key, required this.cycleId});

  @override
  State<ReflectionReadyScreen> createState() => _ReflectionReadyScreenState();
}

class _ReflectionReadyScreenState extends State<ReflectionReadyScreen> {
  Future<void> _snoozeOneHour() async {
    await NotificationService().snoozeReminder(widget.cycleId);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.snooze_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('We\'ll remind you in 1 hour'),
            ],
          ),
          backgroundColor: const Color(0xFF1B1A19),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: DuskCircleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: p.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: p.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.nights_stay_rounded,
                      size: 38,
                      color: p.primary,
                    ),
                  ),
                ).animate().fade().scale(),
                const SizedBox(height: 24),
                Text(
                  "Your reflection is ready.",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: p.onSurface,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fade(delay: 100.ms).slideY(begin: 0.1),
                const SizedBox(height: 12),
                Text(
                  "Take 5 quiet minutes to review your captures and close today's cycle.",
                  style: TextStyle(
                    fontSize: 15,
                    color: p.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                const SizedBox(height: 32),
                
                // Breakdown pill tags
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    DuskPillBadge(
                      text: "Thoughts",
                      icon: Icons.notes_rounded,
                      variant: DuskBadgeVariant.peach,
                    ),
                    DuskPillBadge(
                      text: "Voice Memos",
                      icon: Icons.graphic_eq_rounded,
                      variant: DuskBadgeVariant.blue,
                    ),
                    DuskPillBadge(
                      text: "Moments",
                      icon: Icons.image_rounded,
                      variant: DuskBadgeVariant.green,
                    ),
                  ],
                ).animate().fade(delay: 300.ms),

                const SizedBox(height: 48),
                
                DuskPrimaryButton(
                  label: "Begin Reflection",
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      DuskPageRoute.ritual(
                        builder: (_) => AiCycleSummaryScreen(cycleId: widget.cycleId),
                      ),
                    );
                  },
                ).animate().fade(delay: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _snoozeOneHour,
                      child: Text(
                        "Remind me in 1 hour",
                        style: TextStyle(color: p.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      " • ",
                      style: TextStyle(color: p.outlineVariant),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Skip this cycle",
                        style: TextStyle(color: p.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ).animate().fade(delay: 500.ms),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

