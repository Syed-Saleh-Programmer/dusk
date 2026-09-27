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

  @override
  void initState() {
    super.initState();
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecording) {
        setState(() => _elapsedSeconds++);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
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
        await _saveAndPop(() => _captureService.captureVoice(resolvedPath, ""));
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
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
                    const Text(
                      'Voice Memo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
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

                      // Large Timer Display
                      Text(
                        _formatDuration(_elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -1.5,
                          fontFeatures: [FontFeature.tabularFigures()],
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
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF767068),
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
                                ? const Color(0xFF2DC48D)
                                : _isRecording
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFFF7A1A),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isSaving
                                        ? const Color(0xFF2DC48D)
                                        : _isRecording
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFFF7A1A))
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
            ],
          ),
        ),
      ),
    );
  }
}
