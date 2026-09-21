enum DumpType { text, voice, photo }

enum SyncStatus { pending, synced, failed }

class Dump {
  final String id;
  final String userId;
  final DumpType type;
  final String? content;
  final String? transcript;
  final String? mediaUrl;
  final String? category;
  final DateTime capturedAt;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  Dump({
    required this.id,
    required this.userId,
    required this.type,
    this.content,
    this.transcript,
    this.mediaUrl,
    this.category,
    required this.capturedAt,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.name,
      'content': content,
      'transcript': transcript,
      'media_url': mediaUrl,
      'category': category,
      'captured_at': capturedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Dump.fromMap(Map<String, dynamic> map) {
    return Dump(
      id: map['id'],
      userId: map['user_id'],
      type: DumpType.values.firstWhere((e) => e.name == map['type']),
      content: map['content'],
      transcript: map['transcript'],
      mediaUrl: map['media_url'],
      category: map['category'],
      capturedAt: DateTime.parse(map['captured_at']),
      createdAt: DateTime.parse(map['created_at']),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == map['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}
