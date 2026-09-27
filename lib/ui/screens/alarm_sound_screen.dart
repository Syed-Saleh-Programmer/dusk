import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/alarm_sound.dart';
import '../../services/notification_service.dart';
import '../widgets/dusk_ui_components.dart';

/// Dedicated screen allowing the user to preview and select their preferred alarm sound
/// for the evening reflection ritual.
class AlarmSoundScreen extends StatefulWidget {
  final AlarmSound initialSound;

  const AlarmSoundScreen({
    super.key,
    required this.initialSound,
  });

  @override
  State<AlarmSoundScreen> createState() => _AlarmSoundScreenState();
}

class _AlarmSoundScreenState extends State<AlarmSoundScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  late AlarmSound _selected;
  String? _playingSoundId;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSound;
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingSoundId = null;
        });
      }
    });
  }

  Future<void> _selectAndPreview(AlarmSound sound) async {
    setState(() {
      _selected = sound;
    });
    await _togglePreview(sound, forcePlay: true);
  }

  Future<void> _togglePreview(AlarmSound sound, {bool forcePlay = false}) async {
    try {
      if (!forcePlay && _playingSoundId == sound.id) {
        await _previewPlayer.stop();
        if (mounted) {
          setState(() {
            _playingSoundId = null;
          });
        }
        return;
      }

      await _previewPlayer.stop();
      await _previewPlayer.setReleaseMode(ReleaseMode.stop);
      await _previewPlayer.setVolume(sound.defaultVolume);
      if (mounted) {
        setState(() {
          _playingSoundId = sound.id;
        });
      }
      await _previewPlayer.play(AssetSource(sound.assetPath));
    } catch (e) {
      debugPrint('Error previewing alarm sound: $e');
      if (mounted) {
        setState(() {
          _playingSoundId = null;
        });
      }
    }
  }

  Future<void> _saveAndContinue() async {
    await _previewPlayer.stop();
    await AlarmSound.saveSelected(_selected.id);
    await NotificationService().scheduleNextCadenceReminder();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Alarm sound set to ${_selected.name}'),
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
      Navigator.of(context).pop(_selected);
    }
  }

  @override
  void dispose() {
    _previewPlayer.stop();
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
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
                        text: 'Ritual Tone',
                        variant: DuskBadgeVariant.peach,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                // Title & Subtitle
                const Text(
                  'Choose your alarm sound',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1A19),
                    letterSpacing: -0.5,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08),

                const SizedBox(height: 10),

                const Text(
                  'Tap a tone to preview and set for your evening reflection ritual.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF88827A),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 150.ms, duration: 500.ms).slideY(begin: 0.08),

                const SizedBox(height: 28),

                // Alarm Sound Options
                ...AlarmSound.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sound = entry.value;
                  final isSelected = _selected.id == sound.id;
                  final isPlaying = _playingSoundId == sound.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _selectAndPreview(sound),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFFF8F2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF7A1A)
                                  : const Color(0xFFEFE8DE),
                              width: isSelected ? 2.0 : 1.0,
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
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFDE8D7)
                                      : const Color(0xFFF5F1EA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  sound.icon,
                                  size: 20,
                                  color: isSelected
                                      ? const Color(0xFFFF7A1A)
                                      : const Color(0xFF6E6862),
                                ),
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
                                          sound.name,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: const Color(0xFF1B1A19),
                                          ),
                                        ),
                                        DuskPillBadge(
                                          text: sound.tag,
                                          variant: sound.id == 'calm_horizon'
                                              ? DuskBadgeVariant.peach
                                              : DuskBadgeVariant.neutral,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sound.subtitle,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF88827A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _togglePreview(sound),
                                tooltip: isPlaying ? 'Stop preview' : 'Preview sound',
                                style: IconButton.styleFrom(
                                  backgroundColor: isPlaying
                                      ? const Color(0xFFFF7A1A)
                                      : const Color(0xFFFAF6F0),
                                  minimumSize: const Size(38, 38),
                                  padding: EdgeInsets.zero,
                                ),
                                icon: Icon(
                                  isPlaying
                                      ? Icons.stop_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 20,
                                  color: isPlaying
                                      ? Colors.white
                                      : const Color(0xFF1B1A19),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: (200 + index * 80).ms, duration: 400.ms).slideY(begin: 0.05);
                }),

                const SizedBox(height: 20),

                // Save Button
                DuskPrimaryButton(
                  label: 'Save Alarm Sound',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _saveAndContinue,
                ).animate().fadeIn(delay: 550.ms, duration: 400.ms).slideY(begin: 0.05),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
