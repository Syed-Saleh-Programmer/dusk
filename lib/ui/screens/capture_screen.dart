import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/capture_service.dart';
import '../../models/dump.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final CaptureService _captureService = CaptureService();
  final TextEditingController _textController = TextEditingController();
  DumpType _currentMode = DumpType.text;
  bool _isRecording = false;
  
  Future<void> _saveTextDump() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    await _captureService.captureText(text);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildTextCapture() {
    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            maxLines: null,
            autofocus: true,
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: const InputDecoration(
              hintText: 'What is on your mind?',
              border: InputBorder.none,
            ),
          ),
        ).animate().fadeIn().slideY(begin: 0.1),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _saveTextDump,
              icon: const Icon(LucideIcons.send),
              label: const Text('Save'),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildVoiceCapture() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onLongPressStart: (_) {
              setState(() => _isRecording = true);
              // TODO: start recording audio
            },
            onLongPressEnd: (_) {
              setState(() => _isRecording = false);
              // TODO: stop recording and save
            },
            child: AnimatedContainer(
              duration: 300.ms,
              width: _isRecording ? 120 : 100,
              height: _isRecording ? 120 : 100,
              decoration: BoxDecoration(
                color: _isRecording 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: _isRecording 
                  ? [BoxShadow(color: Theme.of(context).colorScheme.error.withOpacity(0.5), blurRadius: 20, spreadRadius: 10)]
                  : [],
              ),
              child: Icon(
                LucideIcons.mic,
                size: 48,
                color: _isRecording 
                    ? Theme.of(context).colorScheme.onError
                    : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ).animate(target: _isRecording ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.1,1.1)),
          const SizedBox(height: 32),
          Text(
            _isRecording ? 'Recording...' : 'Hold to record voice',
            style: Theme.of(context).textTheme.titleLarge,
          ).animate(target: _isRecording ? 1 : 0).fadeIn(),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildPhotoCapture() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.camera, size: 64, color: Theme.of(context).colorScheme.primary)
            .animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 16),
          const Text('Photo capture coming soon').animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: implement image picker
            },
            child: const Text('Open Camera'),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Mode Switcher
              SegmentedButton<DumpType>(
                segments: const [
                  ButtonSegment(
                    value: DumpType.text,
                    icon: Icon(LucideIcons.type),
                    label: Text('Text'),
                  ),
                  ButtonSegment(
                    value: DumpType.voice,
                    icon: Icon(LucideIcons.mic),
                    label: Text('Voice'),
                  ),
                  ButtonSegment(
                    value: DumpType.photo,
                    icon: Icon(LucideIcons.camera),
                    label: Text('Photo'),
                  ),
                ],
                selected: {_currentMode},
                onSelectionChanged: (Set<DumpType> selection) {
                  setState(() => _currentMode = selection.first);
                },
              ).animate().fadeIn().slideY(begin: -0.1),
              const SizedBox(height: 32),
              Expanded(
                child: _currentMode == DumpType.text
                    ? _buildTextCapture()
                    : _currentMode == DumpType.voice
                        ? _buildVoiceCapture()
                        : _buildPhotoCapture(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
