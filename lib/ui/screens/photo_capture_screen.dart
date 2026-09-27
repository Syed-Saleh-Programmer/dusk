import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/capture_service.dart';
import '../../models/dump.dart';
import '../../providers/app_state.dart';
import '../../main.dart';
import '../widgets/dusk_ui_components.dart';

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final CaptureService _captureService = CaptureService();
  bool _isSaving = false;

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

  Future<void> _pickAndSave(ImageSource source) async {
    if (_isSaving) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      await _saveAndPop(() => _captureService.capturePhoto(image.path));
    }
  }

  Widget _buildProminentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 38,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Capture Moment',
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

              // Fullscreen Prominent Two Options: Camera & Gallery
              Expanded(
                child: _isSaving
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF7A1A),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Saving your moment...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF767068),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Option 1: Take Photo with Camera
                            _buildProminentOption(
                              icon: Icons.camera_alt_rounded,
                              title: 'Take a Photo',
                              subtitle: 'Use your camera to capture a visual moment right now',
                              iconBgColor: Colors.white.withValues(alpha: 0.22),
                              iconColor: Colors.white,
                              cardColor: const Color(0xFFFF7A1A),
                              textColor: Colors.white,
                              subtitleColor: Colors.white.withValues(alpha: 0.9),
                              borderColor: const Color(0xFFFF7A1A),
                              onTap: () => _pickAndSave(ImageSource.camera),
                            ),

                            const SizedBox(height: 18),

                            // Option 2: Choose from Gallery
                            _buildProminentOption(
                              icon: Icons.photo_library_rounded,
                              title: 'Choose from Gallery',
                              subtitle: 'Select an existing photo from your library as an insight anchor',
                              iconBgColor: const Color(0xFFFDE8D7),
                              iconColor: const Color(0xFFFF7A1A),
                              cardColor: Colors.white,
                              textColor: const Color(0xFF1B1A19),
                              subtitleColor: const Color(0xFF767068),
                              borderColor: const Color(0xFFECE7DE),
                              onTap: () => _pickAndSave(ImageSource.gallery),
                            ),
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
