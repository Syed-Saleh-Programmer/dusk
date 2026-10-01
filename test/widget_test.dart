import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dusk/ui/widgets/dusk_ui_components.dart';

void main() {
  testWidgets('DuskNotchedBottomBar renders tabs and handles selection', (WidgetTester tester) async {
    int selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DuskNotchedBottomBar(
            currentIndex: selectedIndex,
            pendingTasksCount: 3,
            onTabSelected: (index) {
              selectedIndex = index;
            },
          ),
        ),
      ),
    );

    // Verify all tabs are rendered
    expect(find.text('Captures'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify pending tasks badge
    expect(find.text('3'), findsOneWidget);

    // Tap on Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 3);
  });
}
