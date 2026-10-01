import 'package:flutter_test/flutter_test.dart';
import 'package:dusk/services/quick_capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickCaptureService Tests', () {
    test('QuickCaptureService instance is singleton', () {
      final instance1 = QuickCaptureService();
      final instance2 = QuickCaptureService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Initializes cleanly without throwing', () async {
      final service = QuickCaptureService();
      // Should not throw on second init or double calls
      await service.init();
      await service.init();
      expect(service, isNotNull);
    });

    test('Updates widget analytics data cleanly without throwing', () async {
      final service = QuickCaptureService();
      await service.updateWidgetData(
        dumpCount: 3,
        todayCount: 3,
        totalCount: 14,
        thoughtCount: 7,
        voiceCount: 4,
        photoCount: 3,
        weeklyCounts: const [1, 2, 0, 3, 2, 3, 3],
        weeklyLabels: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
        activeDays: 6,
        ritualProgress: 75,
        ritualCompleted: false,
        peakPeriod: 'Evening',
      );
      expect(service, isNotNull);
    });
  });
}
