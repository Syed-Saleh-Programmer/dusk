import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/dump.dart';
import '../models/task_item.dart';
import 'local_db_service.dart';
import 'supabase_service.dart';

class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final LocalDbService _localDb = LocalDbService();
  final SupabaseService _supabase = SupabaseService();
  final Uuid _uuid = const Uuid();

  /// Callback notified whenever tasks are extracted or synced in the background
  static void Function()? onTasksChanged;

  /// Parses a JSON-encoded or raw list of AI task strings into a clean list.
  static List<String> parseTaskStrings(dynamic rawTasks) {
    if (rawTasks == null) return [];
    List<dynamic> list = [];
    if (rawTasks is List) {
      list = rawTasks;
    } else if (rawTasks is String && rawTasks.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTasks);
        if (decoded is List) {
          list = decoded;
        }
      } catch (_) {}
    }
    return list
        .map((e) => _cleanTaskTitle(e?.toString() ?? ''))
        .where((s) => s.length >= 3)
        .toList();
  }

  static String _cleanTaskTitle(String raw) {
    String s = raw.trim();
    // Strip markdown checkboxes or leading bullets/numbers
    s = s.replaceFirst(
      RegExp(r'^(\s*[-*•+]\s*(\[[ xX]\]\s*)?|\s*\d+[.)]\s*|\s*\[[ xX]\]\s*)'),
      '',
    );
    // Strip leading "todo:", "task:", "next step:" prefixes
    s = s.replaceFirst(
      RegExp(
        r'^(todo|to-do|task|action item|next step|reminder)\s*[:\-–]\s*',
        caseSensitive: false,
      ),
      '',
    );
    // Strip leading/trailing quotes
    s = s.replaceAll(RegExp(r'^["\x27]+|["\x27]+$'), '').trim();
    // Remove trailing period if it's a single short action phrase
    if (s.endsWith('.') && !s.endsWith('...')) {
      s = s.substring(0, s.length - 1).trim();
    }
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Client-side heuristic extractor that identifies actionable tasks from
  /// dump content, voice transcripts, or AI summaries when offline or when
  /// AI task extraction is not yet available.
  static List<String> extractTasksFromText(
    String? rawText, {
    String? aiSummary,
  }) {
    final results = <String>[];
    final seenNormalized = <String>{};

    void addCandidate(String candidate) {
      final cleaned = _cleanTaskTitle(candidate);
      if (cleaned.length < 4 || cleaned.length > 140) return;
      final wordCount = cleaned.split(RegExp(r'\s+')).length;
      if (wordCount < 2 || wordCount > 24) return;
      final norm = cleaned.toLowerCase();
      if (seenNormalized.contains(norm)) return;
      seenNormalized.add(norm);
      results.add(cleaned);
    }

    final text = (rawText ?? '').trim();
    if (text.isNotEmpty) {
      final lines = text.split(RegExp(r'[\r\n]+'));
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        if (line.toLowerCase().startsWith('extracted text:')) continue;

        // 1. Explicit checklist or bullet items
        final checkboxMatch = RegExp(
          r'^([-*•+]?\s*\[[ xX]\]\s+|[-*•+]\s+|\d+[.)]\s+)(.+)$',
        ).firstMatch(line);
        if (checkboxMatch != null) {
          addCandidate(checkboxMatch.group(2)!);
          continue;
        }

        // 2. Split line into sentences and check for action intent patterns
        final clauses = line.split(RegExp(r'(?<=[.!?])\s+|\s*;\s*'));
        for (final clause in clauses) {
          final c = clause.trim();
          if (c.isEmpty) continue;

          // Prefix patterns like "I need to ...", "Need to ...", "Remember to ...", "Don't forget to ...", "Must ...", "Todo: ..."
          final prefixIntent = RegExp(
            r'^(?:i\s+need\s+to|need\s+to|i\s+have\s+to|have\s+to|i\s+must|must|i\s+should|should|remember\s+to|don\x27t\s+forget\s+to|make\s+sure\s+to|plan\s+to|going\s+to|gonna|todo\s*[:\-]?|to-do\s*[:\-]?|task\s*[:\-]?|reminder\s*[:\-]?|next\s+step\s*[:\-]?)\s+(.+)$',
            caseSensitive: false,
          ).firstMatch(c);

          if (prefixIntent != null) {
            final extracted = prefixIntent.group(1)!.trim();
            // Split compound "need to X and Y" only if second part starts with a clear action verb
            final compoundParts = extracted.split(
              RegExp(
                r'\s+and\s+(?=(?:send|call|email|schedule|book|buy|finish|complete|review|update|fix|prepare|write|submit|reach|follow|check|create|clean|pay|pick)\b)',
                caseSensitive: false,
              ),
            );
            for (final part in compoundParts) {
              addCandidate(part);
            }
            continue;
          }

          // Direct imperative action verbs at start of a short sentence/note
          final imperativeMatch = RegExp(
            r'^(?:call|email|text|message|schedule|book|buy|pick\s+up|finish|complete|submit|send|review|prepare|follow\s+up\s+(?:with|on)|pay|renew|fix|update|draft|write|organize|clean)\s+.+$',
            caseSensitive: false,
          ).firstMatch(c);
          if (imperativeMatch != null) {
            final compoundParts = c.split(
              RegExp(
                r'\s+and\s+(?=(?:send|call|email|schedule|book|buy|finish|complete|review|update|fix|prepare|write|submit|reach|follow|check|create|clean|pay|pick)\b)',
                caseSensitive: false,
              ),
            );
            for (final part in compoundParts) {
              addCandidate(part);
            }
          }
        }
      }
    }

    // 3. Also check AI summary for explicit "Key focus:" / "Next step:" if nothing found yet
    if (results.isEmpty && aiSummary != null && aiSummary.trim().isNotEmpty) {
      final summaryMatch = RegExp(
        r'(?:next\s+steps?|key\s+focus|action\s+item)\s*[:\-–]\s*([^.!?\n]+)',
        caseSensitive: false,
      ).firstMatch(aiSummary);
      if (summaryMatch != null) {
        addCandidate(summaryMatch.group(1)!);
      }
    }

    return results.take(5).toList();
  }

  /// Extracts tasks for a Dump (using AI tasks if provided, or client-side extraction otherwise),
  /// saves new tasks to LocalDbService, and syncs to Supabase in the background.
  Future<List<TaskItem>> extractAndSaveTasksForDump({
    required String dumpId,
    required String userId,
    required DateTime capturedAt,
    String? dumpTitle,
    String? content,
    String? transcript,
    String? aiSummary,
    List<String>? aiTasks,
  }) async {
    if (userId.trim().isEmpty || dumpId.trim().isEmpty) return [];

    final existingForDump = await _localDb.getTasksForDump(dumpId, userId: userId);
    if (dumpTitle != null && dumpTitle.trim().isNotEmpty) {
      await _localDb.updateTaskSourceLabelForDump(dumpId, dumpTitle.trim());
    }

    final existingTitles = existingForDump
        .map((t) => t.title.toLowerCase().trim())
        .toSet();

    List<String> candidateTitles = [];
    if (aiTasks != null && aiTasks.isNotEmpty) {
      candidateTitles = aiTasks
          .map(_cleanTaskTitle)
          .where((t) => t.length >= 3)
          .toList();
    } else {
      final textToAnalyze = [
        if (content != null && content.trim().isNotEmpty) content.trim(),
        if (transcript != null && transcript.trim().isNotEmpty) transcript.trim(),
      ].join('\n');
      candidateTitles = extractTasksFromText(textToAnalyze, aiSummary: aiSummary);
    }

    if (candidateTitles.isEmpty) return existingForDump;

    final newTasks = <TaskItem>[];
    for (final rawTitle in candidateTitles) {
      final norm = rawTitle.toLowerCase().trim();
      if (existingTitles.contains(norm)) continue;
      existingTitles.add(norm);

      newTasks.add(
        TaskItem(
          id: _uuid.v4(),
          userId: userId,
          dumpId: dumpId,
          title: rawTitle,
          sourceType: TaskSourceType.dump,
          sourceLabel: (dumpTitle != null && dumpTitle.trim().isNotEmpty)
              ? dumpTitle.trim()
              : null,
          status: TaskStatus.pending,
          createdAt: capturedAt,
          updatedAt: DateTime.now(),
          syncStatus: SyncStatus.pending,
        ),
      );
    }

    if (newTasks.isNotEmpty) {
      await _localDb.insertTasksBatch(newTasks);
      onTasksChanged?.call();

      // Sync to Supabase in background
      _syncTasksListToRemote(newTasks);
    } else if (dumpTitle != null && dumpTitle.trim().isNotEmpty) {
      onTasksChanged?.call();
    }

    return [...existingForDump, ...newTasks];
  }

  Future<void> _syncTasksListToRemote(List<TaskItem> tasks) async {
    final synced = await _supabase.upsertTasks(tasks);
    if (synced) {
      for (final t in tasks) {
        await _localDb.updateTaskSyncStatus(t.id, SyncStatus.synced);
      }
      onTasksChanged?.call();
    }
  }

  /// Syncs local pending tasks to Supabase, pulls remote tasks from Supabase,
  /// and backfills tasks from existing Dumps and completed Insight Cards ("A gentle next step").
  Future<List<TaskItem>> syncAndLoadAllTasks({
    required String userId,
    List<Map<String, dynamic>>? currentDumps,
  }) async {
    if (userId.trim().isEmpty) return [];

    // 1. Push any pending local tasks to Supabase first
    try {
      final pendingLocal = await _localDb.getPendingSyncTasks(userId: userId);
      if (pendingLocal.isNotEmpty) {
        final ok = await _supabase.upsertTasks(pendingLocal);
        if (ok) {
          for (final t in pendingLocal) {
            await _localDb.updateTaskSyncStatus(t.id, SyncStatus.synced);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed pushing pending tasks: $e');
    }

    // 2. Fetch remote tasks & Insight Cards in parallel
    List<Map<String, dynamic>> remoteTaskMaps = [];
    List<Map<String, dynamic>> insightCards = [];
    try {
      final res = await Future.wait([
        _supabase.getAllTasks().catchError((_) => <Map<String, dynamic>>[]),
        _supabase.getInsightCards().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      remoteTaskMaps = res[0];
      insightCards = res[1];
    } catch (_) {}

    // 3. Merge remote tasks with local SQLite tasks using updated_at conflict resolution
    final localTasks = await _localDb.getAllTasks(userId: userId);
    final localById = {for (final t in localTasks) t.id: t};
    final toSaveLocally = <TaskItem>[];

    for (final map in remoteTaskMaps) {
      if (map['user_id']?.toString() != userId) continue;
      final remoteTask = TaskItem.fromMap(map).copyWith(syncStatus: SyncStatus.synced);
      final localTask = localById[remoteTask.id];

      if (localTask == null) {
        localById[remoteTask.id] = remoteTask;
        toSaveLocally.add(remoteTask);
      } else if (localTask.syncStatus == SyncStatus.pending &&
          localTask.updatedAt.isAfter(remoteTask.updatedAt)) {
        // Local offline edit is newer; keep local and push later
        continue;
      } else {
        final mergedTask =
            (remoteTask.dueDate == null && localTask.dueDate != null)
                ? remoteTask.copyWith(dueDate: localTask.dueDate)
                : remoteTask;
        localById[remoteTask.id] = mergedTask;
        toSaveLocally.add(mergedTask);
      }
    }

    if (toSaveLocally.isNotEmpty) {
      await _localDb.insertTasksBatch(toSaveLocally);
    }

    // 4. Ensure every completed Insight Card's "A gentle next step" (suggestion) exists as a TaskItem
    final existingInsightIds = localById.values
        .where((t) => t.insightCardId != null && t.insightCardId!.isNotEmpty)
        .map((t) => t.insightCardId!)
        .toSet();
    final existingInsightTitles = localById.values
        .where((t) => t.sourceType == TaskSourceType.insight)
        .map((t) => t.title.toLowerCase().trim())
        .toSet();

    final newInsightTasks = <TaskItem>[];
    for (final card in insightCards) {
      final cardId = card['id']?.toString();
      final suggestion = _cleanTaskTitle(card['suggestion']?.toString() ?? '');
      if (cardId == null || cardId.isEmpty || suggestion.isEmpty) continue;
      if (existingInsightIds.contains(cardId) ||
          existingInsightTitles.contains(suggestion.toLowerCase())) {
        continue;
      }

      existingInsightIds.add(cardId);
      existingInsightTitles.add(suggestion.toLowerCase());

      final createdAt =
          DateTime.tryParse(card['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now();
      final cardTitle = card['title']?.toString().trim();

      newInsightTasks.add(
        TaskItem(
          id: _uuid.v4(),
          userId: userId,
          insightCardId: cardId,
          title: suggestion,
          sourceType: TaskSourceType.insight,
          sourceLabel: (cardTitle != null && cardTitle.isNotEmpty)
              ? cardTitle
              : 'Evening Insight',
          status: TaskStatus.pending,
          createdAt: createdAt,
          updatedAt: DateTime.now(),
          syncStatus: SyncStatus.pending,
        ),
      );
    }

    if (newInsightTasks.isNotEmpty) {
      await _localDb.insertTasksBatch(newInsightTasks);
      for (final t in newInsightTasks) {
        localById[t.id] = t;
      }
      _syncTasksListToRemote(newInsightTasks);
    }

    // 5. Backfill tasks from existing Dumps that don't have tasks extracted yet
    if (currentDumps != null && currentDumps.isNotEmpty) {
      final dumpsWithTasks = localById.values
          .where((t) => t.dumpId != null && t.dumpId!.isNotEmpty)
          .map((t) => t.dumpId!)
          .toSet();

      for (final dumpMap in currentDumps) {
        final dumpId = dumpMap['id']?.toString();
        if (dumpId == null || dumpId.isEmpty) continue;
        if (dumpsWithTasks.contains(dumpId)) continue;

        final capturedAt = DateTime.tryParse(
              (dumpMap['captured_at'] ?? dumpMap['created_at'])?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();

        final extracted = await extractAndSaveTasksForDump(
          dumpId: dumpId,
          userId: userId,
          capturedAt: capturedAt,
          dumpTitle: (dumpMap['title'] ?? dumpMap['category'])?.toString(),
          content: dumpMap['content']?.toString(),
          transcript: dumpMap['transcript']?.toString(),
          aiSummary: dumpMap['ai_summary']?.toString(),
        );
        for (final t in extracted) {
          localById[t.id] = t;
        }
      }
    }

    final all = localById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  /// Formats a list of tasks into clean, structured Markdown for 1-tap export
  /// to Apple Reminders, Google Tasks, Notion, Obsidian, or Notes.
  static String formatTasksAsMarkdown(
    List<TaskItem> tasks, {
    String periodLabel = 'All Time',
  }) {
    if (tasks.isEmpty) {
      return '# Dusk — Gentle Next Steps & Tasks\n\n_No tasks in this view._';
    }

    final buffer = StringBuffer();
    final dateStr = DateFormat('MMM d, yyyy').format(DateTime.now());
    buffer.writeln('# Dusk — Gentle Next Steps & Tasks');
    buffer.writeln('_Exported on $dateStr • Filter: ${periodLabel}_\n');

    final insightSteps =
        tasks.where((t) => t.sourceType == TaskSourceType.insight).toList();
    final dumpSteps =
        tasks.where((t) => t.sourceType == TaskSourceType.dump).toList();
    final manualSteps =
        tasks.where((t) => t.sourceType == TaskSourceType.manual).toList();

    void writeSection(String heading, List<TaskItem> sectionTasks) {
      if (sectionTasks.isEmpty) return;
      buffer.writeln('## $heading');
      for (final t in sectionTasks) {
        final check = t.isDone ? '[x]' : '[ ]';
        final dateTag = DateFormat('MMM d').format(t.createdAt);
        final dueTag = t.dueDate != null
            ? ' • Due ${DateFormat('MMM d').format(t.dueDate!.toLocal())}'
            : '';
        final sourceSuffix = (t.sourceLabel != null && t.sourceLabel!.trim().isNotEmpty)
            ? ' _(${t.sourceLabel!.trim()} • $dateTag$dueTag)_'
            : ' _($dateTag$dueTag)_';
        buffer.writeln('- $check ${t.title}$sourceSuffix');
      }
      buffer.writeln();
    }

    writeSection('Gentle Next Steps (From Reflections)', insightSteps);
    writeSection('Tasks from Captures', dumpSteps);
    writeSection('Personal Steps', manualSteps);

    return buffer.toString().trimRight();
  }
}
