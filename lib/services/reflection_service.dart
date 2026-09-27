import 'package:flutter/material.dart';
import '../models/reflection_session.dart';
import '../models/insight_card.dart';
import 'supabase_service.dart';

class ReflectionService {
  static final ReflectionService _instance = ReflectionService._internal();
  factory ReflectionService() => _instance;
  ReflectionService._internal();

  final SupabaseService _supabase = SupabaseService();

  Future<ReflectionSession> generateSummary(String cycleId) async {
    final data = await _supabase.generateReflection(cycleId);
    final sessionId = data['session_id'] as String;
    final summary = data['summary'] as String? ?? '';

    return ReflectionSession(
      id: sessionId,
      cycleId: cycleId,
      userId: _supabase.currentUser?.id ?? 'local_user',
      status: SessionStatus.active,
      generatedSummary: summary,
      startedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  Future<List<ReflectionQuestion>> generateQuestions(String sessionId, {String? cycleId}) async {
    // 1. Try to fetch existing questions for this session ID
    List<Map<String, dynamic>> list = [];
    try {
      list = await _supabase.getReflectionQuestions(sessionId);
    } catch (e) {
      debugPrint('Could not fetch questions directly for $sessionId: $e');
    }
    
    // 2. If no questions exist, but a cycleId is provided (or if sessionId was actually a cycleId),
    // generate the session & questions via edge function
    if (list.isEmpty) {
      try {
        final actualCycleId = (cycleId != null && cycleId.isNotEmpty) ? cycleId : sessionId;
        final session = await generateSummary(actualCycleId);
        list = await _supabase.getReflectionQuestions(session.id);
      } catch (e) {
        debugPrint('Error generating questions via edge function: $e');
      }
    }
    
    // 3. Fallback questions if database / network is empty so the ritual always works smoothly
    if (list.isEmpty) {
      return [
        ReflectionQuestion(
          id: 'default_q1',
          sessionId: sessionId,
          position: 1,
          questionText: 'What was the most meaningful or memorable moment of your day?',
          createdAt: DateTime.now(),
        ),
        ReflectionQuestion(
          id: 'default_q2',
          sessionId: sessionId,
          position: 2,
          questionText: 'What is something you learned, navigated, or want to let go of today?',
          createdAt: DateTime.now(),
        ),
        ReflectionQuestion(
          id: 'default_q3',
          sessionId: sessionId,
          position: 3,
          questionText: 'What is your primary intention, priority, or mindset focus for tomorrow?',
          createdAt: DateTime.now(),
        ),
      ];
    }

    return list.map((q) => ReflectionQuestion(
      id: q['id'] as String? ?? 'q_${q['position']}',
      sessionId: q['session_id'] as String? ?? sessionId,
      position: (q['position'] as num?)?.toInt() ?? 1,
      questionText: q['question_text'] as String? ?? 'What is on your mind tonight?',
      createdAt: DateTime.tryParse(q['created_at']?.toString() ?? '') ?? DateTime.now(),
    )).toList();
  }

  Future<InsightCard> generateInsightCard(String sessionId, List<ReflectionAnswer> answers) async {
    // 1. Submit answers to DB
    for (final ans in answers) {
      final text = (ans.answerText != null && ans.answerText!.trim().isNotEmpty)
          ? ans.answerText!.trim()
          : ((ans.transcript != null && ans.transcript!.trim().isNotEmpty) ? ans.transcript!.trim() : 'Reflected on this question.');
      final type = ans.answerType.name;
      try {
        await _supabase.submitReflectionAnswer(ans.questionId, text, answerType: type);
      } catch (e) {
        debugPrint('Could not submit answer to Supabase: $e');
      }
    }

    // 2. Call generate-insight edge function
    final data = await _supabase.generateInsight(sessionId);
    final cardData = data['insight_card'];

    if (cardData != null) {
      return InsightCard(
        id: cardData['id'] as String? ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: cardData['session_id'] as String? ?? sessionId,
        userId: cardData['user_id'] as String? ?? (_supabase.currentUser?.id ?? 'user'),
        title: cardData['title'] as String? ?? 'Daily Insight',
        mainInsight: cardData['main_insight'] as String? ?? 'A mindful pause brings clarity to your days.',
        standout: cardData['standout'] as String? ?? 'Reflecting with consistency and intention.',
        suggestion: cardData['suggestion'] as String? ?? 'Carry today’s lessons into tomorrow.',
        createdAt: DateTime.tryParse(cardData['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
    }

    // Fallback card if needed
    return InsightCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      userId: _supabase.currentUser?.id ?? 'user',
      title: 'Daily Reflection Complete',
      mainInsight: 'You took time to honor your thoughts and process today’s experiences.',
      standout: 'Completing today’s reflection ritual.',
      suggestion: 'Rest well and begin tomorrow with intention.',
      createdAt: DateTime.now(),
    );
  }
}
