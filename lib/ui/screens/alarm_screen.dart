import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/alarm_sound.dart';
import '../../providers/app_state.dart';
import '../../services/notification_service.dart';
import '../widgets/dusk_logo.dart';
import '../widgets/dusk_ui_components.dart';
import '../navigation/dusk_navigation.dart';
import 'reflection_ready_screen.dart';

/// Full-screen reflection alarm screen designed in Dusk's signature
/// warm editorial palette. Plays the user's chosen calming alarm sound,
/// displays live time and current cycle capture stats, and provides
/// Begin Reflection, Snooze (1h), and Dismiss actions.
class AlarmScreen extends StatefulWidget {
  final String cycleId;

  const AlarmScreen({super.key, required this.cycleId});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _breathController;

  AlarmSound _activeSound = AlarmSound.calmHorizon;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    // Slow, meditative 3.6-second breathing cycle
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF9F7F2),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _initAndPlayAlarmSound();
  }

  Future<void> _initAndPlayAlarmSound() async {
    try {
      final selected = await AlarmSound.loadSelected();
      if (mounted) {
        setState(() {
          _activeSound = selected;
        });
      }
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(selected.defaultVolume);
      await _audioPlayer.play(AssetSource(selected.assetPath));
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
    }
  }

  Future<void> _toggleMute() async {
    try {
      final nextMuted = !_isMuted;
      setState(() {
        _isMuted = nextMuted;
      });
      await _audioPlayer.setVolume(nextMuted ? 0.0 : _activeSound.defaultVolume);
    } catch (_) {}
  }

  Future<void> _stopSound() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  void _beginReflection() async {
    await _stopSound();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      DuskPageRoute.ritual(
        builder: (_) => ReflectionReadyScreen(cycleId: widget.cycleId),
      ),
    );

    NotificationService().scheduleNextCadenceReminder();
  }

  void _dismiss() async {
    await _stopSound();

    if (!mounted) return;

    Navigator.of(context).pop();

    NotificationService().scheduleNextCadenceReminder();
  }

  void _snooze() async {
    await _stopSound();

    if (!mounted) return;

    await NotificationService().snoozeReminder(widget.cycleId);

    if (!mounted) return;
    Navigator.of(context).pop();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.snooze_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Snoozed — we\'ll remind you in 1 hour'),
              ),
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
  void dispose() {
    _stopSound();
    _breathController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final dumps = appState.todayDumps;

    int thoughtCount = 0;
    int voiceCount = 0;
    int momentCount = 0;

    for (final d in dumps) {
      final type = (d['type'] ?? 'text').toString().toLowerCase();
      if (type == 'voice' || type == 'audio') {
        voiceCount++;
      } else if (type == 'photo' || type == 'image') {
        momentCount++;
      } else {
        thoughtCount++;
      }
    }
    final totalCaptures = dumps.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _dismiss();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F7F2),
        body: DuskAmbientBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Bar: Ritual Pill Badge + Sound Mute Toggle
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: DuskPillBadge(
                                    text: 'Reflection',
                                    icon: Icons.wb_twilight_rounded,
                                    variant: DuskBadgeVariant.peach,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(child: _buildSoundStatusPill()),
                              ],
                            ).animate().fadeIn(duration: 350.ms),

                            const Spacer(flex: 2),

                            // Calm Breathing Horizon Emblem + Dusk Logo
                            Center(
                              child: AnimatedBuilder(
                                animation: _breathController,
                                builder: (context, child) {
                                  final t = Curves.easeInOutSine
                                      .transform(_breathController.value);
                                  return SizedBox(
                                    width: 156,
                                    height: 156,
                                    child: CustomPaint(
                                      painter: _BreathingHorizonPainter(
                                        progress: t,
                                        isMuted: _isMuted,
                                      ),
                                      child: Center(
                                        child: Transform.scale(
                                          scale: 1.0 + (t * 0.035),
                                          child: child,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: const DuskLogo(
                                  size: 72,
                                  showBadgeContainer: true,
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .scale(
                                  begin: const Offset(0.92, 0.92),
                                  end: const Offset(1.0, 1.0),
                                  curve: Curves.easeOutCubic,
                                  duration: 500.ms,
                                ),

                            const SizedBox(height: 20),

                            // Editorial Live Clock & Date
                            StreamBuilder<int>(
                              stream: Stream.periodic(
                                const Duration(seconds: 1),
                                (i) => i,
                              ),
                              builder: (context, _) {
                                final now = DateTime.now();
                                final timeStr = DateFormat('h:mm').format(now);
                                final periodStr = DateFormat('a').format(now);
                                final dateStr =
                                    DateFormat('EEEE, MMMM d').format(now);

                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          timeStr,
                                          style: const TextStyle(
                                            fontSize: 56,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1B1A19),
                                            letterSpacing: -2.0,
                                            height: 1.0,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          periodStr,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFFF7A1A),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF88827A),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                            const SizedBox(height: 24),

                            // Editorial Title & Subtitle
                            const Text(
                              'Time to pause and reflect',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1A19),
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            )
                                .animate()
                                .fadeIn(delay: 180.ms, duration: 400.ms)
                                .slideY(begin: 0.08),

                            const SizedBox(height: 8),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Take 5 quiet minutes to review your captures and close this cycle with clarity.',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: Color(0xFF6E6862),
                                  height: 1.45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 240.ms, duration: 400.ms)
                                .slideY(begin: 0.08),

                            const SizedBox(height: 24),

                            // Current Cycle Snapshot Card
                            _buildCycleSnapshotCard(
                              totalCaptures: totalCaptures,
                              thoughtCount: thoughtCount,
                              voiceCount: voiceCount,
                              momentCount: momentCount,
                            )
                                .animate()
                                .fadeIn(delay: 320.ms, duration: 450.ms)
                                .slideY(begin: 0.08),

                            const Spacer(flex: 3),
                            const SizedBox(height: 20),

                            // Primary Action: Begin Reflection Ritual
                            DuskPrimaryButton(
                              label: 'Begin Reflection',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _beginReflection,
                            )
                                .animate()
                                .fadeIn(delay: 400.ms, duration: 400.ms)
                                .slideY(begin: 0.1),

                            const SizedBox(height: 12),

                            // Secondary Actions: Snooze 1h & Dismiss
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSecondaryActionButton(
                                    icon: Icons.snooze_rounded,
                                    label: 'Snooze 1h',
                                    onTap: _snooze,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSecondaryActionButton(
                                    icon: Icons.close_rounded,
                                    label: 'Dismiss',
                                    onTap: _dismiss,
                                    isSubtle: true,
                                  ),
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(delay: 460.ms, duration: 400.ms)
                                .slideY(begin: 0.08),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoundStatusPill() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleMute,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0EBE1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                size: 15,
                color: _isMuted
                    ? const Color(0xFF88827A)
                    : const Color(0xFFFF7A1A),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _isMuted ? 'Muted' : _activeSound.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isMuted
                        ? const Color(0xFF88827A)
                        : const Color(0xFF1B1A19),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCycleSnapshotCard({
    required int totalCaptures,
    required int thoughtCount,
    required int voiceCount,
    required int momentCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFE8DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Status Indicator & Duration Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF7A1A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Reflection Cycle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A19),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEFE8DE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Color(0xFF88827A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '~5 min',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E6862),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Total Captures Headline
          Text(
            totalCaptures == 0
                ? 'No captures in this cycle'
                : totalCaptures == 1
                    ? '1 capture ready to review'
                    : '$totalCaptures captures ready to review',
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1A19),
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3EFE9)),
          const SizedBox(height: 14),

          // 3 Spacious Metric Tiles (No truncation)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.notes_rounded,
                  label: 'Thoughts',
                  count: thoughtCount,
                  iconColor: const Color(0xFFD66B1E),
                  bgColor: const Color(0xFFFDE8D7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.graphic_eq_rounded,
                  label: 'Voice',
                  count: voiceCount,
                  iconColor: const Color(0xFF3B7ED4),
                  bgColor: const Color(0xFFE6F0FC),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.image_rounded,
                  label: 'Moments',
                  count: momentCount,
                  iconColor: const Color(0xFF2E9473),
                  bgColor: const Color(0xFFE4F5EE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required int count,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EBE1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1A19),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E6862),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSubtle = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE8E2D8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSubtle
                    ? const Color(0xFF88827A)
                    : const Color(0xFFFF7A1A),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isSubtle
                        ? const Color(0xFF6E6862)
                        : const Color(0xFF1B1A19),
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

/// Custom painter that renders soft, warm concentric breathing rings
/// and a subtle dusk horizon arc behind the Dusk logo.
class _BreathingHorizonPainter extends CustomPainter {
  final double progress;
  final bool isMuted;

  _BreathingHorizonPainter({
    required this.progress,
    required this.isMuted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.30;

    // Soft warm ambient glow behind the badge
    final glowRadius = baseRadius + 16 + (progress * 14);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF7A1A).withValues(alpha: isMuted ? 0.06 : 0.16),
          const Color(0xFFFDE8D7).withValues(alpha: isMuted ? 0.03 : 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);

    // Outer breathing ring
    final outerRadius = baseRadius + 18 + (progress * 10);
    final outerRingPaint = Paint()
      ..color = const Color(0xFFFF7A1A)
          .withValues(alpha: isMuted ? 0.08 : (0.18 - progress * 0.08))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, outerRadius, outerRingPaint);

    // Inner breathing ring
    final innerRadius = baseRadius + 8 + (progress * 5);
    final innerRingPaint = Paint()
      ..color = const Color(0xFFD66B1E)
          .withValues(alpha: isMuted ? 0.10 : (0.24 - progress * 0.08))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, innerRadius, innerRingPaint);

    // Subtle upper dusk sun arc
    final arcRect = Rect.fromCircle(center: center, radius: outerRadius + 5);
    final arcPaint = Paint()
      ..color = const Color(0xFFFF7A1A)
          .withValues(alpha: isMuted ? 0.12 : (0.28 + progress * 0.12))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      math.pi * 1.18,
      math.pi * 0.64,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BreathingHorizonPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isMuted != isMuted;
  }
}
