import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../providers/app_state.dart';
import '../../services/capture_service.dart';
import '../../services/supabase_service.dart';
import '../widgets/dusk_ui_components.dart';

class QuickShareModal extends StatefulWidget {
  final List<SharedMediaFile> sharedFiles;
  final VoidCallback? onDismissed;

  const QuickShareModal({
    super.key,
    required this.sharedFiles,
    this.onDismissed,
  });

  static Future<void> show(
    BuildContext context,
    List<SharedMediaFile> sharedFiles,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickShareModal(sharedFiles: sharedFiles),
    );
  }

  @override
  State<QuickShareModal> createState() => _QuickShareModalState();
}

class _QuickShareModalState extends State<QuickShareModal> {
  final CaptureService _captureService = CaptureService();
  final TextEditingController _textController = TextEditingController();
  bool _isSaving = false;
  String? _imagePath;
  bool _isImageShare = false;

  @override
  void initState() {
    super.initState();
    _processSharedFiles();
  }

  void _processSharedFiles() {
    if (widget.sharedFiles.isEmpty) return;

    final first = widget.sharedFiles.first;
    if (first.type == SharedMediaType.image) {
      _isImageShare = true;
      _imagePath = first.path;
    } else {
      _isImageShare = false;
      // Text or URL share: combine text from all items
      final texts = widget.sharedFiles
          .map((f) => f.path.trim())
          .where((s) => s.isNotEmpty)
          .join('\n\n');
      _textController.text = texts;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    widget.onDismissed?.call();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final user = SupabaseService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save dumps to Dusk')),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final appState = context.read<AppState>();

      if (_isImageShare && _imagePath != null) {
        final dump = await _captureService.capturePhoto(_imagePath!);
        appState.addDumpLocally(dump);
      } else {
        final content = _textController.text.trim();
        if (content.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot save empty dump')),
          );
          setState(() => _isSaving = false);
          return;
        }
        final dump = await _captureService.captureText(content);
        appState.addDumpLocally(dump);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B1A19),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFFFF7A1A), size: 18),
                SizedBox(width: 10),
                Text(
                  'Captured to your active cycle',
                  style: TextStyle(color: Color(0xFFFAF8F5), fontSize: 14),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save share: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4CEC3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A1A).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isImageShare ? Icons.image_rounded : Icons.share_rounded,
                        color: const Color(0xFFFF7A1A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Quick Capture',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1A19),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Saved into your current reflection cycle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7A756D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                DuskCircleButton(
                  icon: Icons.close_rounded,
                  size: 34,
                  iconSize: 18,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Content preview
            if (_isImageShare && _imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180,
                  color: Colors.black12,
                  child: Image.file(
                    File(_imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8E3D9)),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1B1A19),
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Add context or thoughts to this share...',
                    hintStyle: TextStyle(color: Color(0xFFAFA99E)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B1A19),
                  foregroundColor: const Color(0xFFFAF8F5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_rounded, color: Color(0xFFFF7A1A), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Save to Dusk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
