import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class VoiceReflectionAnswerScreen extends StatefulWidget {
  final String questionText;

  const VoiceReflectionAnswerScreen({
    super.key,
    required this.questionText,
  });

  @override
  State<VoiceReflectionAnswerScreen> createState() => _VoiceReflectionAnswerScreenState();
}

class _VoiceReflectionAnswerScreenState extends State<VoiceReflectionAnswerScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _transcript;
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _audioRecorder.stop();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      // Mock transcript delay
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isProcessing = false;
        _transcript = "This is a mocked transcription of your voice reflection answer. It captures the essence of what you said during the recording.";
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_ans_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
          _transcript = null;
        });
        _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.questionText,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  height: 28 / 24,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_transcript != null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _transcript!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 32),
              ],
              if (_isProcessing)
                Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 24),
                    Text(
                      'Transcribing...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ).animate().fadeIn(),
              if (!_isProcessing && _transcript == null)
                Column(
                  children: [
                    Text(
                      _formatDuration(_recordDuration),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: _isRecording ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w300,
                          ),
                    ),
                    const SizedBox(height: 48),
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording 
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(context).colorScheme.primaryContainer,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 32,
                          color: _isRecording 
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ).animate(target: _isRecording ? 1 : 0)
                       .scale(end: const Offset(1.1, 1.1), duration: 200.ms),
                    ),
                  ],
                ),
              const Spacer(),
              if (_transcript != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _transcript = null;
                            _recordDuration = 0;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(_transcript),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
