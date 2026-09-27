import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/capture_service.dart';
import '../../models/dump.dart';
import '../../providers/app_state.dart';
import '../../main.dart';
import '../widgets/dusk_ui_components.dart';

class TextCaptureScreen extends StatefulWidget {
  const TextCaptureScreen({super.key});

  @override
  State<TextCaptureScreen> createState() => _TextCaptureScreenState();
}

class _TextCaptureScreenState extends State<TextCaptureScreen> {
  final CaptureService _captureService = CaptureService();
  final TextEditingController _textController = TextEditingController();
  bool _isSaving = false;

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

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a thought')),
      );
      return;
    }
    await _saveAndPop(() => _captureService.captureText(text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      resizeToAvoidBottomInset: true,
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header: Back Button, Title, Save Tick Button
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
                      'New Thought',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.2,
                      ),
                    ),
                    _isSaving
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF7A1A),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Material(
                            color: const Color(0xFFFF7A1A),
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
                                      color: const Color(0xFFFF7A1A).withValues(alpha: 0.28),
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

              // Fullscreen borderless, background-free TextField
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: TextField(
                    controller: _textController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF1B1A19),
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'What is lingering on your mind tonight? Type your thoughts freely...',
                      hintStyle: TextStyle(
                        color: Color(0xFFAFA99E),
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
            ],
          ),
        ),
      ),
    );
  }
}
