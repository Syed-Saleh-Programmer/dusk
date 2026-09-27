import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Represents an available alarm sound option for the reflection ritual.
class AlarmSound {
  static const String prefsKey = 'selected_alarm_sound_id';

  static String _scopedPrefsKey() {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        return '${prefsKey}_$uid';
      }
    } catch (_) {}
    return prefsKey;
  }

  final String id;
  final String name;
  final String subtitle;
  final String tag;
  final String assetPath; // Relative to assets/ for AudioPlayer AssetSource
  final String rawResourceName; // Android res/raw filename without extension
  final double defaultVolume;
  final IconData icon;

  const AlarmSound({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.tag,
    required this.assetPath,
    required this.rawResourceName,
    required this.defaultVolume,
    required this.icon,
  });

  String get channelId => 'dusk_alarm_v3_$id';

  static const AlarmSound calmHorizon = AlarmSound(
    id: 'calm_horizon',
    name: 'Calm Horizon',
    subtitle: 'Subtle warm ambient chord & soft chime',
    tag: 'Subtle & Calming',
    assetPath: 'sounds/calm_horizon.wav',
    rawResourceName: 'calm_horizon',
    defaultVolume: 0.85,
    icon: Icons.wb_twilight_rounded,
  );

  static const AlarmSound singingBowl = AlarmSound(
    id: 'singing_bowl',
    name: 'Sanctuary Bowl',
    subtitle: 'Deep, meditative singing bowl resonance',
    tag: 'Meditative',
    assetPath: 'sounds/singing_bowl.wav',
    rawResourceName: 'singing_bowl',
    defaultVolume: 0.85,
    icon: Icons.self_improvement_rounded,
  );

  static const AlarmSound eveningChime = AlarmSound(
    id: 'evening_chime',
    name: 'Evening Breeze',
    subtitle: 'Gentle acoustic pentatonic dusk notes',
    tag: 'Gentle',
    assetPath: 'sounds/evening_chime.wav',
    rawResourceName: 'evening_chime',
    defaultVolume: 0.85,
    icon: Icons.air_rounded,
  );

  static const AlarmSound reflectionBell = AlarmSound(
    id: 'reflection_bell',
    name: 'Reflection Bell',
    subtitle: 'Clear, resonant temple reminder bell',
    tag: 'Classic',
    assetPath: 'sounds/reflection_bell.ogg',
    rawResourceName: 'reflection_bell',
    defaultVolume: 1.0,
    icon: Icons.notifications_none_rounded,
  );

  static const List<AlarmSound> values = [
    calmHorizon,
    singingBowl,
    eveningChime,
    reflectionBell,
  ];

  static AlarmSound fromId(String? id) {
    if (id == null) return calmHorizon;
    for (final sound in values) {
      if (sound.id == id) return sound;
    }
    return calmHorizon;
  }

  static Future<AlarmSound> loadSelected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _scopedPrefsKey();
      String? savedId = prefs.getString(key);
      if (savedId == null || savedId.isEmpty) {
        final metaSound = Supabase
            .instance
            .client
            .auth
            .currentUser
            ?.userMetadata?['selected_alarm_sound_id']
            ?.toString();
        if (metaSound != null && metaSound.isNotEmpty) {
          savedId = metaSound;
          await prefs.setString(key, metaSound);
        }
      }
      return fromId(savedId);
    } catch (_) {
      return calmHorizon;
    }
  }

  static Future<void> saveSelected(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedPrefsKey(), id);
    unawaited(SupabaseService().updateUserScheduleSettings(alarmSoundId: id));
  }
}
