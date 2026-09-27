enum CycleStatus { scheduled, ready, pending, inProgress, completed, skipped }

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
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      scheduleId: map['schedule_id'] ?? 'default',
      periodStart: DateTime.parse(map['period_start'] ?? DateTime.now().toIso8601String()),
      periodEnd: DateTime.parse(map['period_end'] ?? DateTime.now().toIso8601String()),
      status: () {
        final st = map['status'];
        if (st == 'in_progress') return CycleStatus.inProgress;
        if (st == 'pending') return CycleStatus.pending;
        return CycleStatus.values.firstWhere(
          (e) => e.name == st,
          orElse: () => CycleStatus.scheduled,
        );
      }(),
      summary: map['summary'],
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }
}
