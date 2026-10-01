import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/dump.dart';
import 'local_db_service.dart';
import 'supabase_service.dart';
import 'task_service.dart';
import 'subscription_service.dart';

class CaptureService {
  static final CaptureService _instance = CaptureService._internal();
  factory CaptureService() => _instance;
  CaptureService._internal();

  final LocalDbService _localDb = LocalDbService();
  final SupabaseService _supabase = SupabaseService();
  final Uuid _uuid = const Uuid();

  final Set<String> _processingIds = {};
  final Set<String> _deletedIds = {};

  bool isProcessing(String dumpId) => _processingIds.contains(dumpId);
  bool isDeleted(String dumpId) => _deletedIds.contains(dumpId);

  void markDeleted(String dumpId) {
    _deletedIds.add(dumpId);
    _processingIds.remove(dumpId);
  }

  /// Clears in-flight processing & deleted tracking when user logs out or switches accounts
  void clearState() {
    _processingIds.clear();
    _deletedIds.clear();
  }

  /// Callback registered by AppState or UI to receive real-time title/summary updates
  static void Function(String dumpId, String? title, String? summary)? onDumpAiGenerated;

  /// Callback registered by AppState to receive immediate field updates (sync_status, transcript, title, ai_summary, tags, is_processing)
  static void Function(String dumpId, Map<String, dynamic> updatedFields)? onDumpUpdated;

  /// Callback registered by AppState to supply the user's current available tags list
  static List<String> Function()? getAvailableTags;

  /// Copies temporary/shared media files into persistent app documents storage so OS cache cleanup never deletes them.
  Future<String> _persistLocalMedia(String rawPath, {required bool isAudio}) async {
    if (rawPath.isEmpty ||
        rawPath.startsWith('http://') ||
        rawPath.startsWith('https://')) {
      return rawPath;
    }

    try {
      String cleanPath = rawPath;
      if (cleanPath.startsWith('file://')) {
        cleanPath = Uri.parse(cleanPath).toFilePath();
      }
      final sourceFile = File(cleanPath);
      if (!await sourceFile.exists()) {
        return cleanPath;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final folderName = isAudio ? 'audio_dumps' : 'photo_dumps';
      final targetDir = Directory(p.join(docsDir.path, folderName));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      if (p.isWithin(targetDir.path, sourceFile.path)) {
        return sourceFile.path;
      }

      String ext = p.extension(sourceFile.path).toLowerCase();
      if (ext.isEmpty) {
        ext = isAudio ? '.m4a' : '.jpg';
      }
      final prefix = isAudio ? 'voice' : 'photo';
      final fileName =
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}$ext';
      final destPath = p.join(targetDir.path, fileName);
      final copied = await sourceFile.copy(destPath);
      return copied.path;
    } catch (e) {
      debugPrint('Failed to persist media file ($rawPath): $e');
      return rawPath;
    }
  }

  /// Captures a text dump, saves locally, and returns the Dump immediately.
  /// Cloud sync and AI summary happen in the background without delay.
  Future<Dump> captureText(
    String content, {
    List<String> tags = const [],
    String? projectId,
  }) async {
    final userId = _supabase.currentUser?.id ?? 'local_user';
    final now = DateTime.now();

    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.text,
      content: content,
      tags: tags,
      projectId: projectId,
      capturedAt: now,
      createdAt: now,
      syncStatus: SyncStatus.pending,
    );

    _processingIds.add(dump.id);
    await _localDb.insertDump(dump);
    // Extract any immediate local tasks in 0ms
    unawaited(
      TaskService().extractAndSaveTasksForDump(
        dumpId: dump.id,
        userId: userId,
        capturedAt: now,
        content: content,
        dumpTags: dump.tags,
        availableTags: getAvailableTags?.call(),
        projectId: projectId,
      ),
    );
    // Fire-and-forget: sync and AI summary immediately in background
    _syncAndSummarize(dump);
    return dump;
  }

  /// Captures a voice dump, saves locally, and returns the Dump immediately.
  /// Cloud sync and AI summary happen in the background.
  Future<Dump> captureVoice(
    String mediaUrl,
    String transcript, {
    String? content,
    List<String> tags = const [],
    String? projectId,
  }) async {
    final userId = _supabase.currentUser?.id ?? 'local_user';
    final now = DateTime.now();
    final persistedMediaUrl = await _persistLocalMedia(mediaUrl, isAudio: true);
    final cleanContent =
        (content != null && content.trim().isNotEmpty) ? content.trim() : null;

    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.voice,
      content: cleanContent,
      mediaUrl: persistedMediaUrl,
      transcript: transcript,
      tags: tags,
      projectId: projectId,
      capturedAt: now,
      createdAt: now,
      syncStatus: SyncStatus.pending,
    );

    _processingIds.add(dump.id);
    await _localDb.insertDump(dump);
    if (transcript.trim().isNotEmpty || cleanContent != null) {
      unawaited(
        TaskService().extractAndSaveTasksForDump(
          dumpId: dump.id,
          userId: userId,
          capturedAt: now,
          content: cleanContent,
          transcript: transcript,
          dumpTags: dump.tags,
          availableTags: getAvailableTags?.call(),
          projectId: projectId,
        ),
      );
    }
    // Fire-and-forget: sync and AI summary in background
    _syncAndSummarize(dump);
    return dump;
  }

  /// Captures a photo dump, saves locally, and returns the Dump immediately.
  /// Cloud sync and AI summary happen in the background.
  Future<Dump> capturePhoto(
    String mediaUrl, {
    String? content,
    List<String> tags = const [],
    String? projectId,
  }) async {
    final userId = _supabase.currentUser?.id ?? 'local_user';
    final now = DateTime.now();
    final persistedMediaUrl = await _persistLocalMedia(mediaUrl, isAudio: false);
    final cleanContent =
        (content != null && content.trim().isNotEmpty) ? content.trim() : null;

    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.photo,
      content: cleanContent,
      mediaUrl: persistedMediaUrl,
      tags: tags,
      projectId: projectId,
      capturedAt: now,
      createdAt: now,
      syncStatus: SyncStatus.pending,
    );

    _processingIds.add(dump.id);
    await _localDb.insertDump(dump);
    if (cleanContent != null) {
      unawaited(
        TaskService().extractAndSaveTasksForDump(
          dumpId: dump.id,
          userId: userId,
          capturedAt: now,
          content: cleanContent,
          dumpTags: dump.tags,
          availableTags: getAvailableTags?.call(),
          projectId: projectId,
        ),
      );
    }
    // Fire-and-forget: sync and AI summary in background
    _syncAndSummarize(dump);
    return dump;
  }

  /// Triggers background processing for a dump if it isn't already processing.
  Future<void> processDumpIfNeeded(Dump dump) async {
    if (_processingIds.contains(dump.id) || _deletedIds.contains(dump.id)) {
      return;
    }
    await _syncAndSummarize(dump);
  }

  /// Background task: sync to cloud first, then request AI title & summary.
  /// Immediately notifies AppState at each stage so cards re-render in real time.
  Future<void> _syncAndSummarize(Dump dump) async {
    if (_deletedIds.contains(dump.id)) return;
    if (!SubscriptionService().isPro) {
      // Free Tier: 100% offline local SQLite storage without syncing to Supabase
      return;
    }
    if (_supabase.currentUser?.id != dump.userId) return;
    _processingIds.add(dump.id);
    onDumpUpdated?.call(dump.id, {'is_processing': true});

    final availableTags = getAvailableTags?.call() ?? Dump.defaultTags;

    try {
      if (dump.type == DumpType.text) {
        // Run sync and AI generation concurrently for ultra-fast processing
        final syncFuture = _supabase.syncDumps(
          [dump],
          availableTags: availableTags,
        );

        final aiFuture = _supabase.generateDumpSummaryAndTitle(
          dump.id,
          dump.userId,
          content: dump.content,
          type: dump.type.name,
          availableTags: availableTags,
          existingTags: dump.tags,
        );

        final results = await Future.wait([syncFuture, aiFuture]);
        if (_deletedIds.contains(dump.id)) {
          _supabase.deleteDump(dump.id);
          return;
        }
        if (_supabase.currentUser?.id != dump.userId) return;

        final syncRes = results[0] as Map<String, dynamic>;
        final result = results[1] as Map<String, String?>?;

        if (syncRes.containsKey(dump.id)) {
          await _localDb.updateDumpSyncStatus(dump.id, SyncStatus.synced);
          onDumpUpdated?.call(dump.id, {'sync_status': SyncStatus.synced.name});
        }

        if (result != null) {
          final summary = result['summary']?.trim();
          final title = result['title']?.trim();
          final aiTags = Dump.parseTags(result['tags_json']);
          final mergedTags = Dump.parseTags([...dump.tags, ...aiTags]);
          final aiStructuredTasks = TaskService.parseAiTasks(result['tasks_json']);

          if (mergedTags.isNotEmpty) {
            TaskService.onNewTagsDiscovered?.call(mergedTags);
          }

          if ((summary != null && summary.isNotEmpty) ||
              (title != null && title.isNotEmpty) ||
              mergedTags.isNotEmpty) {
            await _localDb.updateDumpDetails(
              dump.id,
              title: title,
              aiSummary: summary,
              tags: mergedTags.isNotEmpty ? mergedTags : null,
              syncStatus: SyncStatus.synced,
            );
            onDumpUpdated?.call(dump.id, {
              if (title != null && title.isNotEmpty) 'title': title,
              if (title != null && title.isNotEmpty) 'category': title,
              if (summary != null && summary.isNotEmpty) 'ai_summary': summary,
              if (mergedTags.isNotEmpty) 'tags': mergedTags,
              'sync_status': SyncStatus.synced.name,
              'is_processing': false,
            });
            onDumpAiGenerated?.call(dump.id, title, summary);
          }
          await TaskService().extractAndSaveTasksForDump(
            dumpId: dump.id,
            userId: dump.userId,
            capturedAt: dump.capturedAt,
            dumpTitle: title,
            content: dump.content,
            aiSummary: summary,
            aiStructuredTasks: aiStructuredTasks,
            dumpTags: mergedTags,
            availableTags: availableTags,
          );
        }
      } else {
        // Photo or Voice dump: upload media & invoke process-photo / process-voice
        final results = await _supabase.syncDumps(
          [dump],
          availableTags: availableTags,
        );
        if (_deletedIds.contains(dump.id)) {
          _supabase.deleteDump(dump.id);
          return;
        }
        if (_supabase.currentUser?.id != dump.userId) return;

        final res = results[dump.id];
        if (res != null) {
          await _localDb.updateDumpSyncStatus(dump.id, SyncStatus.synced);

          String? transcript = (res['transcript'] as String?)?.trim();
          String? title = (res['title'] as String?)?.trim();
          String? summary = (res['summary'] as String?)?.trim();
          List<String> aiTags = Dump.parseTags(res['tags']);
          List<AiExtractedTask> aiStructuredTasks =
              TaskService.parseAiTasks(res['tasks']);

          // If edge function updated DB directly or returned partial fields, check remote row
          if ((transcript == null || transcript.isEmpty) ||
              (title == null || title.isEmpty)) {
            try {
              final remoteRow = await _supabase.getDumpById(dump.id);
              if (remoteRow != null) {
                final remoteTranscript = (remoteRow['transcript'] as String?)?.trim();
                final remoteTitle = (remoteRow['title'] as String?)?.trim();
                final remoteSummary = (remoteRow['ai_summary'] as String?)?.trim();
                final remoteTags = Dump.parseTags(remoteRow['tags']);
                if ((transcript == null || transcript.isEmpty) &&
                    remoteTranscript != null &&
                    remoteTranscript.isNotEmpty) {
                  transcript = remoteTranscript;
                }
                if ((title == null || title.isEmpty) &&
                    remoteTitle != null &&
                    remoteTitle.isNotEmpty) {
                  title = remoteTitle;
                }
                if ((summary == null || summary.isEmpty) &&
                    remoteSummary != null &&
                    remoteSummary.isNotEmpty) {
                  summary = remoteSummary;
                }
                if (aiTags.isEmpty && remoteTags.isNotEmpty) {
                  aiTags = remoteTags;
                }
              }
            } catch (_) {}
          }

          if (_supabase.currentUser?.id != dump.userId) return;

          final mergedTags = Dump.parseTags([...dump.tags, ...aiTags]);
          if (mergedTags.isNotEmpty) {
            TaskService.onNewTagsDiscovered?.call(mergedTags);
          }

          // Immediately update local DB & UI with whatever we have right now
          await _localDb.updateDumpDetails(
            dump.id,
            transcript: transcript,
            title: title,
            aiSummary: summary,
            tags: mergedTags.isNotEmpty ? mergedTags : null,
            syncStatus: SyncStatus.synced,
          );
          onDumpUpdated?.call(dump.id, {
            if (transcript != null && transcript.isNotEmpty) 'transcript': transcript,
            if (title != null && title.isNotEmpty) 'title': title,
            if (title != null && title.isNotEmpty) 'category': title,
            if (summary != null && summary.isNotEmpty) 'ai_summary': summary,
            if (mergedTags.isNotEmpty) 'tags': mergedTags,
            'sync_status': SyncStatus.synced.name,
          });
          if ((title != null && title.isNotEmpty) ||
              (summary != null && summary.isNotEmpty)) {
            onDumpAiGenerated?.call(dump.id, title, summary);
          }

          await TaskService().extractAndSaveTasksForDump(
            dumpId: dump.id,
            userId: dump.userId,
            capturedAt: dump.capturedAt,
            dumpTitle: title,
            content: dump.content,
            transcript: transcript,
            aiSummary: summary,
            aiStructuredTasks: aiStructuredTasks,
            dumpTags: mergedTags,
            availableTags: availableTags,
          );

          // Ensure AI summary & tasks are generated using combined user note + transcript/OCR
          final hasUserNote =
              dump.content != null && dump.content!.trim().isNotEmpty;
          final combinedText = [
            if (hasUserNote) dump.content!.trim(),
            if (transcript != null && transcript.isNotEmpty) transcript,
          ].join('\n\n');

          if (!_deletedIds.contains(dump.id) &&
              _supabase.currentUser?.id == dump.userId &&
              combinedText.isNotEmpty &&
              ((title == null || title.isEmpty) ||
                  (summary == null || summary.isEmpty) ||
                  (hasUserNote && aiStructuredTasks.isEmpty))) {
            try {
              final genResult = await _supabase.generateDumpSummaryAndTitle(
                dump.id,
                dump.userId,
                content: combinedText,
                type: dump.type.name,
                availableTags: availableTags,
                existingTags: mergedTags,
              );
              if (!_deletedIds.contains(dump.id) &&
                  _supabase.currentUser?.id == dump.userId &&
                  genResult != null) {
                final genTitle = genResult['title']?.trim();
                final genSummary = genResult['summary']?.trim();
                final genTags = Dump.parseTags([
                  ...mergedTags,
                  ...Dump.parseTags(genResult['tags_json']),
                ]);
                final genStructuredTasks =
                    TaskService.parseAiTasks(genResult['tasks_json']);
                if (genTags.isNotEmpty) {
                  TaskService.onNewTagsDiscovered?.call(genTags);
                }
                if ((genTitle != null && genTitle.isNotEmpty) ||
                    (genSummary != null && genSummary.isNotEmpty) ||
                    genTags.isNotEmpty) {
                  await _localDb.updateDumpDetails(
                    dump.id,
                    title: genTitle,
                    aiSummary: genSummary,
                    tags: genTags.isNotEmpty ? genTags : null,
                    syncStatus: SyncStatus.synced,
                  );
                  onDumpUpdated?.call(dump.id, {
                    if (genTitle != null && genTitle.isNotEmpty) 'title': genTitle,
                    if (genTitle != null && genTitle.isNotEmpty) 'category': genTitle,
                    if (genSummary != null && genSummary.isNotEmpty) 'ai_summary': genSummary,
                    if (genTags.isNotEmpty) 'tags': genTags,
                    'sync_status': SyncStatus.synced.name,
                    'is_processing': false,
                  });
                  onDumpAiGenerated?.call(dump.id, genTitle, genSummary);
                }
                await TaskService().extractAndSaveTasksForDump(
                  dumpId: dump.id,
                  userId: dump.userId,
                  capturedAt: dump.capturedAt,
                  dumpTitle: genTitle ?? title,
                  content: dump.content,
                  transcript: transcript,
                  aiSummary: genSummary ?? summary,
                  aiStructuredTasks: genStructuredTasks,
                  dumpTags: genTags,
                  availableTags: availableTags,
                );
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Background sync/summarize failed: $e');
    } finally {
      _processingIds.remove(dump.id);
      if (!_deletedIds.contains(dump.id) &&
          _supabase.currentUser?.id == dump.userId) {
        onDumpUpdated?.call(dump.id, {'is_processing': false});
      }
    }
  }

  /// Immediately syncs all pending dumps and generates any missing summaries & titles
  Future<void> syncPendingDumps() async {
    try {
      if (!SubscriptionService().isPro) {
        debugPrint('[CaptureService] Free Tier active: Cloud sync disabled. Dumps stored 100% locally.');
        return;
      }
      final userId = _supabase.currentUser?.id;
      if (userId == null || userId.isEmpty) return;

      final pendingDumps = (await _localDb.getPendingDumps(userId: userId))
          .where((d) =>
              d.userId == userId &&
              !_deletedIds.contains(d.id) &&
              !_processingIds.contains(d.id))
          .toList();

      for (final dump in pendingDumps) {
        if (_deletedIds.contains(dump.id)) continue;
        if (_supabase.currentUser?.id != userId) break;
        await _syncAndSummarize(dump);
      }
    } catch (e) {
      debugPrint('Sync pending dumps failed: $e');
    }
  }
}
