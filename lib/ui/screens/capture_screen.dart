import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  DumpType _currentMode = DumpType.text;
  bool _isRecording = false;
  String? _audioPath;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }
  
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
              icon: Icon(LucideIcons.send),
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
            onLongPressStart: (_) async {
              if (await _audioRecorder.hasPermission()) {
                final dir = await getTemporaryDirectory();
                _audioPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
                await _audioRecorder.start(const RecordConfig(), path: _audioPath!);
                setState(() => _isRecording = true);
              }
            },
            onLongPressEnd: (_) async {
              if (_isRecording) {
                await _audioRecorder.stop();
                setState(() => _isRecording = false);
                if (_audioPath != null) {
                  await _captureService.captureVoice(_audioPath!, "");
                  if (mounted) Navigator.of(context).pop();
                }
              }
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
                  ? [BoxShadow(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 10)]
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
          const Text('Capture a moment').animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.camera);
              if (image != null) {
                await _captureService.capturePhoto(image.path);
                if (mounted) Navigator.of(context).pop();
              }
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
