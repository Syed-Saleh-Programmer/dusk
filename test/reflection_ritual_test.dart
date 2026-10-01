import 'package:flutter_test/flutter_test.dart';
import 'package:dusk/models/reflection_ritual.dart';

void main() {
  group('ReflectionRitual Model Tests', () {
    test('defaultRituals creates the 3 standard rituals with expected defaults', () {
      final rituals = ReflectionRitual.defaultRituals(
        eveningHour: 21,
        eveningMinute: 15,
        eveningCadence: 3,
      );

      expect(rituals.length, 3);

      final dawn = rituals[0];
      expect(dawn.id, 'dawn');
      expect(dawn.name, 'Morning Dawn Check-in');
      expect(dawn.hour, 8);
      expect(dawn.minute, 0);
      expect(dawn.cadenceDays, 1);
      expect(dawn.cadenceLabel, 'Daily');
      expect(dawn.timeFormatted, '8:00 AM');
      expect(dawn.isEnabled, true);

      final shutdown = rituals[1];
      expect(shutdown.id, 'shutdown');
      expect(shutdown.name, 'Workday Shutdown');
      expect(shutdown.hour, 17);
      expect(shutdown.minute, 30);
      expect(shutdown.cadenceDays, 1);
      expect(shutdown.cadenceLabel, 'Daily');
      expect(shutdown.timeFormatted, '5:30 PM');
      expect(shutdown.isEnabled, true);

      final dusk = rituals[2];
      expect(dusk.id, 'dusk');
      expect(dusk.name, 'Evening Dusk Synthesis');
      expect(dusk.hour, 21);
      expect(dusk.minute, 15);
      expect(dusk.cadenceDays, 3);
      expect(dusk.cadenceLabel, 'Every 3 days');
      expect(dusk.timeFormatted, '9:15 PM');
      expect(dusk.isEnabled, true);
    });

    test('toJson and fromJson serialize and deserialize correctly', () {
      final ritual = ReflectionRitual(
        id: 'custom_123',
        name: 'Midday Mindful Reset',
        hour: 13,
        minute: 45,
        cadenceDays: 2,
        isEnabled: false,
      );

      final json = ritual.toJson();
      expect(json['id'], 'custom_123');
      expect(json['name'], 'Midday Mindful Reset');
      expect(json['hour'], 13);
      expect(json['minute'], 45);
      expect(json['cadence_days'], 2);
      expect(json['is_enabled'], false);

      final deserialized = ReflectionRitual.fromJson(json);
      expect(deserialized.id, 'custom_123');
      expect(deserialized.name, 'Midday Mindful Reset');
      expect(deserialized.hour, 13);
      expect(deserialized.minute, 45);
      expect(deserialized.cadenceDays, 2);
      expect(deserialized.cadenceLabel, 'Every 2 days');
      expect(deserialized.timeFormatted, '1:45 PM');
      expect(deserialized.isEnabled, false);
    });

    test('copyWith updates specific fields properly', () {
      final original = ReflectionRitual(
        id: 'r1',
        name: 'Morning Dawn Check-in',
        hour: 8,
        minute: 0,
        cadenceDays: 1,
        isEnabled: true,
      );

      final updated = original.copyWith(
        hour: 9,
        minute: 15,
        cadenceDays: 7,
      );

      expect(updated.id, 'r1');
      expect(updated.name, 'Morning Dawn Check-in');
      expect(updated.hour, 9);
      expect(updated.minute, 15);
      expect(updated.timeFormatted, '9:15 AM');
      expect(updated.cadenceDays, 7);
      expect(updated.cadenceLabel, 'Every 7 days');
      expect(updated.isEnabled, true);
    });
  });
}
