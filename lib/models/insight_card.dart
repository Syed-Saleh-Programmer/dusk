class InsightCard {
  final String id;
  final String sessionId;
  final String userId;
  final String title;
  final String mainInsight;
  final String standout;
  final String suggestion;
  final DateTime createdAt;

  InsightCard({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.title,
    required this.mainInsight,
    required this.standout,
    required this.suggestion,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'title': title,
      'main_insight': mainInsight,
      'standout': standout,
      'suggestion': suggestion,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InsightCard.fromMap(Map<String, dynamic> map) {
    return InsightCard(
      id: map['id'],
      sessionId: map['session_id'],
      userId: map['user_id'],
      title: map['title'],
      mainInsight: map['main_insight'],
      standout: map['standout'],
      suggestion: map['suggestion'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
