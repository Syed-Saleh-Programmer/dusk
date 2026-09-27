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
  });
}
