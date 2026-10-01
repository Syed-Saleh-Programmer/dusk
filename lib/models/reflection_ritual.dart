class ReflectionRitual {
  final String id;
  String name;
  int hour;
  int minute;
  int cadenceDays;
  bool isEnabled;

  ReflectionRitual({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    this.cadenceDays = 1,
    this.isEnabled = true,
  });

  String get timeFormatted {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $amPm';
  }

  String get cadenceLabel {
    if (cadenceDays == 1) return 'Daily';
    if (cadenceDays == 2) return 'Every 2 days';
    if (cadenceDays == 3) return 'Every 3 days';
    if (cadenceDays == 7) return 'Every 7 days';
    return 'Every $cadenceDays days';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
        'cadence_days': cadenceDays,
        'is_enabled': isEnabled,
      };

  factory ReflectionRitual.fromMap(Map<String, dynamic> map) => ReflectionRitual(
        id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: map['name']?.toString() ?? 'Reflection Ritual',
        hour: (map['hour'] as num?)?.toInt() ?? 21,
        minute: (map['minute'] as num?)?.toInt() ?? 0,
        cadenceDays: (map['cadence_days'] as num?)?.toInt() ?? 1,
        isEnabled: map['is_enabled'] == true || map['is_enabled'] == 1,
      );

  Map<String, dynamic> toJson() => toMap();

  factory ReflectionRitual.fromJson(Map<String, dynamic> json) =>
      ReflectionRitual.fromMap(json);

  ReflectionRitual copyWith({
    String? id,
    String? name,
    int? hour,
    int? minute,
    int? cadenceDays,
    bool? isEnabled,
  }) {
    return ReflectionRitual(
      id: id ?? this.id,
      name: name ?? this.name,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      cadenceDays: cadenceDays ?? this.cadenceDays,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  static List<ReflectionRitual> defaultRituals({
    int eveningHour = 21,
    int eveningMinute = 0,
    int eveningCadence = 3,
  }) {
    return [
      ReflectionRitual(
        id: 'dawn',
        name: 'Morning Dawn Check-in',
        hour: 8,
        minute: 0,
        cadenceDays: 1,
        isEnabled: true,
      ),
      ReflectionRitual(
        id: 'shutdown',
        name: 'Workday Shutdown',
        hour: 17,
        minute: 30,
        cadenceDays: 1,
        isEnabled: true,
      ),
      ReflectionRitual(
        id: 'dusk',
        name: 'Evening Dusk Synthesis',
        hour: eveningHour,
        minute: eveningMinute,
        cadenceDays: eveningCadence,
        isEnabled: true,
      ),
    ];
  }
}
