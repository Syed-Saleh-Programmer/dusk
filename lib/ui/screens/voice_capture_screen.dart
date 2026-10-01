import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/capture_service.dart';
import '../../models/dump.dart';
import '../../providers/app_state.dart';
import '../../main.dart';
import '../widgets/dusk_ui_components.dart';
import '../widgets/project_components.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

class VoiceCaptureScreen extends StatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  State<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends State<VoiceCaptureScreen> {
  final CaptureService _captureService = CaptureService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSaving = false;
  String? _audioPath;
  int _elapsedSeconds = 0;
  Timer? _timer;
  List<String> _selectedTags = [];
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = context.read<AppState>().activeProjectId;
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsedSeconds = 0;
    final maxSec = context.read<AppState>().maxAudioSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (mounted && _isRecording) {
        setState(() => _elapsedSeconds++);
        if (_elapsedSeconds >= maxSec) {
          _timer?.cancel();
          await _onRecordButtonTap();
          if (mounted) {
            showDuskSnackBar(
              context,
              content: Text(
                maxSec <= 60
                    ? 'Recording ended at 60s limit (Free Tier). Upgrade to Pro for 10-minute voice notes.'
                    : '10-minute maximum recording limit reached.',
              ),
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _saveAndPop(Future<Dump> Function() captureFn) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final dump = await captureFn();
      if (mounted) {
        context.read<AppState>().addDumpLocally(dump);
        Navigator.of(context).pop();
        _scheduleAiSummaryRefresh(dump.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showDuskSnackBar(
          context,
          content: Text('Failed to save: $e'),
          duration: const Duration(milliseconds: 1800),
        );
      }
    }
  }

  void _scheduleAiSummaryRefresh(String dumpId) {
    Future.delayed(const Duration(seconds: 4), () {
      try {
        if (navigatorKey.currentContext != null) {
          final appState = Provider.of<AppState>(
            navigatorKey.currentContext!,
            listen: false,
          );
          appState.refreshDumpAiSummary(dumpId);
        }
      } catch (_) {}
    });
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isSaving) return;
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        if (mounted) {
          setState(() {
            _audioPath = path;
            _isRecording = true;
          });
          _startTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        showDuskSnackBar(
          context,
          content: Text('Could not start recording: $e'),
          duration: const Duration(milliseconds: 1800),
        );
      }
    }
  }

  /// Stopping the recording immediately triggers auto-save and processing.
  Future<void> _onRecordButtonTap() async {
    if (_isSaving) return;

    if (_isRecording) {
      _timer?.cancel();
      final path = await _audioRecorder.stop();
      final resolvedPath = path ?? _audioPath;
      if (mounted) {
        setState(() {
          _isRecording = false;
          if (resolvedPath != null) _audioPath = resolvedPath;
        });
      }
      if (resolvedPath != null) {
        await _saveAndPop(
          () => _captureService.captureVoice(
            resolvedPath,
            "",
            tags: _selectedTags,
            projectId: _selectedProjectId,
          ),
        );
      }
    } else {
      await _startRecording();
    }
  }

  Future<void> _handleBack() async {
    _timer?.cancel();
    if (_isRecording) {
      try {
        await _audioRecorder.stop();
      } catch (_) {}
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final p = AppTheme.of(context);

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DuskCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 40,
                      iconSize: 17,
                      onTap: _handleBack,
                    ),
                    Text(
                      'Voice Memo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: p.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const DuskQuickThemeButton(size: 38, iconSize: 18),
                  ],
                ),
              ),

              // Project Space Selector Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DuskProjectSelectorChip(
                    selectedProjectId: _selectedProjectId,
                    onProjectChanged: (newId) => setState(() => _selectedProjectId = newId),
                  ),
                ),
              ),

              // Full-page Voice Capture UI
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Status Pill Badge
                      DuskPillBadge(
                        text: _isSaving
                            ? 'Saving & Processing...'
                            : _isRecording
                                ? 'Listening'
                                : 'Ready',
                        variant: _isSaving
                            ? DuskBadgeVariant.green
                            : _isRecording
                                ? DuskBadgeVariant.orange
                                : DuskBadgeVariant.neutral,
                        icon: _isSaving
                            ? Icons.sync_rounded
                            : _isRecording
                                ? Icons.graphic_eq_rounded
                                : Icons.mic_none_rounded,
                      ),

                      const SizedBox(height: 24),

                      // Large Timer Display with max limit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatDuration(_elapsedSeconds),
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: p.onSurface,
                              letterSpacing: -1.5,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            ' / ${_formatDuration(appState.maxAudioSeconds)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: p.onSurfaceVariant,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Tier limit indicator pill
                      GestureDetector(
                        onTap: appState.isPro
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  DuskPageRoute.modalSheet(builder: (_) => const PaywallScreen()),
                                );
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: appState.isPro
                                ? p.tertiaryContainer
                                : p.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: appState.isPro
                                  ? p.tertiary.withValues(alpha: 0.5)
                                  : p.primary.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                appState.isPro
                                    ? Icons.auto_awesome_rounded
                                    : Icons.lock_outline_rounded,
                                size: 12,
                                color: appState.isPro
                                    ? p.onTertiaryContainer
                                    : p.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                appState.isPro
                                    ? 'Pro: 10-Minute Voice Notes'
                                    : 'Free: 60s Max (Auto-stops) • Upgrade',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: appState.isPro
                                      ? p.onTertiaryContainer
                                      : p.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        _isSaving
                            ? 'Saving your voice memo and generating insights...'
                            : _isRecording
                                ? 'Speak freely. Tap stop when finished to auto-save.'
                                : 'Tap the microphone to start recording.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: p.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Prominent Record / Stop Button
                      GestureDetector(
                        onTap: _onRecordButtonTap,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _isRecording ? 116 : 100,
                          height: _isRecording ? 116 : 100,
                          decoration: BoxDecoration(
                            color: _isSaving
                                ? p.tertiary
                                : _isRecording
                                    ? const Color(0xFFEF4444)
                                    : p.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isSaving
                                        ? p.tertiary
                                        : _isRecording
                                            ? const Color(0xFFEF4444)
                                            : p.primary)
                                    .withValues(alpha: _isRecording ? 0.42 : 0.28),
                                blurRadius: _isRecording ? 32 : 18,
                                spreadRadius: _isRecording ? 10 : 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _isRecording
                                        ? Icons.stop_rounded
                                        : Icons.mic_rounded,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        _isSaving
                            ? 'Processing...'
                            : _isRecording
                                ? 'Tap to Stop & Save'
                                : 'Tap to Record',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1A19),
                        ),
                      ),

                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),

              // Tag Selector Bar at Bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: DuskTagSelector(
                  availableTags: appState.availableTags,
                  selectedTags: _selectedTags,
                  onChanged: (tags) => setState(() => _selectedTags = tags),
                  onCreateCustomTag: appState.addCustomTag,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
