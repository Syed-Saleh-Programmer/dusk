import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reflection_ritual.dart';
import '../../providers/app_state.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dusk_ui_components.dart';
import 'paywall_screen.dart';

class EditReflectionScheduleScreen extends StatefulWidget {
  const EditReflectionScheduleScreen({super.key});

  @override
  State<EditReflectionScheduleScreen> createState() => _EditReflectionScheduleScreenState();
}

class _EditReflectionScheduleScreenState extends State<EditReflectionScheduleScreen> {
  int _selectedFrequency = 3;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 21, minute: 0);
  List<ReflectionRitual> _rituals = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _frequencies = [
    {
      'label': 'Daily',
      'subtitle': 'Every evening reflection',
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

      if (!mounted) return;

      // Load multi-rituals
      List<ReflectionRitual> loadedRituals = [];
      final appState = context.read<AppState>();
      if (appState.rituals.isNotEmpty) {
        loadedRituals = appState.rituals.map((r) => r.copyWith()).toList();
      } else {
        final raw = prefs.getString('multi_reflection_rituals$suffix');
        if (raw != null && raw.isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(raw);
            loadedRituals = decoded
                .map((e) => ReflectionRitual.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          } catch (_) {}
        } else if (meta['multi_rituals'] is List && (meta['multi_rituals'] as List).isNotEmpty) {
          try {
            loadedRituals = (meta['multi_rituals'] as List)
                .map((e) => ReflectionRitual.fromMap(Map<String, dynamic>.from(e)))
                .toList();
          } catch (_) {}
        }
      }

      if (loadedRituals.isEmpty) {
        loadedRituals = ReflectionRitual.defaultRituals(
          eveningHour: hour,
          eveningMinute: minute,
          eveningCadence: freq,
        );
      }

      if (mounted) {
        setState(() {
          _selectedFrequency = freq;
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
          _rituals = loadedRituals;
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
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1B1A19),
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

  Future<void> _showRitualEditorSheet({ReflectionRitual? ritual, int? index}) async {
    final isEditing = ritual != null && index != null;
    final titleController = TextEditingController(text: ritual?.name ?? '');
    TimeOfDay sheetTime = ritual != null
        ? TimeOfDay(hour: ritual.hour, minute: ritual.minute)
        : const TimeOfDay(hour: 12, minute: 0);
    int sheetCadence = ritual?.cadenceDays ?? 1;
    bool sheetEnabled = ritual?.isEnabled ?? true;

    final presets = [
      {'name': 'Morning Dawn Check-in', 'hour': 8, 'minute': 0, 'cadence': 1},
      {'name': 'Midday Reset', 'hour': 13, 'minute': 0, 'cadence': 1},
      {'name': 'Workday Shutdown', 'hour': 17, 'minute': 30, 'cadence': 1},
      {'name': 'Evening Dusk Synthesis', 'hour': 21, 'minute': 0, 'cadence': 3},
      {'name': 'Late Night Journal', 'hour': 23, 'minute': 0, 'cadence': 1},
      {'name': 'Weekly Retrospective', 'hour': 18, 'minute': 0, 'cadence': 7},
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final timeFormatted = sheetTime.format(context);

            return Container(
              padding: EdgeInsets.fromLTRB(
                22,
                14,
                22,
                MediaQuery.of(context).viewInsets.bottom + 26,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2DED6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEADA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFFF7A1A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Reflection Session' : 'Add Reflection Session',
                                style: const TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B1A19),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Set separate schedule cadence and time',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF88827A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DuskCircleButton(
                          icon: Icons.close_rounded,
                          size: 32,
                          iconSize: 16,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Session Name
                    const Text(
                      'Session Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1A19),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1A19),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., Morning Dawn Check-in',
                        hintStyle: const TextStyle(color: Color(0xFFA59F95), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFEFE8DE)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFEFE8DE)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFFF7A1A), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Preset chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: presets.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {
                                  titleController.text = p['name'] as String;
                                  sheetTime = TimeOfDay(
                                    hour: p['hour'] as int,
                                    minute: p['minute'] as int,
                                  );
                                  sheetCadence = p['cadence'] as int;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F2EB),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE8E2D8)),
                                ),
                                child: Text(
                                  p['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5A544E),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Time Picker Section
                    const Text(
                      'Session Time',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1A19),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: sheetTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: const Color(0xFF1B1A19),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setSheetState(() => sheetTime = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEFE8DE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_filled_rounded, color: Color(0xFFFF7A1A), size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  timeFormatted,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1B1A19),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE8E2D8)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 12, color: Color(0xFFFF7A1A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Change',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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

                    const SizedBox(height: 20),

                    // Schedule Cadence Section
                    const Text(
                      'Schedule Cadence',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1A19),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'label': 'Daily', 'days': 1},
                        {'label': 'Every 2 days', 'days': 2},
                        {'label': 'Every 3 days', 'days': 3},
                        {'label': 'Every 7 days', 'days': 7},
                      ].map((opt) {
                        final isSelected = sheetCadence == opt['days'];
                        return InkWell(
                          onTap: () => setSheetState(() => sheetCadence = opt['days'] as int),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFEADA) : const Color(0xFFFAF7F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFFEFE8DE),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFFFF7A1A)),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  opt['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFFFF7A1A) : const Color(0xFF5A544E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Active Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Session Active',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B1A19),
                          ),
                        ),
                        Switch.adaptive(
                          value: sheetEnabled,
                          activeTrackColor: const Color(0xFFFF7A1A),
                          onChanged: (val) => setSheetState(() => sheetEnabled = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Save Button
                    DuskPrimaryButton(
                      label: isEditing ? 'Save Session' : 'Add Session',
                      icon: Icons.check_rounded,
                      onPressed: () {
                        final name = titleController.text.trim().isEmpty
                            ? (isEditing ? ritual.name : 'Reflection Ritual')
                            : titleController.text.trim();
                        setState(() {
                          if (isEditing) {
                            _rituals[index] = _rituals[index].copyWith(
                              name: name,
                              hour: sheetTime.hour,
                              minute: sheetTime.minute,
                              cadenceDays: sheetCadence,
                              isEnabled: sheetEnabled,
                            );
                            if (_rituals[index].id == 'dusk' || index == 0) {
                              _selectedTime = sheetTime;
                              _selectedFrequency = sheetCadence;
                            }
                          } else {
                            final newId = 'ritual_${DateTime.now().millisecondsSinceEpoch}';
                            _rituals.add(ReflectionRitual(
                              id: newId,
                              name: name,
                              hour: sheetTime.hour,
                              minute: sheetTime.minute,
                              cadenceDays: sheetCadence,
                              isEnabled: sheetEnabled,
                            ));
                          }
                        });
                        Navigator.pop(ctx);
                      },
                    ),

                    if (isEditing && _rituals.length > 1) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _rituals.removeAt(index);
                            });
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFD9534F)),
                          label: const Text(
                            'Delete Session',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD9534F),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveAndContinue() async {
    final appState = context.read<AppState>();
    final isPro = appState.isPro;
    final prefs = await SharedPreferences.getInstance();
    final uid = SupabaseService().currentUser?.id;
    final suffix = (uid != null && uid.isNotEmpty) ? '_$uid' : '';

    if (isPro) {
      await appState.updateRituals(_rituals);

      // Keep legacy fallback values aligned
      final duskRitual = _rituals.firstWhere(
        (r) => r.id == 'dusk',
        orElse: () => _rituals.first,
      );
      await prefs.setInt('reflection_cadence_days$suffix', duskRitual.cadenceDays);
      await prefs.setInt('reflection_reminder_hour$suffix', duskRitual.hour);
      await prefs.setInt('reflection_reminder_minute$suffix', duskRitual.minute);
      await prefs.setInt('schedule_hour', duskRitual.hour);
      await prefs.setInt('schedule_minute', duskRitual.minute);
      await prefs.setInt('schedule_frequency', duskRitual.cadenceDays);

      unawaited(
        SupabaseService().updateUserScheduleSettings(
          cadenceDays: duskRitual.cadenceDays,
          reminderHour: duskRitual.hour,
          reminderMinute: duskRitual.minute,
          multiRituals: _rituals.map((r) => r.toMap()).toList(),
        ),
      );
    } else {
      await prefs.setInt('reflection_cadence_days$suffix', _selectedFrequency);
      await prefs.setInt('reflection_reminder_hour$suffix', _selectedTime.hour);
      await prefs.setInt('reflection_reminder_minute$suffix', _selectedTime.minute);
      await prefs.setInt('schedule_hour', _selectedTime.hour);
      await prefs.setInt('schedule_minute', _selectedTime.minute);
      await prefs.setInt('schedule_frequency', _selectedFrequency);

      if (mounted) {
        appState.updateRitualTime(_selectedTime.hour, _selectedTime.minute);
      }

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
      await NotificationService().scheduleReflectionReminder(scheduledDate, 'setup-cycle');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPro
                      ? 'Multi-ritual schedules and times saved'
                      : 'Reflection schedule updated',
                ),
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

  Widget _buildProRitualItem(ReflectionRitual ritual, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ritual.isEnabled ? const Color(0xFFEFE8DE) : const Color(0xFFF2ECE4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                ritual.isEnabled = !ritual.isEnabled;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                ritual.isEnabled
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: ritual.isEnabled ? AppTheme.primaryColor : const Color(0xFFA59F95),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ritual.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: ritual.isEnabled ? const Color(0xFF1B1A19) : const Color(0xFF88827A),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Time pill
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: ritual.hour, minute: ritual.minute),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: const Color(0xFF1B1A19),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            ritual.hour = picked.hour;
                            ritual.minute = picked.minute;
                            if (ritual.id == 'dusk' || index == 0) {
                              _selectedTime = picked;
                            }
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEADA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFFF7A1A)),
                            const SizedBox(width: 4),
                            Text(
                              ritual.timeFormatted,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF7A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Cadence pill
                    InkWell(
                      onTap: () => _showRitualEditorSheet(ritual: ritual, index: index),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F2EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.repeat_rounded, size: 12, color: Color(0xFF6E6862)),
                            const SizedBox(width: 4),
                            Text(
                              ritual.cadenceLabel,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6E6862),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 19, color: Color(0xFF7A746E)),
            tooltip: 'Edit Schedule & Time',
            onPressed: () => _showRitualEditorSheet(ritual: ritual, index: index),
          ),
          if (_rituals.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFA59F95)),
              tooltip: 'Delete Session',
              onPressed: () {
                setState(() {
                  _rituals.removeAt(index);
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFreeRitualPreviewRow(String title, String time) {
    return Row(
      children: [
        const Icon(
          Icons.radio_button_unchecked_rounded,
          color: Color(0xFFA59F95),
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1A19),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F2EB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E6862),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<AppState>().isPro;

    return Scaffold(
      body: DuskAmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top App Bar row with Back Button
                      Row(
                        children: [
                          DuskCircleButton(
                            icon: Icons.arrow_back_rounded,
                            size: 38,
                            iconSize: 17,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              isPro ? 'Multi-Ritual Scheduling' : 'Reflection Cadence',
                              style: const TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1A19),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (isPro)
                            const DuskPillBadge(
                              text: 'Pro Unlocked',
                              variant: DuskBadgeVariant.peach,
                            ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 20),

                      // Title & Subtitle
                      Text(
                        isPro ? 'Multi-Ritual Reflection Schedule' : 'Tune your reflection cadence',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.4,
                          height: 1.25,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08),

                      const SizedBox(height: 8),

                      Text(
                        isPro
                            ? 'Set separate schedule cadences and times for multiple reflection sessions per day. Add as many as you need.'
                            : 'Adjust how often you\'d like to review your thoughts.',
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF88827A),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 150.ms, duration: 500.ms).slideY(begin: 0.08),

                      const SizedBox(height: 24),

                      // PRO VIEW: Separate schedule & time for each session
                      if (isPro) ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
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
                                      color: const Color(0xFFFFEADA),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFFFF7A1A),
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Daily Reflection Sessions',
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1B1A19),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_rituals.where((r) => r.isEnabled).length} active of ${_rituals.length} · Tap time or schedule to edit',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF88827A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DuskPillBadge(
                                    text: '${_rituals.length} Sessions',
                                    variant: DuskBadgeVariant.neutral,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Ritual items list
                              ..._rituals.asMap().entries.map((entry) {
                                return _buildProRitualItem(entry.value, entry.key);
                              }),

                              const SizedBox(height: 4),

                              // Add Session Button
                              InkWell(
                                onTap: () => _showRitualEditorSheet(),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFF7A1A).withValues(alpha: 0.5),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_circle_outline_rounded, color: Color(0xFFFF7A1A), size: 19),
                                      SizedBox(width: 8),
                                      Text(
                                        'Add Reflection Session',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFFF7A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05),

                        const SizedBox(height: 14),

                        // Helper note for Pro users
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDFBF7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFEFE8DE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF88827A)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Each reflection session fires independently according to its own cadence and time.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF88827A),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      // FREE VIEW: Single reflection session + Pro upgrade teaser
                      ] else ...[
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
                                  color: isSelected ? AppTheme.primarySoftBg : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryColor : const Color(0xFFEFE8DE),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? AppTheme.primaryColor.withValues(alpha: 0.08)
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
                                      color: isSelected ? AppTheme.primaryColor : const Color(0xFFA59F95),
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
                                      color: AppTheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.access_time_filled_rounded,
                                      color: AppTheme.primaryColor,
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
                                    color: AppTheme.backgroundColor,
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
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryColor),
                                            const SizedBox(width: 4),
                                            const Text(
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

                        const SizedBox(height: 20),

                        // Multi-Ritual Teaser Section (Free Users)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF8F4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFFD8B3),
                              width: 1,
                            ),
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
                                      color: const Color(0xFFFFEADA),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFFFF7A1A),
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Multi-Rituals Per Day',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1B1A19),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Dawn, Shutdown & Dusk',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF88827A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const DuskPillBadge(
                                    text: 'Pro',
                                    variant: DuskBadgeVariant.peach,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Free plan includes 1 reflection ritual per day. Upgrade to Dusk Pro to unlock multi-cadence rituals (Morning Dawn, Workday Shutdown, Evening Dusk) with separate schedules and times.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF88827A),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildFreeRitualPreviewRow('Morning Dawn Check-in', '8:00 AM'),
                              const Divider(height: 16, color: Color(0xFFF0EAE1)),
                              _buildFreeRitualPreviewRow('Workday Shutdown', '5:30 PM'),
                              const Divider(height: 16, color: Color(0xFFF0EAE1)),
                              _buildFreeRitualPreviewRow('Evening Dusk Synthesis', _selectedTime.format(context)),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    DuskPageRoute.modalSheet(builder: (_) => const PaywallScreen()),
                                  );
                                },
                                icon: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFF7A1A)),
                                label: const Text(
                                  'Unlock Multi-Rituals with Pro',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF7A1A),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFFF7A1A)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 550.ms, duration: 400.ms).slideY(begin: 0.05),
                      ],

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
