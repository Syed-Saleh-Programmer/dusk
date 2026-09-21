import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dump.dart';
import '../models/reflection_cycle.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // Dumps
  Future<void> syncDumps(List<Dump> dumps) async {
    for (final dump in dumps) {
      String? uploadedMediaUrl;

      // 1. Upload Media to Storage if necessary
      if ((dump.type == DumpType.voice || dump.type == DumpType.photo) && dump.mediaUrl != null) {
        try {
          final file = File(dump.mediaUrl!);
          final fileName = '${dump.id}.${dump.type == DumpType.voice ? "m4a" : "jpg"}';
          final storagePath = '${currentUser?.id}/dumps/$fileName';

          await _client.storage.from('user-media').upload(storagePath, file);
          uploadedMediaUrl = storagePath;
        } catch (e) {
          // If upload fails, we skip syncing this dump for now
          print('Failed to upload media for dump ${dump.id}: $e');
          continue; 
        }
      }

      // 2. Insert row into dumps table
      try {
        await _client.from('dumps').insert({
          'id': dump.id,
          'user_id': dump.userId,
          'type': dump.type.name,
          'content': dump.content,
          'transcript': dump.transcript,
          'media_url': uploadedMediaUrl ?? dump.mediaUrl, // use remote path if uploaded
          'category': dump.category,
          'captured_at': dump.capturedAt.toIso8601String(),
          'sync_status': 'synced'
        });

        // 3. Trigger Edge Function if needed (process-voice or process-photo)
        if (dump.type == DumpType.voice && uploadedMediaUrl != null) {
          await _client.functions.invoke('process-voice', body: {
            'dump_id': dump.id,
            'file_path': uploadedMediaUrl
          });
        } else if (dump.type == DumpType.photo && uploadedMediaUrl != null) {
          await _client.functions.invoke('process-photo', body: {
            'dump_id': dump.id,
            'file_path': uploadedMediaUrl
          });
        }
      } catch (e) {
        print('Failed to insert dump ${dump.id}: $e');
      }
    }
  }

  Future<ReflectionCycle?> getOrCreateCurrentCycle() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    // See if there's an active or pending cycle today
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

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
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getReflectionQuestions(String sessionId) async {
    final res = await _client.from('reflection_questions').select().eq('session_id', sessionId).order('position');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> submitReflectionAnswer(String questionId, String answerText) async {
    await _client.from('reflection_answers').insert({
      'question_id': questionId,
      'answer_text': answerText,
    });
  }

  Future<Map<String, dynamic>> generateInsight(String sessionId) async {
    final res = await _client.functions.invoke('generate-insight', body: {
      'session_id': sessionId,
      'user_id': currentUser!.id,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getInsightCards() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _client.from('insight_cards').select().eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Mocks for Auth since we don't have real credentials yet
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}
