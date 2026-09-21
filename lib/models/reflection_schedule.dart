enum FrequencyType { daily, interval, weekly }

class ReflectionSchedule {
  final String id;
  final String userId;
  final FrequencyType frequencyType;
  final int frequencyValue;
  final String time; // e.g. "21:00"
  final String timezone;
  final bool enabled;
  final DateTime nextTriggerAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReflectionSchedule({
    required this.id,
    required this.userId,
    required this.frequencyType,
    required this.frequencyValue,
    required this.time,
    required this.timezone,
    this.enabled = true,
    required this.nextTriggerAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'frequency_type': frequencyType.name,
      'frequency_value': frequencyValue,
      'time': time,
      'timezone': timezone,
      'enabled': enabled ? 1 : 0,
      'next_trigger_at': nextTriggerAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ReflectionSchedule.fromMap(Map<String, dynamic> map) {
    return ReflectionSchedule(
      id: map['id'],
      userId: map['user_id'],
      frequencyType: FrequencyType.values.firstWhere(
        (e) => e.name == map['frequency_type'],
        orElse: () => FrequencyType.daily,
      ),
      frequencyValue: map['frequency_value'],
      time: map['time'],
      timezone: map['timezone'],
      enabled: map['enabled'] == 1 || map['enabled'] == true,
      nextTriggerAt: DateTime.parse(map['next_trigger_at']),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
