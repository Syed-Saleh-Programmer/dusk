import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/dump.dart';
import '../models/task_item.dart';
import 'local_db_service.dart';
import 'supabase_service.dart';

class AiExtractedTask {
  final String title;
  final List<String> tags;

  const AiExtractedTask({
    required this.title,
    this.tags = const [],
  });
}

class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final LocalDbService _localDb = LocalDbService();
  final SupabaseService _supabase = SupabaseService();
  final Uuid _uuid = const Uuid();

  /// Callback notified whenever tasks are extracted or synced in the background
  static void Function()? onTasksChanged;

  /// Callback notified whenever AI or remote sync introduces new tags
  static void Function(List<String> tags)? onNewTagsDiscovered;

  /// Parses a JSON-encoded or raw list of AI tasks (either strings or `{title, tags}` objects).
  static List<AiExtractedTask> parseAiTasks(dynamic rawTasks) {
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

    final results = <AiExtractedTask>[];
    for (final item in list) {
      if (item is Map) {
        final rawTitle =
            (item['title'] ?? item['task'] ?? item['text'] ?? '').toString();
        final cleaned = _cleanTaskTitle(rawTitle);
        if (cleaned.length >= 3) {
          final tags = Dump.parseTags(item['tags']);
          results.add(AiExtractedTask(title: cleaned, tags: tags));
        }
      } else if (item != null) {
        final cleaned = _cleanTaskTitle(item.toString());
        if (cleaned.length >= 3) {
          results.add(AiExtractedTask(title: cleaned));
        }
      }
    }
    return results;
  }

  /// Parses a JSON-encoded or raw list of AI task strings into a clean list.
  static List<String> parseTaskStrings(dynamic rawTasks) {
    return parseAiTasks(rawTasks).map((e) => e.title).toList();
  }

  /// Selects relevant tags for a task or dump text from available tags and keyword heuristics,
  /// and extracts any explicit #hashtags.
  static List<String> inferTagsForText(
    String text, {
    List<String> seedTags = const [],
    List<String> availableTags = const [],
  }) {
    final combined = <String>[...Dump.parseTags(seedTags)];
    final lower = text.toLowerCase();

    // 1. Extract explicit #hashtags from text if present
    final hashtagMatches = RegExp(r'#([a-zA-Z][a-zA-Z0-9_-]{1,20})').allMatches(text);
    for (final m in hashtagMatches) {
      final tag = Dump.normalizeTag(m.group(1) ?? '');
      if (tag.isNotEmpty) combined.add(tag);
    }

    // 2. Match any user custom / available tags mentioned directly in the text
    final pool = Dump.parseTags([...Dump.defaultTags, ...availableTags]);
    for (final tag in pool) {
      final tagLower = tag.toLowerCase();
      if (RegExp(r'\b' + RegExp.escape(tagLower) + r'\b', caseSensitive: false)
          .hasMatch(lower)) {
        combined.add(tag);
      }
    }

    // 3. Keyword-to-tag mapping for common action domains
    final keywordRules = <String, RegExp>{
      'Work': RegExp(
        r'\b(meeting|standup|client|project|deadline|sprint|email|report|review|deck|presentation|deploy|code|bug|team|colleague|manager|proposal|sync|slides|ticket)\b',
        caseSensitive: false,
      ),
      'Errands': RegExp(
        r'\b(buy|grocery|groceries|store|shop|pick\s+up|order|package|return|clean|laundry|dishes|chore|pharmacy|errand)\b',
        caseSensitive: false,
      ),
      'Finance': RegExp(
        r'\b(pay|bill|rent|budget|bank|tax|subscription|renew|expense|invoice|salary|invest|money|receipt)\b',
        caseSensitive: false,
      ),
      'Health': RegExp(
        r'\b(workout|gym|run|walk|doctor|dentist|meds|medicine|sleep|water|hydrate|stretch|yoga|therapy|appointment|health|exercise)\b',
        caseSensitive: false,
      ),
      'Learning': RegExp(
        r'\b(read|book|study|course|learn|tutorial|article|lecture|practice|research|lesson)\b',
        caseSensitive: false,
      ),
      'Goals': RegExp(
        r'\b(goal|milestone|habit|plan|target|vision|quarter|launch|focus|objective)\b',
        caseSensitive: false,
      ),
      'Ideas': RegExp(
        r'\b(idea|brainstorm|concept|prototype|design|sketch|experiment|explore|feature)\b',
        caseSensitive: false,
      ),
      'Personal': RegExp(
        r'\b(mom|dad|family|friend|birthday|dinner|weekend|home|trip|vacation|gift|call\s+mom|call\s+dad)\b',
        caseSensitive: false,
      ),
    };

    keywordRules.forEach((tag, regex) {
      if (regex.hasMatch(lower)) {
        combined.add(tag);
      }
    });

    return Dump.parseTags(combined).take(4).toList();
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

  /// Checks whether a phrase is purely an introductory line, heading, or meta-sentence
  /// rather than a real, actionable task (e.g., "Complete the following", "Need to do these things:").
  static bool isNonActionableIntro(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return true;
    if (RegExp(
      r'\b(the following|following|as follows|below|these tasks|these items|these things|this list|a few things|stuff to do)\b',
      caseSensitive: false,
    ).hasMatch(s)) {
      return true;
    }
    if (s.endsWith(':')) return true;
    if (RegExp(
      r'^(todo|to-do|tasks?|checklist|reminders?|notes?|action items?)$',
      caseSensitive: false,
    ).hasMatch(s)) {
      return true;
    }
    if (RegExp(
      r'^(here is|here are|this is|things to do|what to do|items to do|plan for today)\b',
      caseSensitive: false,
    ).hasMatch(s)) {
      return true;
    }
    return false;
  }

  /// Normalizes a task title for duplicate detection by stripping standalone articles
  /// ("the", "a", "an", "to"), punctuation, and collapsing excess whitespace.
  static String normalizeTaskForDeduplication(String title) {
    var s = title.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    s = s.replaceAll(RegExp(r'\b(the|a|an|to)\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Determines whether two task titles are semantically equivalent or duplicate variants
  /// (e.g. "Complete app" vs "Complete the app", "Prepare demo" vs "Prepare demo.").
  static bool areTaskTitlesEquivalent(String a, String b) {
    final normA = normalizeTaskForDeduplication(a);
    final normB = normalizeTaskForDeduplication(b);
    if (normA.isEmpty || normB.isEmpty) return false;
    if (normA == normB) return true;
    final wordsA = normA.split(' ').where((w) => w.isNotEmpty).toSet();
    final wordsB = normB.split(' ').where((w) => w.isNotEmpty).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return false;
    final common = wordsA.intersection(wordsB).length;
    final minLen = wordsA.length < wordsB.length ? wordsA.length : wordsB.length;
    final maxLen = wordsA.length > wordsB.length ? wordsA.length : wordsB.length;
    if (common == minLen && (maxLen - minLen) <= 1) return true;
    if (common / maxLen >= 0.65) return true;
    return false;
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
      if (isNonActionableIntro(candidate)) return;
      final cleaned = _cleanTaskTitle(candidate);
      if (cleaned.length < 3 || cleaned.length > 140) return;
      if (isNonActionableIntro(cleaned)) return;
      final wordCount = cleaned.split(RegExp(r'\s+')).length;
      if (wordCount < 1 || wordCount > 24) return;
      final norm = normalizeTaskForDeduplication(cleaned);
      if (norm.isEmpty || seenNormalized.contains(norm)) return;
      for (final existing in results) {
        if (areTaskTitlesEquivalent(existing, cleaned)) return;
      }
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
        if (isNonActionableIntro(line)) continue;

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
          if (isNonActionableIntro(c)) continue;

          // Prefix patterns like "I need to ...", "Need to ...", "Remember to ...", "Don't forget to ...", "Must ...", "Todo: ..."
          final prefixIntent = RegExp(
            r'^(?:i\s+need\s+to|need\s+to|i\s+have\s+to|have\s+to|i\s+must|must|i\s+should|should|remember\s+to|don\x27t\s+forget\s+to|make\s+sure\s+to|plan\s+to|going\s+to|gonna|todo\s*[:\-]?|to-do\s*[:\-]?|task\s*[:\-]?|reminder\s*[:\-]?|next\s+step\s*[:\-]?)\s+(.+)$',
            caseSensitive: false,
          ).firstMatch(c);

          if (prefixIntent != null) {
            final extracted = prefixIntent.group(1)!.trim();
            if (isNonActionableIntro(extracted)) continue;
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
  /// assigns/merges relevant tags, saves tasks to LocalDbService, and syncs to Supabase in the background.
  Future<List<TaskItem>> extractAndSaveTasksForDump({
    required String dumpId,
    required String userId,
    required DateTime capturedAt,
    String? dumpTitle,
    String? content,
    String? transcript,
    String? aiSummary,
    List<String>? aiTasks,
    List<AiExtractedTask>? aiStructuredTasks,
    List<String>? dumpTags,
    List<String>? availableTags,
    String? projectId,
  }) async {
    if (userId.trim().isEmpty || dumpId.trim().isEmpty) return [];

    await _localDb.markDumpsTasksExtracted([dumpId], userId: userId);
    final deletedTitles = await _localDb.getDeletedTaskTitles(userId: userId, dumpId: dumpId);

    final existingForDump = await _localDb.getTasksForDump(dumpId, userId: userId);
    if (dumpTitle != null && dumpTitle.trim().isNotEmpty) {
      await _localDb.updateTaskSourceLabelForDump(dumpId, dumpTitle.trim());
    }

    // Purge any legacy non-actionable intro tasks that were previously saved for this dump
    final invalidTasks = existingForDump.where((t) => isNonActionableIntro(t.title)).toList();
    if (invalidTasks.isNotEmpty) {
      final invalidIds = invalidTasks.map((t) => t.id).toList();
      await _localDb.deleteTasksBatch(invalidIds, userId: userId);
      existingForDump.removeWhere((t) => invalidIds.contains(t.id));
      unawaited(_supabase.deleteTasks(invalidIds));
    }

    final normalizedDumpTags = Dump.parseTags(dumpTags);
    final normalizedAvailable = Dump.parseTags(availableTags);

    List<AiExtractedTask> candidates = [];
    if (aiStructuredTasks != null && aiStructuredTasks.isNotEmpty) {
      candidates = aiStructuredTasks
          .map(
            (e) => AiExtractedTask(
              title: _cleanTaskTitle(e.title),
              tags: e.tags,
            ),
          )
          .where((e) => e.title.length >= 3 && !isNonActionableIntro(e.title))
          .toList();
    } else if (aiTasks != null && aiTasks.isNotEmpty) {
      candidates = aiTasks
          .map(_cleanTaskTitle)
          .where((t) => t.length >= 3 && !isNonActionableIntro(t))
          .map((t) => AiExtractedTask(title: t))
          .toList();
    } else {
      final textToAnalyze = [
        if (content != null && content.trim().isNotEmpty) content.trim(),
        if (transcript != null && transcript.trim().isNotEmpty) transcript.trim(),
      ].join('\n');
      candidates = extractTasksFromText(textToAnalyze, aiSummary: aiSummary)
          .map((t) => AiExtractedTask(title: t))
          .toList();
    }

    final discoveredTags = <String>{...normalizedDumpTags};
    final updatedExistingTasks = <TaskItem>[];

    // If dumpTags were provided and there are already existing tasks for this dump, ensure they inherit relevant tags
    if (candidates.isEmpty && normalizedDumpTags.isNotEmpty && existingForDump.isNotEmpty) {
      for (var i = 0; i < existingForDump.length; i++) {
        final existing = existingForDump[i];
        final mergedTags = Dump.parseTags([...existing.tags, ...normalizedDumpTags]);
        if (mergedTags.join('|') != existing.tags.join('|')) {
          final updated = existing.copyWith(
            tags: mergedTags,
            updatedAt: DateTime.now(),
            syncStatus: SyncStatus.pending,
          );
          existingForDump[i] = updated;
          updatedExistingTasks.add(updated);
          await _localDb.updateTaskDetails(
            existing.id,
            tags: mergedTags,
            syncStatus: SyncStatus.pending,
          );
        }
      }
      if (updatedExistingTasks.isNotEmpty) {
        onTasksChanged?.call();
        _syncTasksListToRemote(updatedExistingTasks);
      }
      return existingForDump;
    }

    if (candidates.isEmpty) return existingForDump;

    final newTasks = <TaskItem>[];
    for (final candidate in candidates) {
      final rawTitle = candidate.title;
      if (isNonActionableIntro(rawTitle)) continue;

      final norm = normalizeTaskForDeduplication(rawTitle);
      if (norm.isEmpty) continue;

      // Never re-extract a task that the user explicitly deleted
      if (deletedTitles.contains(norm) || deletedTitles.contains(rawTitle.toLowerCase().trim())) {
        continue;
      }

      final taskTags = inferTagsForText(
        rawTitle,
        seedTags: [
          ...candidate.tags,
          ...normalizedDumpTags,
        ],
        availableTags: normalizedAvailable,
      );
      discoveredTags.addAll(taskTags);

      // Check if this task already exists for this dump using semantic equivalence
      final existingIdx = existingForDump.indexWhere(
        (t) => areTaskTitlesEquivalent(t.title, rawTitle),
      );

      if (existingIdx != -1) {
        // MATCH FOUND: Merge tags and metadata onto the existing task rather than creating a duplicate
        final existingMatch = existingForDump[existingIdx];
        final mergedTags = Dump.parseTags([...existingMatch.tags, ...taskTags]);
        final bool tagsChanged = mergedTags.join('|') != existingMatch.tags.join('|');
        final bool labelChanged = (dumpTitle != null && dumpTitle.trim().isNotEmpty) &&
            existingMatch.sourceLabel != dumpTitle.trim();

        if (tagsChanged || labelChanged) {
          final updated = existingMatch.copyWith(
            tags: mergedTags,
            sourceLabel: (dumpTitle != null && dumpTitle.trim().isNotEmpty)
                ? dumpTitle.trim()
                : existingMatch.sourceLabel,
            updatedAt: DateTime.now(),
            syncStatus: SyncStatus.pending,
          );
          existingForDump[existingIdx] = updated;
          updatedExistingTasks.add(updated);
          await _localDb.updateTaskDetails(
            existingMatch.id,
            tags: mergedTags,
            syncStatus: SyncStatus.pending,
          );
        }
        continue;
      }

      // Check if a task with equivalent title was already added in this candidate batch
      if (newTasks.any((t) => areTaskTitlesEquivalent(t.title, rawTitle))) {
        continue;
      }

      final createdTask = TaskItem(
        id: _uuid.v4(),
        userId: userId,
        dumpId: dumpId,
        projectId: projectId,
        title: rawTitle,
        sourceType: TaskSourceType.dump,
        sourceLabel: (dumpTitle != null && dumpTitle.trim().isNotEmpty)
            ? dumpTitle.trim()
            : null,
        tags: taskTags,
        status: TaskStatus.pending,
        createdAt: capturedAt,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
      existingForDump.add(createdTask);
      newTasks.add(createdTask);
    }

    if (discoveredTags.isNotEmpty) {
      onNewTagsDiscovered?.call(discoveredTags.toList());
    }

    if (newTasks.isNotEmpty || updatedExistingTasks.isNotEmpty) {
      if (newTasks.isNotEmpty) {
        await _localDb.insertTasksBatch(newTasks);
      }
      onTasksChanged?.call();

      // Sync to Supabase in background
      _syncTasksListToRemote([...newTasks, ...updatedExistingTasks]);
    } else if (dumpTitle != null && dumpTitle.trim().isNotEmpty) {
      onTasksChanged?.call();
    }

    return existingForDump;
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

    // 1b. Retrieve persistent deleted task tombstones and processed dump statuses
    final deletedTaskIds = await _localDb.getDeletedTaskIds(userId: userId);
    final deletedTaskTitles = await _localDb.getDeletedTaskTitles(userId: userId);
    final deletedInsightIds = await _localDb.getDeletedInsightCardIds(userId: userId);
    final extractedDumpIds = await _localDb.getExtractedDumpIds(userId: userId);

    // Sync any pending deletions to Supabase in the background
    if (deletedTaskIds.isNotEmpty) {
      unawaited(_supabase.deleteTasks(deletedTaskIds.toList()));
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

    // 3. Merge remote tasks with local SQLite tasks using updated_at conflict resolution & deduplication
    final localTasks = await _localDb.getAllTasks(userId: userId);
    final localById = <String, TaskItem>{};
    final localDuplicatesToDelete = <String>[];

    for (final t in localTasks) {
      if (deletedTaskIds.contains(t.id) ||
          deletedTaskTitles.contains(t.title.toLowerCase().trim()) ||
          isNonActionableIntro(t.title)) {
        localDuplicatesToDelete.add(t.id);
        continue;
      }

      // Check if duplicate for same dump already added to localById
      final duplicateMatch = localById.values.firstWhereOrNull(
        (existing) =>
            existing.dumpId != null &&
            existing.dumpId == t.dumpId &&
            areTaskTitlesEquivalent(existing.title, t.title),
      );

      if (duplicateMatch != null) {
        // Keep the one that is synced or newer; mark redundant copy for deletion
        if (t.syncStatus == SyncStatus.synced && duplicateMatch.syncStatus != SyncStatus.synced) {
          localById.remove(duplicateMatch.id);
          localDuplicatesToDelete.add(duplicateMatch.id);
          localById[t.id] = t;
        } else {
          localDuplicatesToDelete.add(t.id);
        }
      } else {
        localById[t.id] = t;
      }
    }

    if (localDuplicatesToDelete.isNotEmpty) {
      await _localDb.deleteTasksBatch(localDuplicatesToDelete, userId: userId);
      unawaited(_supabase.deleteTasks(localDuplicatesToDelete));
    }

    final toSaveLocally = <TaskItem>[];
    final discoveredRemoteTags = <String>{};

    for (final map in remoteTaskMaps) {
      if (map['user_id']?.toString() != userId) continue;
      final remoteTask = TaskItem.fromMap(map).copyWith(syncStatus: SyncStatus.synced);

      // If this task was deleted by the user or is a non-actionable intro, delete from cloud
      if (deletedTaskIds.contains(remoteTask.id) ||
          deletedTaskTitles.contains(remoteTask.title.toLowerCase().trim()) ||
          isNonActionableIntro(remoteTask.title)) {
        unawaited(_supabase.deleteTask(remoteTask.id));
        continue;
      }

      // Check if an equivalent task already exists for this dump (e.g. from local extraction or edge function)
      final existingEquivalent = localById.values.firstWhereOrNull(
        (local) =>
            local.dumpId != null &&
            local.dumpId == remoteTask.dumpId &&
            areTaskTitlesEquivalent(local.title, remoteTask.title),
      );

      if (existingEquivalent != null) {
        // If IDs differ, the remote row is an unlinked duplicate; clean it from Supabase
        if (existingEquivalent.id != remoteTask.id) {
          unawaited(_supabase.deleteTask(remoteTask.id));
        }
        // Merge tags if remote has more tags
        final mergedTags = Dump.parseTags([...existingEquivalent.tags, ...remoteTask.tags]);
        if (mergedTags.join('|') != existingEquivalent.tags.join('|')) {
          final updated = existingEquivalent.copyWith(tags: mergedTags);
          localById[existingEquivalent.id] = updated;
          toSaveLocally.add(updated);
        }
        continue;
      }

      discoveredRemoteTags.addAll(remoteTask.tags);
      final localTask = localById[remoteTask.id];

      if (localTask == null) {
        localById[remoteTask.id] = remoteTask;
        toSaveLocally.add(remoteTask);
      } else if (localTask.syncStatus == SyncStatus.pending &&
          localTask.updatedAt.isAfter(remoteTask.updatedAt)) {
        // Local offline edit is newer; keep local and push later
        continue;
      } else {
        final mergedTags = remoteTask.tags.isNotEmpty
            ? remoteTask.tags
            : localTask.tags;
        final mergedTask = remoteTask.copyWith(
          dueDate: remoteTask.dueDate ?? localTask.dueDate,
          tags: mergedTags,
        );
        localById[remoteTask.id] = mergedTask;
        toSaveLocally.add(mergedTask);
      }
    }

    if (toSaveLocally.isNotEmpty) {
      await _localDb.insertTasksBatch(toSaveLocally);
    }
    if (discoveredRemoteTags.isNotEmpty) {
      onNewTagsDiscovered?.call(discoveredRemoteTags.toList());
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

      // Skip if previously deleted by the user
      if (deletedInsightIds.contains(cardId) ||
          deletedTaskTitles.contains(suggestion.toLowerCase())) {
        continue;
      }

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
      final cardTags = inferTagsForText(
        suggestion,
        seedTags: [
          ...Dump.parseTags(card['suggestion_tags'] ?? card['tags']),
          'Goals',
        ],
      );

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
          tags: cardTags,
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
        // Never re-extract tasks for dumps that were already extracted
        if (extractedDumpIds.contains(dumpId)) continue;
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
          dumpTags: Dump.parseTags(dumpMap['tags']),
          projectId: dumpMap['project_id']?.toString(),
        );
        extractedDumpIds.add(dumpId);
        for (final t in extracted) {
          localById[t.id] = t;
        }
      }
    }

    final all = localById.values
        .where((t) => !deletedTaskIds.contains(t.id))
        .toList()
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
        final tagsSegment = t.tags.isNotEmpty
            ? ' ${t.tags.map((tag) => '#${tag.replaceAll(' ', '')}').join(' ')}'
            : '';
        final sourceSuffix = (t.sourceLabel != null && t.sourceLabel!.trim().isNotEmpty)
            ? ' _(${t.sourceLabel!.trim()} • $dateTag$dueTag)_'
            : ' _($dateTag$dueTag)_';
        buffer.writeln('- $check ${t.title}$tagsSegment$sourceSuffix');
      }
      buffer.writeln();
    }

    writeSection('Gentle Next Steps (From Reflections)', insightSteps);
    writeSection('Tasks from Captures', dumpSteps);
    writeSection('Personal Steps', manualSteps);

    return buffer.toString().trimRight();
  }
}
