import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/capture_service.dart';
import '../../models/dump.dart';
import '../../providers/app_state.dart';
import '../../main.dart';
import '../widgets/dusk_ui_components.dart';
import '../widgets/project_components.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final CaptureService _captureService = CaptureService();
  bool _isSaving = false;
  List<String> _selectedTags = [];
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = context.read<AppState>().activeProjectId;
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

  Future<void> _pickAndSave(ImageSource source) async {
    if (_isSaving) return;

    final appState = context.read<AppState>();
    if (!appState.canCaptureDump) {
      showDuskSnackBar(
        context,
        content: const Text("Daily limit of 20 dumps reached. Upgrade to Pro for unlimited captures."),
        duration: const Duration(seconds: 3),
      );
      Navigator.of(context).push(
        DuskPageRoute.modalSheet(builder: (_) => const PaywallScreen()),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      await _saveAndPop(
        () => _captureService.capturePhoto(
          image.path,
          tags: _selectedTags,
          projectId: _selectedProjectId,
        ),
      );
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
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Capture Moment',
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

              // Fullscreen Prominent Two Options: Camera & Gallery
              Expanded(
                child: _isSaving
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                p.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Saving your moment...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                              cardColor: p.primary,
                              textColor: Colors.white,
                              subtitleColor: Colors.white.withValues(alpha: 0.9),
                              borderColor: p.primary,
                              onTap: () => _pickAndSave(ImageSource.camera),
                            ),

                            const SizedBox(height: 18),

                            // Option 2: Choose from Gallery
                            _buildProminentOption(
                              icon: Icons.photo_library_rounded,
                              title: 'Choose from Gallery',
                              subtitle: 'Select an existing photo from your library as an insight anchor',
                              iconBgColor: p.secondaryContainer,
                              iconColor: p.secondary,
                              cardColor: p.surface,
                              textColor: p.onSurface,
                              subtitleColor: p.onSurfaceVariant,
                              borderColor: p.outline,
                              onTap: () => _pickAndSave(ImageSource.gallery),
                            ),
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
