import '../models/reflection_session.dart';
import '../models/insight_card.dart';
import 'supabase_service.dart';

class ReflectionService {
  static final ReflectionService _instance = ReflectionService._internal();
  factory ReflectionService() => _instance;
  ReflectionService._internal();

  final SupabaseService _supabase = SupabaseService();

  Future<ReflectionSession> generateSummary(String cycleId) async {
    // Calls Edge Function which generates summary + questions, and creates a session record
    final data = await _supabase.generateReflection(cycleId);
    final sessionId = data['session_id'];

    // For now we don't return the full summary model, we'll fetch the generated questions next.
    return ReflectionSession(
      id: sessionId,
      cycleId: cycleId,
      userId: _supabase.currentUser?.id ?? 'local_user',
      status: SessionStatus.active,
      generatedSummary: '', // Will fetch later if needed
      startedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  Future<List<ReflectionQuestion>> generateQuestions(String sessionId) async {
    final list = await _supabase.getReflectionQuestions(sessionId);
    return list.map((q) => ReflectionQuestion(
      id: q['id'] as String,
      sessionId: q['session_id'] as String,
      position: q['position'] as int,
      questionText: q['question_text'] as String,
      createdAt: DateTime.parse(q['created_at'] as String),
    )).toList();
  }

  Future<InsightCard> generateInsightCard(String sessionId, List<ReflectionAnswer> answers) async {
    // 1. Submit answers to DB
    for (final ans in answers) {
      await _supabase.submitReflectionAnswer(ans.questionId, ans.answerText ?? '');
    }

    // 2. Call generate-insight edge function
    final data = await _supabase.generateInsight(sessionId);
    final cardData = data['insight_card'];

    return InsightCard(
      id: cardData['id'] as String,
      sessionId: cardData['session_id'] as String,
      userId: cardData['user_id'] as String,
      title: cardData['title'] as String,
      mainInsight: cardData['main_insight'] as String,
      standout: cardData['standout'] as String,
      suggestion: cardData['suggestion'] as String,
      createdAt: DateTime.parse(cardData['created_at'] as String),
    );
  }
}
