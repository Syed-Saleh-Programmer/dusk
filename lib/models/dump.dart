import 'dart:convert';

enum DumpType { text, voice, photo }

enum SyncStatus { pending, synced, failed }

class Dump {
  static const List<String> defaultTags = [
    'Work',
    'Personal',
    'Ideas',
    'Goals',
    'Health',
    'Feelings',
    'Finance',
    'Errands',
    'Learning',
    'Gratitude',
  ];

  static String normalizeTag(String raw) {
    final cleaned = raw.replaceAll('#', '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';
    // Capitalize first letter if the tag is entirely lowercase
    if (cleaned == cleaned.toLowerCase() && cleaned.length > 1) {
      return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    return cleaned;
  }

  static List<String> parseTags(dynamic raw) {
    if (raw == null) return const [];
    final List<String> candidates = [];
    if (raw is List) {
      for (final item in raw) {
        if (item != null) {
          candidates.add(item.toString());
        }
      }
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            for (final item in decoded) {
              if (item != null) candidates.add(item.toString());
            }
          }
        } catch (_) {
          candidates.addAll(trimmed.split(','));
        }
      } else if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        // Postgres text[] format e.g. {Work,"New Tag"}
        final inner = trimmed.substring(1, trimmed.length - 1);
        if (inner.isNotEmpty) {
          candidates.addAll(
            inner.split(',').map((s) => s.replaceAll('"', '').trim()),
          );
        }
      } else {
        candidates.addAll(trimmed.split(','));
      }
    }

    final seenLower = <String>{};
    final result = <String>[];
    for (final c in candidates) {
      final norm = normalizeTag(c);
      if (norm.isEmpty) continue;
      final lower = norm.toLowerCase();
      if (seenLower.add(lower)) {
        // Prefer canonical casing from defaultTags if it matches
        final canonical = defaultTags.firstWhere(
          (d) => d.toLowerCase() == lower,
          orElse: () => norm,
        );
        result.add(canonical);
      }
    }
    return result;
  }

  final String id;
  final String userId;
  final DumpType type;
  final String? title;
  final String? content;
  final String? transcript;
  final String? mediaUrl;
  final String? category;
  final String? projectId;
  final List<String> tags;
  final DateTime capturedAt;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final String? aiSummary;

  Dump({
    required this.id,
    required this.userId,
    required this.type,
    this.title,
    this.content,
    this.transcript,
    this.mediaUrl,
    this.category,
    this.projectId,
    List<String> tags = const [],
    required this.capturedAt,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
    this.aiSummary,
  }) : tags = parseTags(tags);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.name,
      'title': title,
      'content': content,
      'transcript': transcript,
      'media_url': mediaUrl,
      'category': category,
      'project_id': projectId,
      'tags': tags,
      'captured_at': capturedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus.name,
      'ai_summary': aiSummary,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    final map = toMap();
    map['tags'] = jsonEncode(tags);
    return map;
  }

  factory Dump.fromMap(Map<String, dynamic> map) {
    return Dump(
      id: map['id'],
      userId: map['user_id'],
      type: DumpType.values.firstWhere((e) => e.name == map['type']),
      title: map['title'] ?? map['category'],
      content: map['content'],
      transcript: map['transcript'],
      mediaUrl: map['media_url'],
      category: map['category'] ?? map['title'],
      projectId: map['project_id']?.toString(),
      tags: parseTags(map['tags']),
      capturedAt: DateTime.parse(map['captured_at']),
      createdAt: DateTime.parse(map['created_at']),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == map['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
      aiSummary: map['ai_summary'],
    );
  }

  Dump copyWith({
    String? id,
    String? userId,
    DumpType? type,
    String? title,
    String? content,
    String? transcript,
    String? mediaUrl,
    String? category,
    String? projectId,
    bool clearProjectId = false,
    List<String>? tags,
    DateTime? capturedAt,
    DateTime? createdAt,
    SyncStatus? syncStatus,
    String? aiSummary,
  }) {
    return Dump(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      transcript: transcript ?? this.transcript,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      category: category ?? this.category,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      tags: tags ?? this.tags,
      capturedAt: capturedAt ?? this.capturedAt,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }
}
