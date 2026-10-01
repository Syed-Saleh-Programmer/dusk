import 'package:flutter/material.dart';
import '../models/reflection_session.dart';
import '../models/insight_card.dart';
import 'local_db_service.dart';
import 'supabase_service.dart';

class ReflectionService {
  static final ReflectionService _instance = ReflectionService._internal();
  factory ReflectionService() => _instance;
  ReflectionService._internal();

  final SupabaseService _supabase = SupabaseService();
  final LocalDbService _localDb = LocalDbService();

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
      final fallbackTexts = [
        'Looking back across the past 7 days, what single moment or achievement brought you the most genuine fulfillment?',
        'Which of your pending goals or tasks feels most important right now, and what is holding you back from completing it?',
        'Connecting your recent notes and thoughts, what recurring pattern or emotion have you noticed showing up most often?',
        'What was a hidden win or subtle progress you made recently that you haven’t given yourself enough credit for?',
        'If you look at the challenges you navigated over the past week, what key lesson stands out?',
        'How well have your daily actions aligned with your core priorities and personal values this week?',
        'What project, task, or thought has been taking up unnecessary space in your mind, and how can you let it go?',
        'Who or what inspired you most recently, and how did it influence your mindset?',
        'What is one small boundary or habit change that would give you more energy and clarity starting tomorrow?',
        'Looking ahead, what is your single primary intention or focus for the upcoming days?',
      ];
      return List.generate(
        fallbackTexts.length,
        (index) => ReflectionQuestion(
          id: 'default_q${index + 1}',
          sessionId: sessionId,
          position: index + 1,
          questionText: fallbackTexts[index],
          createdAt: DateTime.now(),
        ),
      );
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
          : ((ans.transcript != null && ans.transcript!.trim().isNotEmpty) ? ans.transcript!.trim() : 'Skipped reflection prompt.');
      final type = ans.answerType.name;
      try {
        await _supabase.submitReflectionAnswer(ans.questionId, text, answerType: type);
      } catch (e) {
        debugPrint('Could not submit answer to Supabase: $e');
      }
    }

    // 2. Call generate-insight edge function
    Map<String, dynamic>? data;
    try {
      data = await _supabase.generateInsight(sessionId);
    } catch (e) {
      debugPrint('Notice calling generateInsight edge function: $e');
    }
    final cardData = data?['insight_card'];

    List<String>? parsedNextActions;
    if (cardData != null && cardData['next_actions'] != null) {
      if (cardData['next_actions'] is List) {
        parsedNextActions = (cardData['next_actions'] as List).map((e) => e.toString()).toList();
      } else if (cardData['next_actions'] is String) {
        parsedNextActions = [cardData['next_actions'].toString()];
      }
    }

    final card = (cardData != null)
        ? InsightCard(
            id: cardData['id'] as String? ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
            sessionId: cardData['session_id'] as String? ?? sessionId,
            userId: cardData['user_id'] as String? ?? (_supabase.currentUser?.id ?? 'local_user'),
            title: cardData['title'] as String? ?? 'Weekly Reflection Summary',
            mainInsight: cardData['main_insight'] as String? ?? 'A mindful pause brings clarity to your days.',
            standout: cardData['standout'] as String? ?? 'Reflecting with consistency and intention.',
            suggestion: cardData['suggestion'] as String? ?? 'Carry today’s lessons into tomorrow.',
            weekOverview: cardData['week_overview'] as String?,
            progressAndWins: cardData['progress_and_wins'] as String?,
            motivation: cardData['motivation'] as String?,
            nextActions: parsedNextActions,
            createdAt: DateTime.tryParse(cardData['created_at']?.toString() ?? '') ?? DateTime.now(),
          )
        : InsightCard(
            id: 'card_${DateTime.now().millisecondsSinceEpoch}',
            sessionId: sessionId,
            userId: _supabase.currentUser?.id ?? 'local_user',
            title: 'Weekly Reflection Complete',
            mainInsight: 'You took time to honor your thoughts and process today’s experiences.',
            standout: 'Completing your weekly reflection ritual.',
            suggestion: 'Rest well and begin tomorrow with intention.',
            weekOverview: 'A week of captured thoughts, progress on goals, and thoughtful learning.',
            progressAndWins: 'Dedicated time to synthesize your past week and identify next steps.',
            motivation: 'Trust your vision and carry this clarity forward.',
            nextActions: const ['Review your pending action items for tomorrow.'],
            createdAt: DateTime.now(),
          );

    // Save locally into SQLite so 100% offline Free users have immediate access in HistoryScreen
    try {
      await _localDb.insertLocalInsightCard(card.toMap());
      await _localDb.insertLocalReflectionCycle({
        'id': 'cycle_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': _supabase.currentUser?.id ?? 'local_user',
        'period_start': DateTime.now().subtract(const Duration(hours: 24)).toIso8601String(),
        'period_end': DateTime.now().toIso8601String(),
        'status': 'completed',
        'summary': card.mainInsight,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (dbErr) {
      debugPrint('Notice saving local insight card: $dbErr');
    }

    return card;
  }
}
