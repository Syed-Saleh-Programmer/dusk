import '../models/reflection_session.dart';
import '../models/insight_card.dart';
import 'package:uuid/uuid.dart';

class ReflectionService {
  static final ReflectionService _instance = ReflectionService._internal();
  factory ReflectionService() => _instance;
  ReflectionService._internal();

  final Uuid _uuid = const Uuid();

  Future<ReflectionSession> generateSummary(String cycleId) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    return ReflectionSession(
      id: _uuid.v4(),
      cycleId: cycleId,
      userId: 'local_user',
      status: SessionStatus.active,
      generatedSummary: 'You spent much of this cycle moving several unfinished ideas forward, but the clearest pattern was a desire to simplify your workflow.',
      startedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  Future<List<ReflectionQuestion>> generateQuestions(String sessionId) async {
    await Future.delayed(const Duration(seconds: 2));
    
    return [
      ReflectionQuestion(
        id: _uuid.v4(),
        sessionId: sessionId,
        position: 1,
        questionText: 'What is one specific way you can simplify your workflow tomorrow?',
        createdAt: DateTime.now(),
      ),
      ReflectionQuestion(
        id: _uuid.v4(),
        sessionId: sessionId,
        position: 2,
        questionText: 'What idea are you holding onto that you should let go of?',
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<InsightCard> generateInsightCard(String sessionId, List<ReflectionAnswer> answers) async {
    await Future.delayed(const Duration(seconds: 2));
    
    return InsightCard(
      id: _uuid.v4(),
      sessionId: sessionId,
      userId: 'local_user',
      title: 'Simplification',
      mainInsight: 'You are carrying cognitive load from abandoned projects.',
      standout: 'The clearest pattern was a desire to simplify your workflow.',
      suggestion: 'Choose one of the ideas and give it a small, specific next action.',
      createdAt: DateTime.now(),
    );
  }
}
