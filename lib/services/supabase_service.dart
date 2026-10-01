import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dump.dart';
import '../models/reflection_cycle.dart';
import '../models/task_item.dart';
import '../models/project.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Map<String, dynamic>? _parseEdgeResponse(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  String _resolveStorageExt(DumpType type, String path) {
    final rawExt = path.contains('.')
        ? path.split('.').last.toLowerCase().trim()
        : '';
    if (type == DumpType.voice) {
      switch (rawExt) {
        case 'mp3':
        case 'mpeg':
        case 'mpga':
          return 'mp3';
        case 'wav':
          return 'wav';
        case 'ogg':
        case 'opus':
          return 'ogg';
        case 'flac':
          return 'flac';
        case 'webm':
          return 'webm';
        case 'mp4':
          return 'mp4';
        case 'm4a':
        case 'aac':
        case '3gp':
        case '3gpp':
        case 'amr':
        default:
          return 'm4a';
      }
    } else {
      switch (rawExt) {
        case 'png':
          return 'png';
        case 'webp':
          return 'webp';
        case 'gif':
          return 'gif';
        case 'jpg':
        case 'jpeg':
        default:
          return 'jpg';
      }
    }
  }

  String _resolveMimeType(DumpType type, String ext) {
    if (type == DumpType.voice) {
      switch (ext) {
        case 'mp3':
          return 'audio/mpeg';
        case 'wav':
          return 'audio/wav';
        case 'ogg':
          return 'audio/ogg';
        case 'flac':
          return 'audio/flac';
        case 'webm':
          return 'audio/webm';
        case 'mp4':
        case 'm4a':
        default:
          return 'audio/mp4';
      }
    } else {
      switch (ext) {
        case 'png':
          return 'image/png';
        case 'webp':
          return 'image/webp';
        case 'gif':
          return 'image/gif';
        case 'jpg':
        default:
          return 'image/jpeg';
      }
    }
  }

  // Dumps
  Future<Map<String, Map<String, dynamic>>> syncDumps(
    List<Dump> dumps, {
    List<String>? availableTags,
  }) async {
    final Map<String, Map<String, dynamic>> results = {};
    final activeUserId = currentUser?.id;
    if (activeUserId == null) return results;

    for (final dump in dumps) {
      if (dump.userId.isNotEmpty && dump.userId != activeUserId) {
        continue;
      }
      String? uploadedMediaUrl;
      String? resolvedMimeType;

      // 1. Upload Media to Storage if necessary
      if ((dump.type == DumpType.voice || dump.type == DumpType.photo) && dump.mediaUrl != null) {
        try {
          final isLocal = dump.mediaUrl!.startsWith('/') || dump.mediaUrl!.contains(r':\');
          if (isLocal && File(dump.mediaUrl!).existsSync()) {
            final file = File(dump.mediaUrl!);
            final fileExt = _resolveStorageExt(dump.type, dump.mediaUrl!);
            resolvedMimeType = _resolveMimeType(dump.type, fileExt);
            final fileName = '${dump.id}.$fileExt';
            final storagePath = '$activeUserId/dumps/$fileName';

            await _client.storage.from('user-media').upload(
              storagePath,
              file,
              fileOptions: FileOptions(
                upsert: true,
                contentType: resolvedMimeType,
              ),
            );
            uploadedMediaUrl = storagePath;
          } else if (!isLocal) {
            uploadedMediaUrl = dump.mediaUrl;
            final ext = _resolveStorageExt(dump.type, dump.mediaUrl!);
            resolvedMimeType = _resolveMimeType(dump.type, ext);
          }
        } catch (e) {
          debugPrint('Failed to upload media for dump ${dump.id}: $e');
          continue; 
        }
      }

      // 2. Insert or Upsert row into dumps table
      try {
        final payload = <String, dynamic>{
          'id': dump.id,
          'user_id': activeUserId,
          'type': dump.type.name,
          'title': dump.title,
          'content': dump.content,
          'transcript': dump.transcript,
          'media_url': uploadedMediaUrl ?? dump.mediaUrl, // use remote path if uploaded
          'category': dump.category,
          if (dump.projectId != null && dump.projectId!.isNotEmpty)
            'project_id': dump.projectId,
          'tags': dump.tags,
          'captured_at': dump.capturedAt.toUtc().toIso8601String(),
          'sync_status': 'synced',
          'ai_summary': dump.aiSummary,
        };

        try {
          await _client.from('dumps').upsert(payload);
        } catch (upsertErr) {
          final errStr = upsertErr.toString();
          if (errStr.contains('tags') || errStr.contains('project_id')) {
            final fallbackPayload = Map<String, dynamic>.from(payload);
            if (errStr.contains('tags')) fallbackPayload.remove('tags');
            if (errStr.contains('project_id')) fallbackPayload.remove('project_id');
            await _client.from('dumps').upsert(fallbackPayload);
          } else {
            rethrow;
          }
        }

        results[dump.id] = {'synced': true};

        // 3. Trigger Edge Function if needed (process-voice or process-photo)
        try {
          if (dump.type == DumpType.voice && uploadedMediaUrl != null) {
            final res = await _client.functions.invoke('process-voice', body: {
              'dump_id': dump.id,
              'file_path': uploadedMediaUrl,
              'mime_type': ?resolvedMimeType,
              if (dump.content != null && dump.content!.trim().isNotEmpty)
                'content': dump.content!.trim(),
              if (dump.tags.isNotEmpty) 'existing_tags': dump.tags,
              if (availableTags != null && availableTags.isNotEmpty)
                'available_tags': availableTags,
            });
            final data = _parseEdgeResponse(res.data);
            if (data != null) {
              results[dump.id] = {
                'synced': true,
                'transcript': data['transcript'] as String?,
                'title': data['title'] as String?,
                'summary': data['summary'] as String?,
                'tags': data['tags'],
                'tasks': data['tasks'],
              };
            }
          } else if (dump.type == DumpType.photo && uploadedMediaUrl != null) {
            final res = await _client.functions.invoke('process-photo', body: {
              'dump_id': dump.id,
              'file_path': uploadedMediaUrl,
              'mime_type': ?resolvedMimeType,
              if (dump.content != null && dump.content!.trim().isNotEmpty)
                'content': dump.content!.trim(),
              if (dump.tags.isNotEmpty) 'existing_tags': dump.tags,
              if (availableTags != null && availableTags.isNotEmpty)
                'available_tags': availableTags,
            });
            final data = _parseEdgeResponse(res.data);
            if (data != null) {
              results[dump.id] = {
                'synced': true,
                'transcript': data['transcript'] as String?,
                'title': data['title'] as String?,
                'summary': data['summary'] as String?,
                'tags': data['tags'],
                'tasks': data['tasks'],
              };
            }
          }
        } catch (edgeErr) {
          debugPrint('Edge function processing error for dump ${dump.id}: $edgeErr');
        }
      } catch (e) {
        debugPrint('Failed to insert/process dump ${dump.id}: $e');
      }
    }
    return results;
  }

  Future<bool> updateDumpTags(String dumpId, List<String> tags) async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    try {
      await _client
          .from('dumps')
          .update({'tags': Dump.parseTags(tags)})
          .eq('id', dumpId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Supabase updateDumpTags error: $e');
      return false;
    }
  }

  Future<void> deleteDump(String dumpId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    // First try to delete media from storage
    try {
      final dump = await _client
          .from('dumps')
          .select()
          .eq('id', dumpId)
          .eq('user_id', userId)
          .maybeSingle();
      if (dump != null &&
          dump['media_url'] != null &&
          !dump['media_url'].toString().startsWith('http') &&
          !dump['media_url'].toString().startsWith('/')) {
        await _client.storage.from('user-media').remove([dump['media_url']]);
      }
    } catch (_) {}
    // Delete associated tasks if table exists
    try {
      await _client.from('tasks').delete().eq('dump_id', dumpId).eq('user_id', userId);
    } catch (_) {}
    // Delete the dump record scoped to the authenticated user
    await _client.from('dumps').delete().eq('id', dumpId).eq('user_id', userId);
  }

  Future<void> deleteDumps(List<String> dumpIds) async {
    final userId = currentUser?.id;
    if (userId == null || dumpIds.isEmpty) return;
    try {
      final dumps = await _client
          .from('dumps')
          .select('id, media_url')
          .inFilter('id', dumpIds)
          .eq('user_id', userId);
      final mediaPaths = <String>[];
      for (final d in dumps) {
        final mUrl = d['media_url']?.toString();
        if (mUrl != null && !mUrl.startsWith('http') && !mUrl.startsWith('/')) {
          mediaPaths.add(mUrl);
        }
      }
      if (mediaPaths.isNotEmpty) {
        try {
          await _client.storage.from('user-media').remove(mediaPaths);
        } catch (_) {}
      }

      try {
        await _client
            .from('tasks')
            .delete()
            .inFilter('dump_id', dumpIds)
            .eq('user_id', userId);
      } catch (_) {}

      await _client
          .from('dumps')
          .delete()
          .inFilter('id', dumpIds)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase deleteDumps error: $e');
    }
  }

  Future<String> getSignedUrl(String path) async {
    return await _client.storage.from('user-media').createSignedUrl(path, 60 * 60 * 24 * 7);
  }

  Future<List<Map<String, dynamic>>> getAllDumps() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    
    final res = await _client
        .from('dumps')
        .select()
        .eq('user_id', userId)
        .order('captured_at', ascending: false);
        
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getDumpsForCycle(DateTime start, DateTime end) async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    
    final res = await _client
        .from('dumps')
        .select()
        .eq('user_id', userId)
        .gte('captured_at', start.toUtc().toIso8601String())
        .lte('captured_at', end.toUtc().toIso8601String())
        .order('captured_at', ascending: true);
        
    return List<Map<String, dynamic>>.from(res);
  }

  Future<ReflectionCycle?> getOrCreateCurrentCycle() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    // See if there's an active or pending cycle today
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc();

    final res = await _client
        .from('reflection_cycles')
        .select()
        .eq('user_id', userId)
        .gte('period_start', startOfDay.toIso8601String())
        .lte('period_end', endOfDay.toIso8601String())
        .limit(1)
        .maybeSingle();

    if (res != null) {
      return ReflectionCycle.fromMap(res);
    }

    // Create a new cycle for today
    final newCycle = {
      'user_id': userId,
      'period_start': startOfDay.toIso8601String(),
      'period_end': endOfDay.toIso8601String(),
      'status': 'pending',
    };

    final insertRes = await _client.from('reflection_cycles').insert(newCycle).select().single();
    return ReflectionCycle.fromMap(insertRes);
  }

  Future<Map<String, dynamic>> generateReflection(String cycleId) async {
    final res = await _client.functions.invoke('generate-reflection', body: {
      'cycle_id': cycleId,
      'user_id': currentUser!.id,
    });
    final parsed = _parseEdgeResponse(res.data);
    if (parsed == null) throw Exception('Invalid response from generate-reflection: ${res.data}');
    return parsed;
  }

  Future<List<Map<String, dynamic>>> getReflectionQuestions(String sessionId) async {
    final res = await _client.from('reflection_questions').select().eq('session_id', sessionId).order('position');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> submitReflectionAnswer(String questionId, String answerText, {String answerType = 'text'}) async {
    await _client.from('reflection_answers').insert({
      'question_id': questionId,
      'user_id': currentUser!.id,
      'answer_type': answerType,
      'answer_text': answerText,
    });
  }

  Future<Map<String, dynamic>> generateInsight(
    String sessionId, {
    List<String>? availableTags,
  }) async {
    final res = await _client.functions.invoke('generate-insight', body: {
      'session_id': sessionId,
      'user_id': currentUser!.id,
      if (availableTags != null && availableTags.isNotEmpty)
        'available_tags': availableTags,
    });
    final parsed = _parseEdgeResponse(res.data);
    if (parsed == null) throw Exception('Invalid response from generate-insight: ${res.data}');
    return parsed;
  }

  Future<List<Map<String, dynamic>>> getInsightCards() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _client.from('insight_cards').select().eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> toggleInsightBookmark(String insightId, bool isBookmarked) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client
        .from('insight_cards')
        .update({'is_bookmarked': isBookmarked})
        .eq('id', insightId)
        .eq('user_id', userId);
  }

  Future<User> signIn(String email, String password) async {
    final cleanEmail = email.trim();
    // If another user is currently signed in, sign out first so state never bleeds
    if (currentUser != null &&
        currentUser?.email?.toLowerCase() != cleanEmail.toLowerCase()) {
      await _client.auth.signOut();
    }
    final res = await _client.auth.signInWithPassword(
      email: cleanEmail,
      password: password,
    );
    final user = res.user ?? currentUser;
    if (user == null || (res.session == null && _client.auth.currentSession == null)) {
      throw const AuthException(
        'Unable to sign in. Please verify your email and password.',
      );
    }
    return user;
  }

  Future<User> signUp(String email, String password) async {
    final cleanEmail = email.trim();
    // Always clear any existing session before creating a new account
    if (currentUser != null) {
      await _client.auth.signOut();
    }
    final res = await _client.auth.signUp(
      email: cleanEmail,
      password: password,
    );

    // Detect duplicate signup when email already exists (empty identities list)
    if (res.user != null &&
        res.user!.identities != null &&
        res.user!.identities!.isEmpty) {
      throw const AuthException(
        'An account with this email already exists. Please log in instead.',
      );
    }

    // If signUp did not immediately attach a session, sign in with the credentials
    if (res.session == null && res.user != null) {
      await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
    }

    final user = currentUser ?? res.user;
    if (user == null || _client.auth.currentSession == null) {
      throw const AuthException(
        'Could not establish a session for the new account. Please try logging in.',
      );
    }
    return user;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Uploads a profile avatar image to Supabase Storage and returns the storage path or signed URL.
  Future<String?> uploadProfileAvatar(File imageFile) async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final ext = imageFile.path.split('.').last.toLowerCase();
    final safeExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';
    final storagePath = '$userId/profile/avatar.$safeExt';

    await _client.storage.from('user-media').upload(
      storagePath,
      imageFile,
      fileOptions: const FileOptions(upsert: true),
    );

    final signedUrl = await _client.storage
        .from('user-media')
        .createSignedUrl(storagePath, 60 * 60 * 24 * 365);
    return signedUrl;
  }

  /// Updates the user's profile metadata in Supabase Auth.
  Future<void> updateUserProfile({
    required String preferredName,
    String? profession,
    DateTime? dob,
    String? avatarUrl,
    bool clearDob = false,
    bool clearAvatar = false,
  }) async {
    if (currentUser == null) return;

    final existingData = Map<String, dynamic>.from(
      currentUser?.userMetadata ?? {},
    );

    existingData['full_name'] = preferredName.trim();
    existingData['preferred_name'] = preferredName.trim();
    existingData['profile_setup_completed'] = true;

    if (profession != null) {
      existingData['profession'] = profession.trim();
    }

    if (clearDob) {
      existingData['dob'] = null;
    } else if (dob != null) {
      existingData['dob'] = dob.toIso8601String().split('T').first;
    }

    if (clearAvatar) {
      existingData['avatar_url'] = null;
    } else if (avatarUrl != null) {
      existingData['avatar_url'] = avatarUrl;
    }

    await _client.auth.updateUser(
      UserAttributes(data: existingData),
    );
  }

  /// Syncs the user's custom tags to Supabase Auth metadata.
  Future<void> updateUserCustomTags(List<String> customTags) async {
    final user = currentUser;
    if (user == null) return;
    final existingData = Map<String, dynamic>.from(user.userMetadata ?? {});
    existingData['custom_tags'] = Dump.parseTags(customTags);
    try {
      await _client.auth.updateUser(
        UserAttributes(data: existingData),
      );
    } catch (e) {
      debugPrint('Failed to sync custom tags to Supabase Auth: $e');
    }
  }

  /// Syncs the user's reflection schedule and alarm sound preferences to Supabase Auth metadata & reflection_schedule table.
  Future<void> updateUserScheduleSettings({
    int? cadenceDays,
    int? reminderHour,
    int? reminderMinute,
    String? alarmSoundId,
    List<Map<String, dynamic>>? multiRituals,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final existingData = Map<String, dynamic>.from(user.userMetadata ?? {});
    if (cadenceDays != null) {
      existingData['reflection_cadence_days'] = cadenceDays;
    }
    if (reminderHour != null) {
      existingData['reflection_reminder_hour'] = reminderHour;
    }
    if (reminderMinute != null) {
      existingData['reflection_reminder_minute'] = reminderMinute;
    }
    if (alarmSoundId != null && alarmSoundId.isNotEmpty) {
      existingData['selected_alarm_sound_id'] = alarmSoundId;
    }
    if (multiRituals != null) {
      existingData['multi_rituals'] = multiRituals;
    }

    try {
      await _client.auth.updateUser(
        UserAttributes(data: existingData),
      );
    } catch (e) {
      debugPrint('Failed to sync schedule metadata to Supabase Auth: $e');
    }

    if (cadenceDays != null && reminderHour != null && reminderMinute != null) {
      try {
        final hh = reminderHour.toString().padLeft(2, '0');
        final mm = reminderMinute.toString().padLeft(2, '0');
        await _client.from('reflection_schedule').upsert(
          {
            'user_id': user.id,
            'cadence_days': cadenceDays,
            'reminder_time': '$hh:$mm:00',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      } catch (_) {}
    }
  }

  /// Check if the device has internet connectivity
  Future<bool> hasConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Get a single dump from Supabase by ID
  Future<Map<String, dynamic>?> getDumpById(String dumpId) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return null;
      final res = await _client
          .from('dumps')
          .select()
          .eq('id', dumpId)
          .eq('user_id', userId)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Generate AI summary and title for a single dump via edge function
  Future<Map<String, String?>?> generateDumpSummaryAndTitle(
    String dumpId,
    String userId, {
    String? content,
    String? type,
    List<String>? availableTags,
    List<String>? existingTags,
  }) async {
    try {
      final res = await _client.functions.invoke('generate-dump-summary', body: {
        'dump_id': dumpId,
        'user_id': userId,
        if (content != null && content.isNotEmpty) 'content': content,
        if (type != null && type.isNotEmpty) 'type': type,
        if (availableTags != null && availableTags.isNotEmpty)
          'available_tags': availableTags,
        if (existingTags != null && existingTags.isNotEmpty)
          'existing_tags': existingTags,
      });
      final data = _parseEdgeResponse(res.data);
      if (data != null) {
        String? tasksJson;
        if (data['tasks'] is List) {
          tasksJson = jsonEncode(data['tasks']);
        }
        String? tagsJson;
        if (data['tags'] is List) {
          tagsJson = jsonEncode(data['tags']);
        }
        return {
          'title': data['title'] as String?,
          'summary': data['summary'] as String?,
          'tags_json': ?tagsJson,
          'tasks_json': ?tasksJson,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Failed to generate dump summary: $e');
      return null;
    }
  }

  /// Generate an AI summary for a single dump via edge function
  Future<String?> generateDumpSummary(
    String dumpId,
    String userId, {
    String? content,
    String? type,
  }) async {
    final result = await generateDumpSummaryAndTitle(
      dumpId,
      userId,
      content: content,
      type: type,
    );
    return result?['summary'];
  }

  // ===========================================================================
  // Tasks (Extracted from Dumps, Gentle Next Steps from Insight Cards, Manual)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    try {
      final res = await _client
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Supabase getAllTasks error (table may not exist yet): $e');
      return [];
    }
  }

  Future<bool> upsertTask(TaskItem task) async {
    final userId = currentUser?.id;
    if (userId == null || (task.userId.isNotEmpty && task.userId != userId)) {
      return false;
    }
    final payload = task.toSupabaseMap();
    try {
      await _client.from('tasks').upsert(payload);
      return true;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('due_date') || errStr.contains('tags')) {
        try {
          final fallback = Map<String, dynamic>.from(payload);
          if (errStr.contains('due_date')) fallback.remove('due_date');
          if (errStr.contains('tags')) fallback.remove('tags');
          await _client.from('tasks').upsert(fallback);
          return true;
        } catch (_) {
          try {
            final fallbackBoth = Map<String, dynamic>.from(payload)
              ..remove('due_date')
              ..remove('tags');
            await _client.from('tasks').upsert(fallbackBoth);
            return true;
          } catch (_) {}
        }
      }
      debugPrint('Supabase upsertTask error: $e');
      return false;
    }
  }

  Future<bool> upsertTasks(List<TaskItem> tasks) async {
    final userId = currentUser?.id;
    if (userId == null || tasks.isEmpty) return false;
    final validRows = tasks
        .where((t) => t.userId == userId && t.title.trim().isNotEmpty)
        .map((t) => t.toSupabaseMap())
        .toList();
    if (validRows.isEmpty) return true;
    try {
      await _client.from('tasks').upsert(validRows);
      return true;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('due_date') || errStr.contains('tags')) {
        try {
          final fallbackRows = validRows.map((r) {
            final copy = Map<String, dynamic>.from(r);
            if (errStr.contains('due_date')) copy.remove('due_date');
            if (errStr.contains('tags')) copy.remove('tags');
            return copy;
          }).toList();
          await _client.from('tasks').upsert(fallbackRows);
          return true;
        } catch (_) {
          try {
            final fallbackBoth = validRows
                .map((r) => Map<String, dynamic>.from(r)
                  ..remove('due_date')
                  ..remove('tags'))
                .toList();
            await _client.from('tasks').upsert(fallbackBoth);
            return true;
          } catch (_) {}
        }
      }
      debugPrint('Supabase upsertTasks error: $e');
      return false;
    }
  }

  Future<void> deleteTask(String taskId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('tasks').delete().eq('id', taskId).eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase deleteTask error: $e');
    }
  }

  Future<void> deleteTasks(List<String> taskIds) async {
    final userId = currentUser?.id;
    if (userId == null || taskIds.isEmpty) return;
    try {
      await _client
          .from('tasks')
          .delete()
          .inFilter('id', taskIds)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase deleteTasks error: $e');
    }
  }

  // ===========================================================================
  // Projects
  // ===========================================================================

  Future<List<Project>> getAllProjects() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    try {
      final res = await _client
          .from('projects')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('created_at', ascending: true);
      final list = res as List<dynamic>;
      return list.map((item) => Project.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      debugPrint('Supabase getAllProjects error (table may not exist yet): $e');
      return [];
    }
  }

  Future<bool> upsertProject(Project project) async {
    final userId = currentUser?.id;
    if (userId == null || (project.userId.isNotEmpty && project.userId != userId)) {
      return false;
    }
    final payload = project.toSupabaseMap();
    try {
      await _client.from('projects').upsert(payload);
      return true;
    } catch (e) {
      debugPrint('Supabase upsertProject error: $e');
      return false;
    }
  }

  Future<void> deleteProject(String projectId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      // 1. Unlink dumps and tasks in cloud
      await _client
          .from('dumps')
          .update({'project_id': null})
          .eq('project_id', projectId)
          .eq('user_id', userId);
      await _client
          .from('tasks')
          .update({'project_id': null})
          .eq('project_id', projectId)
          .eq('user_id', userId);
      // 2. Delete project row
      await _client.from('projects').delete().eq('id', projectId).eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase deleteProject error: $e');
    }
  }

  Future<void> updateDumpProject(String dumpId, String? projectId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('dumps')
          .update({'project_id': projectId})
          .eq('id', dumpId)
          .eq('user_id', userId);
      await _client
          .from('tasks')
          .update({'project_id': projectId})
          .eq('dump_id', dumpId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase updateDumpProject error: $e');
    }
  }

  Future<void> updateTaskProject(String taskId, String? projectId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('tasks')
          .update({'project_id': projectId})
          .eq('id', taskId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase updateTaskProject error: $e');
    }
  }
}
