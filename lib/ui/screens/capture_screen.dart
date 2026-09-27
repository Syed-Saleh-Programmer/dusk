import 'package:flutter/material.dart';
import '../../models/dump.dart';
import 'text_capture_screen.dart';
import 'voice_capture_screen.dart';
import 'photo_capture_screen.dart';

export 'text_capture_screen.dart';
export 'voice_capture_screen.dart';
export 'photo_capture_screen.dart';

class CaptureScreen extends StatelessWidget {
  final DumpType initialMode;

  const CaptureScreen({
    super.key,
    this.initialMode = DumpType.text,
  });

  @override
  Widget build(BuildContext context) {
    switch (initialMode) {
      case DumpType.text:
        return const TextCaptureScreen();
      case DumpType.voice:
        return const VoiceCaptureScreen();
      case DumpType.photo:
        return const PhotoCaptureScreen();
    }
  }
}
