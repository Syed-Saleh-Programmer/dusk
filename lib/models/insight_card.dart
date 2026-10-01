class InsightCard {
  final String id;
  final String sessionId;
  final String userId;
  final String title;
  final String mainInsight;
  final String standout;
  final String suggestion;
  final String? weekOverview;
  final String? progressAndWins;
  final String? motivation;
  final List<String>? nextActions;
  final DateTime createdAt;

  InsightCard({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.title,
    required this.mainInsight,
    required this.standout,
    required this.suggestion,
    this.weekOverview,
    this.progressAndWins,
    this.motivation,
    this.nextActions,
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
      'week_overview': weekOverview,
      'progress_and_wins': progressAndWins,
      'motivation': motivation,
      'next_actions': nextActions?.join('|||'),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InsightCard.fromMap(Map<String, dynamic> map) {
    List<String>? parsedNextActions;
    if (map['next_actions'] != null) {
      if (map['next_actions'] is List) {
        parsedNextActions = (map['next_actions'] as List).map((e) => e.toString()).toList();
      } else if (map['next_actions'] is String) {
        final str = map['next_actions'] as String;
        if (str.isNotEmpty) {
          parsedNextActions = str.contains('|||') ? str.split('|||') : [str];
        }
      }
    }

    return InsightCard(
      id: map['id'] ?? '',
      sessionId: map['session_id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? 'Daily Insight',
      mainInsight: map['main_insight'] ?? '',
      standout: map['standout'] ?? '',
      suggestion: map['suggestion'] ?? '',
      weekOverview: map['week_overview'],
      progressAndWins: map['progress_and_wins'],
      motivation: map['motivation'],
      nextActions: parsedNextActions,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
