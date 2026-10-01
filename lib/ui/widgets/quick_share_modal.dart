import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:record/record.dart';
import '../../models/dump.dart';
import '../../providers/app_state.dart';
import '../../services/capture_service.dart';
import '../../services/supabase_service.dart';
import '../../services/task_service.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/dusk_ui_components.dart';

enum ShareCaptureMode { text, audio, photo }

class QuickShareModal extends StatefulWidget {
  final List<SharedMediaFile> sharedFiles;
  final String? extraText;
  final String? extraSubject;
  final List<Map<String, dynamic>>? nativeSharedFiles;
  final VoidCallback? onDismissed;

  const QuickShareModal({
    super.key,
    required this.sharedFiles,
    this.extraText,
    this.extraSubject,
    this.nativeSharedFiles,
    this.onDismissed,
  });

  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context,
    List<SharedMediaFile> sharedFiles, {
    String? extraText,
    String? extraSubject,
    List<Map<String, dynamic>>? nativeSharedFiles,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => QuickShareModal(
          sharedFiles: sharedFiles,
          extraText: extraText,
          extraSubject: extraSubject,
          nativeSharedFiles: nativeSharedFiles,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<QuickShareModal> createState() => _QuickShareModalState();
}

class _QuickShareModalState extends State<QuickShareModal> {
  static const MethodChannel _shareChannel =
      MethodChannel('com.example.dusk/share_intent');

  static const Set<String> _audioExtensions = {
    '.mp3',
    '.m4a',
    '.wav',
    '.aac',
    '.ogg',
    '.oga',
    '.opus',
    '.flac',
    '.amr',
    '.3gp',
    '.wma',
    '.webm',
    '.mp4',
  };

  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.heic',
    '.heif',
    '.bmp',
  };

  static const Set<String> _textFileExtensions = {
    '.txt',
    '.md',
    '.markdown',
    '.csv',
    '.json',
    '.log',
  };

  final CaptureService _captureService = CaptureService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  ShareCaptureMode _selectedMode = ShareCaptureMode.text;
  final List<String> _audioPaths = [];
  final List<String> _imagePaths = [];
  int _activeImageIndex = 0;

  bool _isSaving = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  List<String> _previewTasks = [];
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updateTaskPreview);
    _noteController.addListener(_updateTaskPreview);
    _processSharedPayload();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _textController.removeListener(_updateTaskPreview);
    _noteController.removeListener(_updateTaskPreview);
    _textController.dispose();
    _noteController.dispose();
    widget.onDismissed?.call();
    super.dispose();
  }

  void _updateTaskPreview() {
    final activeText = _selectedMode == ShareCaptureMode.text
        ? _textController.text
        : _noteController.text;
    final detected = TaskService.extractTasksFromText(activeText);
    if (!mounted) return;
    if (detected.length != _previewTasks.length ||
        detected.join('|') != _previewTasks.join('|')) {
      setState(() {
        _previewTasks = detected;
      });
    }
  }

  bool _isAudioItem(String path, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('audio/') || mime == 'application/ogg') {
      return true;
    }
    final ext = p.extension(path).toLowerCase();
    if (_audioExtensions.contains(ext)) {
      // Only treat .mp4 / .webm as audio if mimeType isn't explicitly video/*
      if ((ext == '.mp4' || ext == '.webm') && mime.startsWith('video/')) {
        return false;
      }
      return true;
    }
    return false;
  }

  bool _isImageItem(String path, String? mimeType, SharedMediaType? type) {
    if (type == SharedMediaType.image) return true;
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/')) return true;
    final ext = p.extension(path).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  bool _isTextFileItem(String path, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    final ext = p.extension(path).toLowerCase();
    if (_textFileExtensions.contains(ext)) return true;
    if (mime.startsWith('text/') && File(path).existsSync()) return true;
    return false;
  }

  String _cleanFilePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.startsWith('file://')) {
      try {
        return Uri.parse(trimmed).toFilePath();
      } catch (_) {}
    }
    return trimmed;
  }

  Future<void> _processSharedPayload() async {
    final textParts = <String>[];
    final subject = widget.extraSubject?.trim() ?? '';
    final extraText = widget.extraText?.trim() ?? '';

    if (subject.isNotEmpty) {
      textParts.add(subject);
    }

    for (final item in widget.sharedFiles) {
      final raw = item.path.trim();
      if (raw.isEmpty) continue;
      final cleanedPath = _cleanFilePath(raw);
      final mime = item.mimeType;

      if (item.type == SharedMediaType.text ||
          item.type == SharedMediaType.url) {
        if (!textParts.contains(raw)) {
          textParts.add(raw);
        }
        continue;
      }

      if (_isAudioItem(cleanedPath, mime)) {
        if (!_audioPaths.contains(cleanedPath)) {
          _audioPaths.add(cleanedPath);
        }
        continue;
      }

      if (_isImageItem(cleanedPath, mime, item.type)) {
        if (!_imagePaths.contains(cleanedPath)) {
          _imagePaths.add(cleanedPath);
        }
        continue;
      }

      if (_isTextFileItem(cleanedPath, mime)) {
        try {
          final fileContent = await File(cleanedPath).readAsString();
          if (fileContent.trim().isNotEmpty &&
              !textParts.contains(fileContent.trim())) {
            textParts.add(fileContent.trim());
          }
        } catch (_) {}
        continue;
      }

      // Check if it's an existing file on disk or plain text fallback
      final file = File(cleanedPath);
      if (await file.exists()) {
        // Fallback: check extension again or treat unknown binary file by mime
        if (_isAudioItem(cleanedPath, mime)) {
          if (!_audioPaths.contains(cleanedPath)) {
            _audioPaths.add(cleanedPath);
          }
        } else if (_isImageItem(cleanedPath, mime, null)) {
          if (!_imagePaths.contains(cleanedPath)) {
            _imagePaths.add(cleanedPath);
          }
        }
      } else if (!textParts.contains(raw)) {
        textParts.add(raw);
      }

      if (item.message != null &&
          item.message!.trim().isNotEmpty &&
          !textParts.contains(item.message!.trim())) {
        textParts.add(item.message!.trim());
      }
    }

    // Also merge any files normalized directly by MainActivity.kt
    if (widget.nativeSharedFiles != null) {
      for (final nativeFile in widget.nativeSharedFiles!) {
        final rawPath = (nativeFile['path'] as String?)?.trim() ?? '';
        final mime = (nativeFile['mimeType'] as String?)?.trim();
        if (rawPath.isEmpty) continue;
        final cleanedPath = _cleanFilePath(rawPath);

        if (_isAudioItem(cleanedPath, mime)) {
          if (!_audioPaths.contains(cleanedPath)) {
            _audioPaths.add(cleanedPath);
          }
        } else if (_isImageItem(cleanedPath, mime, null)) {
          if (!_imagePaths.contains(cleanedPath)) {
            _imagePaths.add(cleanedPath);
          }
        } else if (_isTextFileItem(cleanedPath, mime)) {
          try {
            final content = await File(cleanedPath).readAsString();
            if (content.trim().isNotEmpty &&
                !textParts.contains(content.trim())) {
              textParts.add(content.trim());
            }
          } catch (_) {}
        }
      }
    }

    if (extraText.isNotEmpty && !textParts.contains(extraText)) {
      textParts.add(extraText);
    }

    final combinedText = textParts.join('\n\n').trim();

    if (!mounted) return;
    setState(() {
      if (_audioPaths.isNotEmpty) {
        _selectedMode = ShareCaptureMode.audio;
        if (combinedText.isNotEmpty) {
          _noteController.text = combinedText;
          _textController.text = combinedText;
        }
      } else if (_imagePaths.isNotEmpty) {
        _selectedMode = ShareCaptureMode.photo;
        if (combinedText.isNotEmpty) {
          _noteController.text = combinedText;
          _textController.text = combinedText;
        }
      } else {
        _selectedMode = ShareCaptureMode.text;
        _textController.text = combinedText;
      }
    });
    _updateTaskPreview();
  }

  Future<void> _pickAudioFiles() async {
    try {
      final result = await _shareChannel.invokeMethod<List<dynamic>>('pickAudioFiles');
      if (result == null || result.isEmpty) return;

      final added = <String>[];
      for (final item in result) {
        if (item is Map) {
          final path = (item['path'] as String?)?.trim() ?? '';
          if (path.isNotEmpty && !_audioPaths.contains(path)) {
            added.add(path);
          }
        }
      }
      if (added.isNotEmpty && mounted) {
        setState(() {
          _audioPaths.addAll(added);
          _selectedMode = ShareCaptureMode.audio;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick audio file: $e')),
        );
      }
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      try {
        _recordTimer?.cancel();
        final recordedPath = await _audioRecorder.stop();
        if (mounted) {
          setState(() {
            _isRecording = false;
            _recordSeconds = 0;
            if (recordedPath != null &&
                recordedPath.isNotEmpty &&
                !_audioPaths.contains(recordedPath)) {
              _audioPaths.add(recordedPath);
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isRecording = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to stop recording: $e')),
          );
        }
      }
      return;
    }

    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required')),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final outPath = p.join(
        tempDir.path,
        'share_voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: outPath,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
        });
      }

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecording) {
          setState(() => _recordSeconds++);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _pickGalleryImages() async {
    try {
      final picked = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      if (mounted) {
        setState(() {
          for (final xfile in picked) {
            if (!_imagePaths.contains(xfile.path)) {
              _imagePaths.add(xfile.path);
            }
          }
          _activeImageIndex = _imagePaths.length - 1;
          _selectedMode = ShareCaptureMode.photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick images: $e')),
        );
      }
    }
  }

  Future<void> _takeCameraPhoto() async {
    try {
      final xfile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (xfile == null) return;
      if (mounted) {
        setState(() {
          if (!_imagePaths.contains(xfile.path)) {
            _imagePaths.add(xfile.path);
          }
          _activeImageIndex = _imagePaths.length - 1;
          _selectedMode = ShareCaptureMode.photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not take photo: $e')),
        );
      }
    }
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final clip = data?.text?.trim() ?? '';
    if (clip.isEmpty) return;
    setState(() {
      if (_textController.text.trim().isEmpty) {
        _textController.text = clip;
      } else {
        _textController.text = '${_textController.text.trim()}\n\n$clip';
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    if (_isRecording) {
      await _toggleVoiceRecording();
    }
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final appState = context.read<AppState>();

    final user = SupabaseService().currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please log in to save dumps to Dusk')),
      );
      navigator.pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final createdDumps = <Dump>[];

      if (_selectedMode == ShareCaptureMode.text) {
        final content = _textController.text.trim();
        if (content.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Please enter or paste some text to save')),
          );
          setState(() => _isSaving = false);
          return;
        }
        final dump = await _captureService.captureText(
          content,
          tags: _selectedTags,
        );
        appState.addDumpLocally(dump);
        createdDumps.add(dump);
      } else if (_selectedMode == ShareCaptureMode.audio) {
        if (_audioPaths.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Please attach an audio file or record a voice note'),
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
        final note = _noteController.text.trim();
        for (int i = 0; i < _audioPaths.length; i++) {
          final audioPath = _audioPaths[i];
          // Attach the user's note to the first audio dump (or all if single)
          final dumpNote = (i == 0 && note.isNotEmpty) ? note : null;
          final dump = await _captureService.captureVoice(
            audioPath,
            '',
            content: dumpNote,
            tags: _selectedTags,
          );
          appState.addDumpLocally(dump);
          createdDumps.add(dump);
        }
      } else if (_selectedMode == ShareCaptureMode.photo) {
        if (_imagePaths.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Please select or take at least one photo'),
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
        final caption = _noteController.text.trim();
        for (int i = 0; i < _imagePaths.length; i++) {
          final imagePath = _imagePaths[i];
          final dumpCaption = (i == 0 && caption.isNotEmpty) ? caption : null;
          final dump = await _captureService.capturePhoto(
            imagePath,
            content: dumpCaption,
            tags: _selectedTags,
          );
          appState.addDumpLocally(dump);
          createdDumps.add(dump);
        }
      }

      // Schedule background refresh of tasks & dumps after AI summary / task extraction completes
      Future.delayed(const Duration(seconds: 4), () {
        for (final d in createdDumps) {
          appState.refreshDumpAiSummary(d.id);
        }
        appState.loadTasksFromLocalDb();
      });
      Future.delayed(const Duration(seconds: 9), () {
        for (final d in createdDumps) {
          appState.refreshDumpAiSummary(d.id);
        }
        appState.loadTasksFromLocalDb();
      });

      if (mounted) {
        navigator.pop();
        final count = createdDumps.length;
        final typeLabel = _selectedMode == ShareCaptureMode.audio
            ? (count > 1 ? '$count audio dumps' : 'Audio dump')
            : _selectedMode == ShareCaptureMode.photo
                ? (count > 1 ? '$count photo dumps' : 'Photo dump')
                : 'Thought dump';
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B1A19),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFF7A1A),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$typeLabel saved • Summarizing & extracting tasks...',
                    style: const TextStyle(
                      color: Color(0xFFFAF8F5),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to save share: $e')),
        );
      }
    }
  }

  String _formatFileSize(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return '';
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      final kb = bytes / 1024;
      if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
      final mb = kb / 1024;
      return '${mb.toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String? _extractFirstUrl(String text) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(text);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxModalHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxModalHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(22, 14, 22, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A1A).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedMode == ShareCaptureMode.audio
                              ? Icons.graphic_eq_rounded
                              : _selectedMode == ShareCaptureMode.photo
                                  ? Icons.photo_library_rounded
                                  : Icons.notes_rounded,
                          color: const Color(0xFFFF7A1A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share to Dusk',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1A19),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Stored as dump • AI summary & task extraction',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A756D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DuskCircleButton(
                  icon: Icons.close_rounded,
                  size: 34,
                  iconSize: 18,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3-Mode Segmented Selector (Text / Audio / Photo)
            _buildModeSelector(),
            const SizedBox(height: 16),

            // Scrollable Mode Body
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedMode == ShareCaptureMode.text)
                      _buildTextModeContent()
                    else if (_selectedMode == ShareCaptureMode.audio)
                      _buildAudioModeContent()
                    else
                      _buildPhotoModeContent(),

                    const SizedBox(height: 14),
                    Builder(
                      builder: (context) {
                        final appState = context.watch<AppState>();
                        return DuskTagSelector(
                          label: 'Tags',
                          availableTags: appState.availableTags,
                          selectedTags: _selectedTags,
                          onChanged: (tags) =>
                              setState(() => _selectedTags = tags),
                          onCreateCustomTag: appState.addCustomTag,
                        );
                      },
                    ),

                    // Live Task Detection & AI Pipeline Badge
                    const SizedBox(height: 12),
                    _buildPipelineAndTaskFooter(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Primary Save Action Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B1A19),
                  foregroundColor: const Color(0xFFFAF8F5),
                  disabledBackgroundColor:
                      const Color(0xFF1B1A19).withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Saving & Processing...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFFFF7A1A),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getSaveButtonLabel(),
                            style: const TextStyle(
                              fontSize: 15.5,
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

  String _getSaveButtonLabel() {
    switch (_selectedMode) {
      case ShareCaptureMode.text:
        return 'Save Thought Dump';
      case ShareCaptureMode.audio:
        if (_audioPaths.length > 1) {
          return 'Save ${_audioPaths.length} Audio Dumps';
        }
        return 'Save Audio Dump';
      case ShareCaptureMode.photo:
        if (_imagePaths.length > 1) {
          return 'Save ${_imagePaths.length} Photo Dumps';
        }
        return 'Save Photo Dump';
    }
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8DF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildModeTab(
            mode: ShareCaptureMode.text,
            icon: Icons.notes_rounded,
            label: 'Text',
            badgeCount: 0,
          ),
          _buildModeTab(
            mode: ShareCaptureMode.audio,
            icon: Icons.graphic_eq_rounded,
            label: 'Audio',
            badgeCount: _audioPaths.length,
          ),
          _buildModeTab(
            mode: ShareCaptureMode.photo,
            icon: Icons.image_rounded,
            label: 'Photo',
            badgeCount: _imagePaths.length,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required ShareCaptureMode mode,
    required IconData icon,
    required String label,
    required int badgeCount,
  }) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            // Sync text <-> note if user switches modes and one of them is empty
            if (_selectedMode == ShareCaptureMode.text &&
                mode != ShareCaptureMode.text &&
                _noteController.text.trim().isEmpty &&
                _textController.text.trim().isNotEmpty) {
              _noteController.text = _textController.text;
            } else if (_selectedMode != ShareCaptureMode.text &&
                mode == ShareCaptureMode.text &&
                _textController.text.trim().isEmpty &&
                _noteController.text.trim().isNotEmpty) {
              _textController.text = _noteController.text;
            }
            _selectedMode = mode;
          });
          _updateTaskPreview();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? const Color(0xFFFF7A1A)
                    : const Color(0xFF7A756D),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF1B1A19)
                      : const Color(0xFF7A756D),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF7A1A)
                        : const Color(0xFFD4CEC3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF1B1A19),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. TEXT MODE UI
  // ==========================================
  Widget _buildTextModeContent() {
    final detectedUrl = _extractFirstUrl(_textController.text);
    Uri? parsedUri;
    if (detectedUrl != null) {
      parsedUri = Uri.tryParse(detectedUrl);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parsedUri != null && parsedUri.host.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7A1A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF7A1A).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: Color(0xFFFF7A1A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shared link from ${parsedUri.host}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1A19),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          constraints: const BoxConstraints(minHeight: 130, maxHeight: 220),
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
              hintText:
                  'Write or edit shared text, links, or tasks (e.g. "Todo: call Alex tomorrow")...',
              hintStyle: TextStyle(color: Color(0xFFAFA99E), fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildMiniActionButton(
              icon: Icons.content_paste_rounded,
              label: 'Paste Clipboard',
              onTap: _pasteClipboard,
            ),
            const SizedBox(width: 8),
            if (_textController.text.isNotEmpty)
              _buildMiniActionButton(
                icon: Icons.clear_rounded,
                label: 'Clear',
                onTap: () => setState(() => _textController.clear()),
              ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 2. AUDIO MODE UI
  // ==========================================
  Widget _buildAudioModeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_audioPaths.isEmpty && !_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E3D9)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.audio_file_rounded,
                    color: Color(0xFFFF7A1A),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Share or record an audio note',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1A19),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Supports voice notes (.m4a, .mp3, .ogg, .opus, .wav) with AI Whisper transcription',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A756D),
                  ),
                ),
              ],
            ),
          ),

        // Active Recording Banner
        if (_isRecording)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF7A1A).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recording voice note... ${_formatDuration(_recordSeconds)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A19),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _toggleVoiceRecording,
                  icon: const Icon(Icons.stop_circle_rounded, size: 18),
                  label: const Text('Stop'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
          ),

        // Attached Audio File Cards + Preview Player
        ..._audioPaths.asMap().entries.map((entry) {
          final idx = entry.key;
          final path = entry.value;
          final fileName = p.basename(path);
          final ext = p
              .extension(path)
              .replaceFirst('.', '')
              .toUpperCase();
          final sizeLabel = _formatFileSize(path);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E3D9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A1A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ext.isEmpty ? 'AUDIO' : ext,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF7A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1A19),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sizeLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        sizeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8C867B),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _audioPaths.removeAt(idx);
                        });
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF8C867B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AudioPlayerWidget(
                  key: ValueKey(path),
                  audioUrl: path,
                ),
              ],
            ),
          );
        }),

        // Audio Picker / Recorder Action Row
        Row(
          children: [
            Expanded(
              child: _buildMiniActionButton(
                icon: Icons.folder_open_rounded,
                label: 'Pick Audio File',
                onTap: _pickAudioFiles,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniActionButton(
                icon: _isRecording
                    ? Icons.stop_rounded
                    : Icons.mic_none_rounded,
                label: _isRecording ? 'Stop Recording' : 'Record Voice',
                onTap: _toggleVoiceRecording,
                isActive: _isRecording,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Optional Note / Context for Audio Dump
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E3D9)),
          ),
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1B1A19),
              height: 1.4,
            ),
            decoration: const InputDecoration(
              hintText: 'Add a note or tasks for this audio (optional)...',
              hintStyle: TextStyle(color: Color(0xFFAFA99E), fontSize: 13.5),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. PHOTO / IMAGES MODE UI
  // ==========================================
  Widget _buildPhotoModeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_imagePaths.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E3D9)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Color(0xFFFF7A1A),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Share or select photos & screenshots',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1A19),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gemini Vision extracts text, notes, and actionable tasks from your images',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A756D),
                  ),
                ),
              ],
            ),
          )
        else ...[
          SizedBox(
            height: 185,
            child: PageView.builder(
              itemCount: _imagePaths.length,
              onPageChanged: (idx) => setState(() => _activeImageIndex = idx),
              itemBuilder: (context, index) {
                final path = _imagePaths[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: const Color(0xFFEDE8DF),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Image counter pill
                    if (_imagePaths.length > 1)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${index + 1} / ${_imagePaths.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    // Remove photo button
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _imagePaths.removeAt(index);
                            if (_activeImageIndex >= _imagePaths.length &&
                                _imagePaths.isNotEmpty) {
                              _activeImageIndex = _imagePaths.length - 1;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Gallery / Camera Picker Action Row
        Row(
          children: [
            Expanded(
              child: _buildMiniActionButton(
                icon: Icons.photo_library_outlined,
                label: 'Add from Gallery',
                onTap: _pickGalleryImages,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniActionButton(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                onTap: _takeCameraPhoto,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Optional Caption / Context for Photo Dump
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E3D9)),
          ),
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1B1A19),
              height: 1.4,
            ),
            decoration: const InputDecoration(
              hintText: 'Add a caption, context, or tasks for this photo...',
              hintStyle: TextStyle(color: Color(0xFFAFA99E), fontSize: 13.5),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF7A1A).withValues(alpha: 0.14)
              : const Color(0xFFEDE8DF).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFF7A1A)
                : const Color(0xFFE0D9CD),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? const Color(0xFFFF7A1A)
                  : const Color(0xFF1B1A19),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFFFF7A1A)
                      : const Color(0xFF1B1A19),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineAndTaskFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_previewTasks.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF389F7F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF389F7F).withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.task_alt_rounded,
                  size: 16,
                  color: Color(0xFF389F7F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _previewTasks.length == 1
                        ? '1 task detected: "${_previewTasks.first}"'
                        : '${_previewTasks.length} tasks detected & will be added to Tasks',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF236B54),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE8DF).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: Color(0xFFFF7A1A),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _selectedMode == ShareCaptureMode.audio
                      ? 'Audio is transcribed, summarized by AI & scanned for tasks'
                      : _selectedMode == ShareCaptureMode.photo
                          ? 'Photo is analyzed by AI for text, summary & actionable tasks'
                          : 'Text is summarized by AI & actionable tasks are extracted',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6E6960),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
