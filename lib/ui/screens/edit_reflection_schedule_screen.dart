import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../widgets/dusk_ui_components.dart';

class EditReflectionScheduleScreen extends StatefulWidget {
  const EditReflectionScheduleScreen({super.key});

  @override
  State<EditReflectionScheduleScreen> createState() => _EditReflectionScheduleScreenState();
}

class _EditReflectionScheduleScreenState extends State<EditReflectionScheduleScreen> {
  int _selectedFrequency = 3;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 21, minute: 0);
  bool _isLoading = true;

  final List<Map<String, dynamic>> _frequencies = [
    {
      'label': 'Daily',
      'subtitle': 'Every evening reflection ritual',
      'value': 1,
      'isRecommended': false,
    },
    {
      'label': 'Every 2 days',
      'subtitle': 'Review every other evening',
      'value': 2,
      'isRecommended': false,
    },
    {
      'label': 'Every 3 days',
      'subtitle': 'Balanced cadence for mindful insights',
      'value': 3,
      'isRecommended': true,
    },
    {
      'label': 'Every 7 days',
      'subtitle': 'Weekly contemplative wrap-up',
      'value': 7,
      'isRecommended': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = SupabaseService().currentUser;
      final uid = user?.id;
      final meta = user?.userMetadata ?? {};
      final suffix = (uid != null && uid.isNotEmpty) ? '_$uid' : '';
      final freq = prefs.getInt('reflection_cadence_days$suffix') ??
          (meta['reflection_cadence_days'] as int?) ??
          3;
      final hour = prefs.getInt('reflection_reminder_hour$suffix') ??
          (meta['reflection_reminder_hour'] as int?) ??
          21;
      final minute = prefs.getInt('reflection_reminder_minute$suffix') ??
          (meta['reflection_reminder_minute'] as int?) ??
          0;
      if (mounted) {
        setState(() {
          _selectedFrequency = freq;
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF7A1A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1B1A19),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = SupabaseService().currentUser?.id;
    final suffix = (uid != null && uid.isNotEmpty) ? '_$uid' : '';
    await prefs.setInt('reflection_cadence_days$suffix', _selectedFrequency);
    await prefs.setInt('reflection_reminder_hour$suffix', _selectedTime.hour);
    await prefs.setInt('reflection_reminder_minute$suffix', _selectedTime.minute);
    unawaited(
      SupabaseService().updateUserScheduleSettings(
        cadenceDays: _selectedFrequency,
        reminderHour: _selectedTime.hour,
        reminderMinute: _selectedTime.minute,
      ),
    );

    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Schedule notification
    await NotificationService().scheduleReflectionReminder(scheduledDate, 'setup-cycle');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Reflection schedule updated'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B1A19),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DuskAmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A1A)),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top App Bar row with Dusk Circle Back Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          DuskCircleButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const Flexible(
                            child: DuskPillBadge(
                              text: 'Cadence',
                              variant: DuskBadgeVariant.peach,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 24),

                      // Title & Subtitle
                      Text(
                        'Tune your reflection cadence',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.5,
                          height: 1.25,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08),

                      const SizedBox(height: 10),

                      Text(
                        'Adjust how often you\'d like to review your thoughts.',
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF88827A),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 150.ms, duration: 500.ms).slideY(begin: 0.08),

                      const SizedBox(height: 28),

                      // Frequency Options
                      ..._frequencies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final freq = entry.value;
                        final isSelected = _selectedFrequency == freq['value'];
                        final isRecommended = freq['isRecommended'] as bool;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            onTap: () => setState(() => _selectedFrequency = freq['value'] as int),
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF8F2) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFFEFE8DE),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? const Color(0xFFFF7A1A).withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFFA59F95),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              freq['label'] as String,
                                              style: TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                color: const Color(0xFF1B1A19),
                                              ),
                                            ),
                                            if (isRecommended)
                                              const DuskPillBadge(
                                                text: 'Recommended',
                                                variant: DuskBadgeVariant.peach,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          freq['subtitle'] as String,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF88827A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: (200 + index * 80).ms, duration: 400.ms).slideY(begin: 0.05);
                      }),

                      const SizedBox(height: 20),

                      // Time Picker Section
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDE8D7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.access_time_filled_rounded,
                                    color: Color(0xFFFF7A1A),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'At what time?',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1B1A19),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Evening reflection alert',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF88827A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF6F0),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFEFE8DE)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _selectedTime.format(context),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1B1A19),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFE8E2D8)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_outlined, size: 14, color: Color(0xFFFF7A1A)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Change',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1B1A19),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(begin: 0.05),

                      const SizedBox(height: 28),

                      // Save Button
                      DuskPrimaryButton(
                        label: 'Save Settings',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: _saveAndContinue,
                      ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(begin: 0.05),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
