enum CycleStatus { scheduled, ready, inProgress, completed, skipped }

class ReflectionCycle {
  final String id;
  final String userId;
  final String scheduleId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final CycleStatus status;
  final String? summary;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  ReflectionCycle({
    required this.id,
    required this.userId,
    required this.scheduleId,
    required this.periodStart,
    required this.periodEnd,
    this.status = CycleStatus.scheduled,
    this.summary,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'schedule_id': scheduleId,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'status': status.name,
      'summary': summary,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReflectionCycle.fromMap(Map<String, dynamic> map) {
    return ReflectionCycle(
      id: map['id'],
      userId: map['user_id'],
      scheduleId: map['schedule_id'],
      periodStart: DateTime.parse(map['period_start']),
      periodEnd: DateTime.parse(map['period_end']),
      status: CycleStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CycleStatus.scheduled,
      ),
      summary: map['summary'],
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
