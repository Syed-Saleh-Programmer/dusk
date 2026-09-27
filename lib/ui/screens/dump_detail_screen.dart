import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../widgets/audio_player_widget.dart';
import '../../services/supabase_service.dart';
import '../../services/local_db_service.dart';
import '../../services/capture_service.dart';
import '../../services/task_service.dart';
import '../../providers/app_state.dart';
import 'tasks_screen.dart';

class DumpDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dump;

  const DumpDetailScreen({super.key, required this.dump});

  @override
  State<DumpDetailScreen> createState() => _DumpDetailScreenState();
}

class _DumpDetailScreenState extends State<DumpDetailScreen> {
  late Map<String, dynamic> _dump;
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    _dump = Map<String, dynamic>.from(widget.dump);
    final dumpId = _dump['id']?.toString() ?? '';
    if (CaptureService().isProcessing(dumpId) || _dump['is_processing'] == true) {
      // CaptureService is already syncing & summarizing in the background; AppState listener will update us immediately
      _isLoadingSummary = true;
    } else if (_dump['ai_summary'] == null ||
        (_dump['ai_summary'] as String?)?.trim().isEmpty == true ||
        ((_dump['type'] == 'voice' || _dump['type'] == 'photo') &&
            (_dump['transcript'] == null || (_dump['transcript'] as String?)?.trim().isEmpty == true))) {
      _tryLoadAiSummary();
    }
  }

  Future<void> _tryLoadAiSummary() async {
    final dumpId = _dump['id'] as String?;
    if (dumpId == null) return;

    setState(() => _isLoadingSummary = true);

    // 1. Check local DB
    try {
      final localDump = await LocalDbService().getDumpById(dumpId);
      if (localDump != null) {
        if (localDump.transcript != null && localDump.transcript!.trim().isNotEmpty) {
          _dump['transcript'] = localDump.transcript;
        }
        if (localDump.title != null && localDump.title!.trim().isNotEmpty) {
          _dump['title'] = localDump.title;
          _dump['category'] = localDump.title;
        }
        if (localDump.aiSummary != null && localDump.aiSummary!.trim().isNotEmpty) {
          if (mounted) {
            setState(() {
              _dump['ai_summary'] = localDump.aiSummary;
              _isLoadingSummary = false;
            });
            _notifyAppState(dumpId, localDump.aiSummary!, title: localDump.title);
          }
          return;
        }
      }
    } catch (_) {}

    // 2. Check remote Supabase DB
    try {
      final remoteDump = await SupabaseService().getDumpById(dumpId);
      if (remoteDump != null) {
        if (remoteDump['transcript'] != null) {
          _dump['transcript'] = remoteDump['transcript'];
        }
        if (remoteDump['title'] != null) {
          _dump['title'] = remoteDump['title'];
          _dump['category'] = remoteDump['title'];
        }
        final summary = remoteDump['ai_summary'] as String?;
        if (summary != null && summary.trim().isNotEmpty) {
          await LocalDbService().updateDumpAiSummary(dumpId, summary, title: remoteDump['title']);
          if (mounted) {
            setState(() {
              _dump['ai_summary'] = summary;
              _isLoadingSummary = false;
            });
            _notifyAppState(dumpId, summary, title: remoteDump['title']);
          }
          return;
        }
      }
    } catch (_) {}

    // 3. For text dumps, generate the AI summary directly if still missing
    if (_dump['type'] == 'text') {
      await _generateAiSummary();
    } else {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _generateAiSummary() async {
    final dumpId = _dump['id'] as String?;
    final userId = _dump['user_id'] as String? ?? SupabaseService().currentUser?.id;
    if (dumpId == null || userId == null) {
      if (mounted) setState(() => _isLoadingSummary = false);
      return;
    }

    final content = (_dump['type'] == 'text')
        ? (_dump['content'] as String?)
        : (_dump['transcript'] as String? ?? _dump['content'] as String?);

    if (content == null || content.trim().isEmpty) {
      if (mounted) setState(() => _isLoadingSummary = false);
      return;
    }

    if (mounted) setState(() => _isLoadingSummary = true);

    try {
      final type = _dump['type'] as String? ?? 'text';

      final result = await SupabaseService().generateDumpSummaryAndTitle(
        dumpId,
        userId,
        content: content,
        type: type,
      );

      if (result != null) {
        final summary = result['summary'];
        final title = result['title'];
        final aiTasks = TaskService.parseTaskStrings(result['tasks_json']);
        final capturedAt = DateTime.tryParse(
              (_dump['captured_at'] ?? _dump['created_at'])?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();
        await TaskService().extractAndSaveTasksForDump(
          dumpId: dumpId,
          userId: userId,
          capturedAt: capturedAt,
          dumpTitle: title ?? _getDetailTitle(),
          content: _dump['content']?.toString(),
          transcript: _dump['transcript']?.toString(),
          aiSummary: summary,
          aiTasks: aiTasks,
        );
        if (summary != null && summary.trim().isNotEmpty) {
          await LocalDbService().updateDumpAiSummary(dumpId, summary, title: title);
          if (mounted) {
            setState(() {
              _dump['ai_summary'] = summary;
              if (title != null) {
                _dump['title'] = title;
                _dump['category'] = title;
              }
              _isLoadingSummary = false;
            });
            _notifyAppState(dumpId, summary, title: title);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error generating summary in detail screen: $e');
    }

    if (mounted) {
      setState(() => _isLoadingSummary = false);
    }
  }

  void _notifyAppState(String dumpId, String summary, {String? title}) {
    try {
      Provider.of<AppState>(context, listen: false).updateDumpInList(dumpId, {
        'ai_summary': summary,
        'title': ?title,
        'category': ?title,
      });
    } catch (_) {}
  }

  IconData _getIcon() {
    switch (_dump['type']) {
      case 'text': return Icons.notes;
      case 'voice': return Icons.graphic_eq;
      case 'photo': return Icons.image;
      default: return Icons.widgets;
    }
  }
  
  String _getTypeLabel() {
    switch (_dump['type']) {
      case 'text': return 'Thought';
      case 'voice': return 'Voice memo';
      case 'photo': return 'Moment';
      default: return 'Dump';
    }
  }

  String _getDetailTitle() {
    final rawTitle = _dump['title'] ?? _dump['category'];
    if (rawTitle != null && rawTitle.toString().trim().isNotEmpty && rawTitle.toString().toLowerCase() != 'null') {
      return rawTitle.toString().trim();
    }
    switch (_dump['type']) {
      case 'text': return 'Thought Detail';
      case 'voice': return 'Voice Memo Detail';
      case 'photo': return 'Moment Detail';
      default: return 'Dump Detail';
    }
  }

  List<String> _generateTags() {
    final tags = <String>[];
    final type = _dump['type'] as String?;
    final content = _dump['content'] as String? ?? '';
    final transcript = _dump['transcript'] as String? ?? '';
    final text = '$content $transcript'.toLowerCase();

    // Type-based tag
    switch (type) {
      case 'text': tags.add('#Thought'); break;
      case 'voice': tags.add('#VoiceMemo'); break;
      case 'photo': tags.add('#Moment'); break;
    }

    // Content-based tags
    if (text.contains('work') || text.contains('meeting') || text.contains('project')) {
      tags.add('#Work');
    }
    if (text.contains('feel') || text.contains('emotion') || text.contains('happy') || text.contains('sad') || text.contains('anxious')) {
      tags.add('#Feelings');
    }
    if (text.contains('idea') || text.contains('think') || text.contains('wonder')) {
      tags.add('#Ideas');
    }
    if (text.contains('goal') || text.contains('plan') || text.contains('want to')) {
      tags.add('#Goals');
    }
    if (text.contains('grateful') || text.contains('thankful') || text.contains('appreciate')) {
      tags.add('#Gratitude');
    }
    
    // Always add a daily log tag
    tags.add('#DailyLog');

    return tags.take(4).toList();
  }

  String _getCopyableText() {
    final content = _dump['content'] as String? ?? '';
    final transcript = _dump['transcript'] as String? ?? '';
    if (content.isNotEmpty) return content;
    if (transcript.isNotEmpty) return transcript;
    return 'No text content available.';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dumpId = _dump['id']?.toString();
    if (dumpId != null) {
      final liveIdx = appState.allDumps.indexWhere((d) => d['id']?.toString() == dumpId);
      if (liveIdx != -1) {
        _dump = {..._dump, ...appState.allDumps[liveIdx]};
      }
      if ((_dump['ai_summary'] as String?)?.trim().isNotEmpty == true ||
          (!CaptureService().isProcessing(dumpId) && _dump['is_processing'] != true)) {
        if ((_dump['ai_summary'] as String?)?.trim().isNotEmpty == true) {
          _isLoadingSummary = false;
        }
      }
    }

    final type = _dump['type'];
    final content = _dump['content'] as String?;
    final transcript = _dump['transcript'] as String?;
    final mediaUrl = _dump['media_url'] as String?;
    final capturedAt = _dump['captured_at'] ?? _dump['capturedAt'];
    final aiSummary = _dump['ai_summary'] as String?;
    
    // Format timestamp
    String timeLabel = 'Logged Today';
    if (capturedAt != null) {
      try {
        final dt = DateTime.parse(capturedAt.toString());
        final now = DateTime.now();
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          timeLabel = 'Today at $hour:$minute $amPm';
        } else {
          final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          timeLabel = '${months[dt.month - 1]} ${dt.day} at $hour:$minute $amPm';
        }
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_getDetailTitle()),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'delete') {
                _showDeleteConfirmation(context);
              } else if (value == 'copy') {
                _copyToClipboard(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'copy', child: Row(
                children: [Icon(Icons.content_copy, size: 20), SizedBox(width: 12), Text('Copy Text')],
              )),
              PopupMenuItem(value: 'delete', child: Row(
                children: [Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error), const SizedBox(width: 12), Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error))],
              )),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(_getIcon(), size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        _getTypeLabel(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (_dump['sync_status'] == 'synced')
                      Icon(Icons.cloud_done, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    if (_dump['sync_status'] == 'pending')
                      Icon(Icons.cloud_upload_outlined, size: 14, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn().slideX(begin: -0.05),
            
            const SizedBox(height: 24),

            // AI Summary Section
            _buildAiSummarySection(context, aiSummary),
            
            // Audio Player for Voice
            if (type == 'voice' && mediaUrl != null && mediaUrl.isNotEmpty) ...[
              AudioPlayerWidget(audioUrl: mediaUrl).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
              const SizedBox(height: 24),
            ],
            
            // Image Thumbnail for Photo
            if (type == 'photo' && mediaUrl != null && mediaUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: mediaUrl.startsWith('http')
                  ? Image.network(
                      mediaUrl,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: double.infinity,
                        height: 250,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    )
                  : Image.file(
                      File(mediaUrl),
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: double.infinity,
                        height: 250,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
              const SizedBox(height: 24),
            ],

            // User Note / Thought Content
            if (content != null && content.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          type == 'text' ? Icons.notes : Icons.edit_note,
                          size: 18,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type == 'text' ? 'THOUGHT DUMP' : 'YOUR NOTE',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
              const SizedBox(height: 24),
            ],
            
            // Transcribed Voice / Extracted Photo Text
            if (transcript != null && transcript.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          type == 'voice' ? Icons.graphic_eq : Icons.document_scanner_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type == 'voice' ? 'VOICE TRANSCRIPT' : 'EXTRACTED TEXT & DETAILS',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: transcript));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),
                            );
                          },
                          child: Icon(Icons.content_copy, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MarkdownBody(
                      data: transcript,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        h1: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        h2: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        h3: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
              const SizedBox(height: 24),
            ],
            
            // Extracted Tasks from this Capture
            _buildDumpTasksSection(context),

            // Dynamic Tags
            Text(
              'Connected Themes',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _generateTags().map((tag) => _buildTag(context, tag)).toList(),
            ).animate().fadeIn(delay: 350.ms),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(context),
                    icon: const Icon(Icons.content_copy, size: 20),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                label: const Text('Delete from tonight\'s cycle'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ).animate().fadeIn(delay: 450.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildDumpTasksSection(BuildContext context) {
    final dumpId = _dump['id']?.toString() ?? '';
    if (dumpId.isEmpty) return const SizedBox.shrink();

    final appState = context.watch<AppState>();
    final dumpTasks = appState.tasks
        .where((t) => t.dumpId == dumpId && !t.isArchived)
        .toList();

    if (dumpTasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0EBE1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.task_alt_rounded,
                        size: 18,
                        color: Color(0xFF389F7F),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'EXTRACTED TASKS',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Color(0xFF389F7F),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const TasksScreen(showBackButton: true),
                        ),
                      );
                    },
                    child: const Text(
                      'View all in Tasks →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF7A1A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...dumpTasks.map((task) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => appState.toggleTaskDone(task.id),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2, right: 10),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: task.isDone
                                ? const Color(0xFF389F7F)
                                : Colors.transparent,
                            border: Border.all(
                              color: task.isDone
                                  ? const Color(0xFF389F7F)
                                  : const Color(0xFFFF7A1A),
                              width: 1.8,
                            ),
                          ),
                          child: task.isDone
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: task.isDone
                                  ? const Color(0xFF9E978E)
                                  : const Color(0xFF1B1A19),
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ).animate().fadeIn(delay: 250.ms),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Builds the AI Summary card — shows loading shimmer while waiting,
  /// then displays the summary once available.
  Widget _buildAiSummarySection(BuildContext context, String? aiSummary) {
    if (aiSummary != null && aiSummary.isNotEmpty) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI SUMMARY',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: aiSummary,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    h1: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    h2: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    h3: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    listBullet: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05),
          const SizedBox(height: 24),
        ],
      );
    }

    final dumpId = _dump['id']?.toString() ?? '';
    final isProcessingInBg =
        _isLoadingSummary || _dump['is_processing'] == true || CaptureService().isProcessing(dumpId);

    // Show loading state if we're still waiting for the summary
    if (isProcessingInBg) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generating AI summary...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .fade(begin: 0.5, end: 1.0, duration: 1200.ms),
          const SizedBox(height: 24),
        ],
      );
    }

    // When no summary exists and not loading, offer a generate action
    return Column(
      children: [
        InkWell(
          onTap: _generateAiSummary,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD8B3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFF7A1A)),
                SizedBox(width: 8),
                Text(
                  'Generate AI Summary',
                  style: TextStyle(
                    color: Color(0xFFFF7A1A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 24),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _getCopyableText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this dump?'),
        content: const Text('This will permanently remove this capture from your cycle. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final dumpId = _dump['id']?.toString();
              if (dumpId != null) {
                // Optimistic 0ms UI deletion (deletes from local DB & cloud in background)
                context.read<AppState>().deleteDump(dumpId);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dump deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
