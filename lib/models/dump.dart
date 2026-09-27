enum DumpType { text, voice, photo }

enum SyncStatus { pending, synced, failed }

class Dump {
  final String id;
  final String userId;
  final DumpType type;
  final String? title;
  final String? content;
  final String? transcript;
  final String? mediaUrl;
  final String? category;
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
    required this.capturedAt,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
    this.aiSummary,
  });

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
      'captured_at': capturedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus.name,
      'ai_summary': aiSummary,
    };
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
      capturedAt: capturedAt ?? this.capturedAt,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }
}
