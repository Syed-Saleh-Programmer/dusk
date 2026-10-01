import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/alarm_sound.dart';
import '../../providers/app_state.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';
import 'alarm_sound_screen.dart';
import 'edit_reflection_schedule_screen.dart';

class EveningRitualSettingsScreen extends StatefulWidget {
  const EveningRitualSettingsScreen({super.key});

  @override
  State<EveningRitualSettingsScreen> createState() => _EveningRitualSettingsScreenState();
}

class _EveningRitualSettingsScreenState extends State<EveningRitualSettingsScreen> {
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 21, minute: 0);
  int _scheduleFrequency = 3;
  AlarmSound _selectedAlarmSound = AlarmSound.calmHorizon;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = SupabaseService().currentUser?.id;
    final suffix = (uid != null && uid.isNotEmpty) ? '_$uid' : '';
    final hour = prefs.getInt('reflection_reminder_hour$suffix') ?? prefs.getInt('schedule_hour') ?? 21;
    final minute = prefs.getInt('reflection_reminder_minute$suffix') ?? prefs.getInt('schedule_minute') ?? 0;
    final frequency = prefs.getInt('schedule_frequency') ?? 3;
    final soundName = prefs.getString('alarm_sound') ?? AlarmSound.calmHorizon.name;

    final sound = AlarmSound.values.firstWhere(
      (s) => s.name == soundName,
      orElse: () => AlarmSound.calmHorizon,
    );

    if (mounted) {
      setState(() {
        _scheduleTime = TimeOfDay(hour: hour, minute: minute);
        _scheduleFrequency = frequency;
        _selectedAlarmSound = sound;
        _isLoading = false;
      });
    }
  }

  String _getFrequencyLabel(int days) {
    if (days == 1) return 'Every evening (Daily)';
    return 'Every $days days';
  }

  Future<void> _openScheduleScreen() async {
    final result = await Navigator.of(context).push(
      DuskPageRoute.perspectiveSlide(
        builder: (_) => const EditReflectionScheduleScreen(),
      ),
    );
    if (result == true) {
      _loadSettings();
    }
  }

  Future<void> _openAlarmSoundScreen() async {
    final result = await Navigator.of(context).push(
      DuskPageRoute.perspectiveSlide(
        builder: (_) => AlarmSoundScreen(
          initialSound: _selectedAlarmSound,
        ),
      ),
    );
    if (result != null && result is AlarmSound) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarm_sound', result.name);
      setState(() {
        _selectedAlarmSound = result;
      });
    }
  }

  Future<void> _testAlarmChime() async {
    try {
      await NotificationService().scheduleReflectionReminder(
        DateTime.now().add(const Duration(seconds: 2)),
        'test-chime',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Test notification chime sent!'),
              ],
            ),
            backgroundColor: const Color(0xFF1B1A19),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send test chime: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final timeFormatted = _scheduleTime.format(context);
    final appState = context.watch<AppState>();
    final isPro = appState.isPro;
    final activeRitualsCount = appState.rituals.where((r) => r.isEnabled).length;

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
                        'Evening Ritual',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: p.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                        ),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        children: [
                          // Section Header
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 10),
                            child: Text(
                              'CONFIGURATION',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: p.onSurfaceVariant,
                              ),
                            ),
                          ),

                          // 2. CONFIGURATION CARDS
                          Container(
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: p.outline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.025),
                                  blurRadius: 14,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Column(
                                children: [
                                  _buildNavigationTile(
                                    icon: Icons.schedule_rounded,
                                    iconColor: p.primary,
                                    iconBg: p.primaryContainer,
                                    title: isPro ? 'Multi-Ritual Schedule & Times' : 'Reflection Schedule & Time',
                                    subtitle: isPro
                                        ? '$activeRitualsCount active sessions · Separate times & cadences'
                                        : '$timeFormatted · ${_getFrequencyLabel(_scheduleFrequency)}',
                                    onTap: _openScheduleScreen,
                                    p: p,
                                  ),
                                  Divider(height: 1, indent: 68, endIndent: 16, color: p.outline),
                                  _buildNavigationTile(
                                    icon: Icons.music_note_rounded,
                                    iconColor: p.secondary,
                                    iconBg: p.secondaryContainer,
                                    title: 'Alarm Sound & Chime',
                                    subtitle: '${_selectedAlarmSound.name} (${_selectedAlarmSound.tag})',
                                    onTap: _openAlarmSoundScreen,
                                    p: p,
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 70.ms, duration: 280.ms),

                          const SizedBox(height: 24),

                          // 3. TEST CHIME BUTTON CARD
                          Container(
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: p.outline),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _testAlarmChime,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: p.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(Icons.notifications_active_rounded, color: p.tertiary, size: 18),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Test Reflection Chime',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: p.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Sends a test notification to verify sounds & banner',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: p.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: p.surfaceVariant,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Test',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: p.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 130.ms, duration: 280.ms),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required DuskColorPalette p,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2.5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: p.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: p.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: p.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
