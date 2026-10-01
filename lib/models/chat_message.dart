import 'package:uuid/uuid.dart';

enum ChatMessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isError = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == ChatMessageRole.user;
  bool get isAssistant => role == ChatMessageRole.assistant;
  bool get isSystem => role == ChatMessageRole.system;

  Map<String, dynamic> toGroqJson() {
    return {
      'role': role.name,
      'content': content,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_error': isError ? 1 : 0,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString(),
      role: ChatMessageRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => ChatMessageRole.assistant,
      ),
      content: map['content']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isError: map['is_error'] == 1 || map['is_error'] == true,
    );
  }

  ChatMessage copyWith({
    String? id,
    ChatMessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
    );
  }
}
