import 'dart:convert';
import 'dump.dart';

enum TaskSourceType { dump, insight, manual }

enum TaskStatus { pending, done, archived }

class TaskItem {
  final String id;
  final String userId;
  final String? dumpId;
  final String? insightCardId;
  final String? projectId;
  final String title;
  final TaskSourceType sourceType;
  final String? sourceLabel;
  final List<String> tags;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  TaskItem({
    required this.id,
    required this.userId,
    this.dumpId,
    this.insightCardId,
    this.projectId,
    required this.title,
    this.sourceType = TaskSourceType.dump,
    this.sourceLabel,
    List<String> tags = const [],
    this.status = TaskStatus.pending,
    this.dueDate,
    required this.createdAt,
    this.completedAt,
    DateTime? updatedAt,
    this.syncStatus = SyncStatus.pending,
  })  : tags = Dump.parseTags(tags),
        updatedAt = updatedAt ?? createdAt;

  bool get isDone => status == TaskStatus.done;
  bool get isArchived => status == TaskStatus.archived;
  bool get isPending => status == TaskStatus.pending;
  bool get hasDueDate => dueDate != null;

  bool get isOverdue {
    if (dueDate == null || isDone || isArchived) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final localDue = dueDate!.toLocal();
    final dueDay = DateTime(localDue.year, localDue.month, localDue.day);
    return dueDay.isBefore(todayStart);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final localDue = dueDate!.toLocal();
    return localDue.year == now.year &&
        localDue.month == now.month &&
        localDue.day == now.day;
  }

  TaskItem copyWith({
    String? id,
    String? userId,
    String? dumpId,
    String? insightCardId,
    String? projectId,
    bool clearProjectId = false,
    String? title,
    TaskSourceType? sourceType,
    String? sourceLabel,
    List<String>? tags,
    TaskStatus? status,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return TaskItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dumpId: dumpId ?? this.dumpId,
      insightCardId: insightCardId ?? this.insightCardId,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    final rawSource = map['source_type']?.toString().toLowerCase() ?? 'dump';
    final sourceType = TaskSourceType.values.firstWhere(
      (e) => e.name == rawSource,
      orElse: () => TaskSourceType.dump,
    );

    final rawStatus = map['status']?.toString().toLowerCase() ?? 'pending';
    final status = TaskStatus.values.firstWhere(
      (e) => e.name == rawStatus,
      orElse: () => TaskStatus.pending,
    );

    final rawSync = map['sync_status']?.toString().toLowerCase() ?? 'synced';
    final syncStatus = SyncStatus.values.firstWhere(
      (e) => e.name == rawSync,
      orElse: () => SyncStatus.synced,
    );

    final dueDate = map['due_date'] != null
        ? DateTime.tryParse(map['due_date'].toString())?.toLocal()
        : null;
    final createdAt = DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    final completedAt = map['completed_at'] != null
        ? DateTime.tryParse(map['completed_at'].toString())?.toLocal()
        : null;
    final updatedAt = DateTime.tryParse(map['updated_at']?.toString() ?? '')?.toLocal() ??
        createdAt;

    return TaskItem(
      id: map['id'].toString(),
      userId: map['user_id']?.toString() ?? '',
      dumpId: map['dump_id']?.toString(),
      insightCardId: map['insight_card_id']?.toString(),
      projectId: map['project_id']?.toString(),
      title: map['title']?.toString() ?? '',
      sourceType: sourceType,
      sourceLabel: map['source_label']?.toString(),
      tags: Dump.parseTags(map['tags']),
      status: status,
      dueDate: dueDate,
      createdAt: createdAt,
      completedAt: completedAt,
      updatedAt: updatedAt,
      syncStatus: syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'dump_id': dumpId,
      'insight_card_id': insightCardId,
      'project_id': projectId,
      'title': title,
      'source_type': sourceType.name,
      'source_label': sourceLabel,
      'tags': tags,
      'status': status.name,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    final map = toMap();
    map['tags'] = jsonEncode(tags);
    return map;
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      if (dumpId != null && dumpId!.isNotEmpty) 'dump_id': dumpId,
      if (insightCardId != null && insightCardId!.isNotEmpty)
        'insight_card_id': insightCardId,
      if (projectId != null && projectId!.isNotEmpty) 'project_id': projectId,
      'title': title,
      'source_type': sourceType.name,
      if (sourceLabel != null && sourceLabel!.isNotEmpty)
        'source_label': sourceLabel,
      'tags': tags,
      'status': status.name,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'sync_status': 'synced',
    };
  }
}
