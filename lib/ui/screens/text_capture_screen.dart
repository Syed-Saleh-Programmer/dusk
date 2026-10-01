import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/capture_service.dart';
import '../../models/dump.dart';
import '../../providers/app_state.dart';
import '../../main.dart';
import '../widgets/dusk_ui_components.dart';
import '../widgets/project_components.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

class TextCaptureScreen extends StatefulWidget {
  const TextCaptureScreen({super.key});

  @override
  State<TextCaptureScreen> createState() => _TextCaptureScreenState();
}

class _TextCaptureScreenState extends State<TextCaptureScreen> {
  final CaptureService _captureService = CaptureService();
  final TextEditingController _textController = TextEditingController();
  bool _isSaving = false;
  List<String> _selectedTags = [];
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = context.read<AppState>().activeProjectId;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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

  Future<void> _handleSave() async {
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

    final text = _textController.text.trim();
    if (text.isEmpty) {
      showDuskSnackBar(
        context,
        content: const Text('Please write a thought'),
        duration: const Duration(milliseconds: 1800),
      );
      return;
    }
    await _saveAndPop(
      () => _captureService.captureText(
        text,
        tags: _selectedTags,
        projectId: _selectedProjectId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      resizeToAvoidBottomInset: true,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header: Back Button, Title, Theme Switcher & Save Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    DuskCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 40,
                      iconSize: 17,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'New Thought',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: p.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const DuskQuickThemeButton(size: 38, iconSize: 18),
                    const SizedBox(width: 10),
                    _isSaving
                        ? SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    p.primary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Material(
                            color: p.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _handleSave,
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: p.primary.withValues(alpha: 0.28),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 21,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
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

              // Fullscreen borderless, background-free TextField
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: TextField(
                    controller: _textController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      fontSize: 18,
                      color: p.onSurface,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What is lingering on your mind tonight? Type your thoughts freely...',
                      hintStyle: TextStyle(
                        color: p.onSurfaceVariant,
                        fontSize: 18,
                        height: 1.6,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                  ),
                ),
              ),

              // Tag Selector Bar at Bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
