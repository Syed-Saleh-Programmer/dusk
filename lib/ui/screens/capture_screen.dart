import 'package:flutter/material.dart';
import '../../services/capture_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final TextEditingController _textController = TextEditingController();
  final CaptureService _captureService = CaptureService();

  void _saveDump() async {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      await _captureService.captureText(text);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _saveDump,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'What is lingering on your mind tonight?',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  border: InputBorder.none,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    // TODO: Implement voice capture
                  },
                  icon: const Icon(Icons.mic),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                IconButton(
                  onPressed: () {
                    // TODO: Implement photo capture
                  },
                  icon: const Icon(Icons.camera_alt),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
