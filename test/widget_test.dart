import 'package:flutter_test/flutter_test.dart';

import 'package:dusk/main.dart';

void main() {
  testWidgets('DuskApp smoke test', (WidgetTester tester) async {
    // Build DuskApp with hasSeenOnboarding parameter
    await tester.pumpWidget(const DuskApp(hasSeenOnboarding: false));

    // Verify widget tree builds
    expect(find.byType(DuskApp), findsOneWidget);
  });
}
