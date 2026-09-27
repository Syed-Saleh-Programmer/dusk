import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/dump.dart';
import 'local_db_service.dart';
import 'supabase_service.dart';
import 'task_service.dart';

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

  /// Callback registered by AppState to receive immediate field updates (sync_status, transcript, title, ai_summary, is_processing)
  static void Function(String dumpId, Map<String, dynamic> updatedFields)? onDumpUpdated;

  /// Captures a text dump, saves locally, and returns the Dump immediately.
  /// Cloud sync and AI summary happen in the background without delay.
  Future<Dump> captureText(String content) async {
    final userId = _supabase.currentUser?.id ?? (throw Exception('User must be logged in to capture.'));
    final now = DateTime.now();

    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.text,
      content: content,
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
      ),
    );
    // Fire-and-forget: sync and AI summary immediately in background
    _syncAndSummarize(dump);
    return dump;
  }

  /// Captures a voice dump, saves locally, and returns the Dump immediately.
  /// Cloud sync and AI summary happen in the background.
  Future<Dump> captureVoice(String mediaUrl, String transcript) async {
    final userId = _supabase.currentUser?.id ?? (throw Exception('User must be logged in to capture.'));
    final now = DateTime.now();

    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.voice,
      mediaUrl: mediaUrl,
      transcript: transcript,
      capturedAt: now,
      createdAt: now,
      syncStatus: SyncStatus.pending,
    );

    _processingIds.add(dump.id);
    await _localDb.insertDump(dump);
    if (transcript.trim().isNotEmpty) {
      unawaited(
        TaskService().extractAndSaveTasksForDump(
          dumpId: dump.id,
          userId: userId,
          capturedAt: now,
          transcript: transcript,
        ),
      );
    }
    // Fire-and-forget: sync and AI summary in background
    _syncAndSummarize(dump);
    return dump;
  }
  
  /// Captures a photo dump, saves locally, and returns the Dump immediately.
  /// Cloud sync and AI summary happen in the background.
  Future<Dump> capturePhoto(String mediaUrl) async {
    final userId = _supabase.currentUser?.id ?? (throw Exception('User must be logged in to capture.'));
    final now = DateTime.now();

    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.photo,
      mediaUrl: mediaUrl,
      capturedAt: now,
      createdAt: now,
      syncStatus: SyncStatus.pending,
    );

    _processingIds.add(dump.id);
    await _localDb.insertDump(dump);
    // Fire-and-forget: sync and AI summary in background
    _syncAndSummarize(dump);
    return dump;
  }

  /// Background task: sync to cloud first, then request AI title & summary.
  /// Immediately notifies AppState at each stage so cards re-render in real time.
  Future<void> _syncAndSummarize(Dump dump) async {
    if (_deletedIds.contains(dump.id)) return;
    if (_supabase.currentUser?.id != dump.userId) return;
    _processingIds.add(dump.id);
    onDumpUpdated?.call(dump.id, {'is_processing': true});

    try {
      if (dump.type == DumpType.text) {
        // 1. Sync text dump to Supabase
        final syncRes = await _supabase.syncDumps([dump]);
        if (_deletedIds.contains(dump.id)) {
          _supabase.deleteDump(dump.id);
          return;
        }
        if (_supabase.currentUser?.id != dump.userId) return;

        if (syncRes.containsKey(dump.id)) {
          await _localDb.updateDumpSyncStatus(dump.id, SyncStatus.synced);
          onDumpUpdated?.call(dump.id, {'sync_status': SyncStatus.synced.name});
        }

        // 2. Generate summary & title
        try {
          final result = await _supabase.generateDumpSummaryAndTitle(
            dump.id,
            dump.userId,
            content: dump.content,
            type: dump.type.name,
          );

          if (_deletedIds.contains(dump.id)) return;
          if (_supabase.currentUser?.id != dump.userId) return;

          if (result != null) {
            final summary = result['summary']?.trim();
            final title = result['title']?.trim();
            final aiTasks = TaskService.parseTaskStrings(result['tasks_json']);
            if ((summary != null && summary.isNotEmpty) ||
                (title != null && title.isNotEmpty)) {
              await _localDb.updateDumpDetails(
                dump.id,
                title: title,
                aiSummary: summary,
                syncStatus: SyncStatus.synced,
              );
              onDumpUpdated?.call(dump.id, {
                if (title != null && title.isNotEmpty) 'title': title,
                if (title != null && title.isNotEmpty) 'category': title,
                if (summary != null && summary.isNotEmpty) 'ai_summary': summary,
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
              aiTasks: aiTasks,
            );
          }
        } catch (e) {
          debugPrint('AI title & summary generation failed: $e');
        }
      } else {
        // Photo or Voice dump: upload media & invoke process-photo / process-voice
        final results = await _supabase.syncDumps([dump]);
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
          List<String> aiTasks = TaskService.parseTaskStrings(res['tasks']);

          // If edge function updated DB directly or returned partial fields, check remote row
          if ((transcript == null || transcript.isEmpty) ||
              (title == null || title.isEmpty)) {
            try {
              final remoteRow = await _supabase.getDumpById(dump.id);
              if (remoteRow != null) {
                final remoteTranscript = (remoteRow['transcript'] as String?)?.trim();
                final remoteTitle = (remoteRow['title'] as String?)?.trim();
                final remoteSummary = (remoteRow['ai_summary'] as String?)?.trim();
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
              }
            } catch (_) {}
          }

          if (_supabase.currentUser?.id != dump.userId) return;

          // Immediately update local DB & UI with whatever we have right now
          await _localDb.updateDumpDetails(
            dump.id,
            transcript: transcript,
            title: title,
            aiSummary: summary,
            syncStatus: SyncStatus.synced,
          );
          onDumpUpdated?.call(dump.id, {
            if (transcript != null && transcript.isNotEmpty) 'transcript': transcript,
            if (title != null && title.isNotEmpty) 'title': title,
            if (title != null && title.isNotEmpty) 'category': title,
            if (summary != null && summary.isNotEmpty) 'ai_summary': summary,
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
            aiTasks: aiTasks,
          );

          // Fallback: if transcript was extracted but title/summary is still missing, generate it now
          if (!_deletedIds.contains(dump.id) &&
              _supabase.currentUser?.id == dump.userId &&
              transcript != null &&
              transcript.isNotEmpty &&
              ((title == null || title.isEmpty) ||
                  (summary == null || summary.isEmpty))) {
            try {
              final genResult = await _supabase.generateDumpSummaryAndTitle(
                dump.id,
                dump.userId,
                content: transcript,
                type: dump.type.name,
              );
              if (!_deletedIds.contains(dump.id) &&
                  _supabase.currentUser?.id == dump.userId &&
                  genResult != null) {
                final genTitle = genResult['title']?.trim();
                final genSummary = genResult['summary']?.trim();
                final genTasks = TaskService.parseTaskStrings(genResult['tasks_json']);
                if ((genTitle != null && genTitle.isNotEmpty) ||
                    (genSummary != null && genSummary.isNotEmpty)) {
                  await _localDb.updateDumpDetails(
                    dump.id,
                    title: genTitle,
                    aiSummary: genSummary,
                    syncStatus: SyncStatus.synced,
                  );
                  onDumpUpdated?.call(dump.id, {
                    if (genTitle != null && genTitle.isNotEmpty) 'title': genTitle,
                    if (genTitle != null && genTitle.isNotEmpty) 'category': genTitle,
                    if (genSummary != null && genSummary.isNotEmpty) 'ai_summary': genSummary,
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
                  aiTasks: genTasks,
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
