import 'dump.dart';

class Project {
  static const List<int> defaultColors = [
    0xFF6366F1, // Indigo
    0xFF10B981, // Emerald
    0xFFF59E0B, // Amber
    0xFFEC4899, // Rose
    0xFF8B5CF6, // Violet
    0xFF06B6D4, // Cyan
    0xFFF97316, // Orange
    0xFF14B8A6, // Teal
    0xFFE11D48, // Crimson
  ];

  static const List<String> defaultIcons = [
    '📁',
    '🚀',
    '💡',
    '🎯',
    '🌿',
    '🏋️',
    '✈️',
    '📚',
    '💼',
    '🎨',
    '🏠',
    '☕',
  ];

  final String id;
  final String userId;
  final String name;
  final String? description;
  final String icon;
  final int colorValue;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Project({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    String? icon,
    int? colorValue,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = SyncStatus.pending,
  })  : icon = (icon != null && icon.trim().isNotEmpty) ? icon.trim() : '📁',
        colorValue = colorValue ?? defaultColors[0],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  Project copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    bool clearDescription = false,
    String? icon,
    int? colorValue,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Project(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    final rawSync = map['sync_status']?.toString().toLowerCase() ?? 'synced';
    final syncStatus = SyncStatus.values.firstWhere(
      (e) => e.name == rawSync,
      orElse: () => SyncStatus.synced,
    );

    final createdAt = DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    final updatedAt = DateTime.tryParse(map['updated_at']?.toString() ?? '')?.toLocal() ??
        createdAt;

    int color = defaultColors[0];
    if (map['color_value'] != null) {
      if (map['color_value'] is int) {
        color = map['color_value'];
      } else {
        color = int.tryParse(map['color_value'].toString()) ?? defaultColors[0];
      }
    }

    final isArchivedVal = map['is_archived'];
    final isArchived = isArchivedVal == true ||
        isArchivedVal == 1 ||
        isArchivedVal.toString() == 'true' ||
        isArchivedVal.toString() == '1';

    return Project(
      id: map['id'].toString(),
      userId: map['user_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Untitled Project',
      description: map['description']?.toString(),
      icon: map['icon']?.toString(),
      colorValue: color,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncStatus: syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'icon': icon,
      'color_value': colorValue,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return toMap();
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'icon': icon,
      'color_value': colorValue,
      'is_archived': isArchived,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'sync_status': 'synced',
    };
  }
}
