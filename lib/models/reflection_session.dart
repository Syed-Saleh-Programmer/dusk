enum SessionStatus { created, generating, active, completed, failed }

class ReflectionSession {
  final String id;
  final String cycleId;
  final String userId;
  final SessionStatus status;
  final String? generatedSummary;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  ReflectionSession({
    required this.id,
    required this.cycleId,
    required this.userId,
    this.status = SessionStatus.created,
    this.generatedSummary,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycle_id': cycleId,
      'user_id': userId,
      'status': status.name,
      'generated_summary': generatedSummary,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReflectionSession.fromMap(Map<String, dynamic> map) {
    return ReflectionSession(
      id: map['id'],
      cycleId: map['cycle_id'],
      userId: map['user_id'],
      status: SessionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SessionStatus.created,
      ),
      generatedSummary: map['generated_summary'],
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class ReflectionQuestion {
  final String id;
  final String sessionId;
  final int position;
  final String questionText;
  final DateTime createdAt;

  ReflectionQuestion({
    required this.id,
    required this.sessionId,
    required this.position,
    required this.questionText,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'position': position,
      'question_text': questionText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReflectionQuestion.fromMap(Map<String, dynamic> map) {
    return ReflectionQuestion(
      id: map['id'],
      sessionId: map['session_id'],
      position: map['position'],
      questionText: map['question_text'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

enum AnswerType { text, voice }

class ReflectionAnswer {
  final String id;
  final String questionId;
  final String userId;
  final AnswerType answerType;
  final String? answerText;
  final String? transcript;
  final String? mediaUrl;
  final DateTime createdAt;

  ReflectionAnswer({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.answerType,
    this.answerText,
    this.transcript,
    this.mediaUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'user_id': userId,
      'answer_type': answerType.name,
      'answer_text': answerText,
      'transcript': transcript,
      'media_url': mediaUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReflectionAnswer.fromMap(Map<String, dynamic> map) {
    return ReflectionAnswer(
      id: map['id'],
      questionId: map['question_id'],
      userId: map['user_id'],
      answerType: AnswerType.values.firstWhere(
        (e) => e.name == map['answer_type'],
        orElse: () => AnswerType.text,
      ),
      answerText: map['answer_text'],
      transcript: map['transcript'],
      mediaUrl: map['media_url'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
