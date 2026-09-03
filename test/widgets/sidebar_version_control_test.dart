import 'package:fl_clash/manager/app_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Badge marker(WidgetTester tester) =>
      tester.widget<Badge>(find.byKey(const ValueKey('sidebar-update-marker')));

  testWidgets('shows the version and checks for updates on tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        SidebarVersionControl(
          version: '1.0.8',
          checkUpdateLabel: 'Check for updates',
          onCheckUpdate: () => taps++,
        ),
      ),
    );

    expect(find.text('v1.0.8'), findsOneWidget);
    expect(find.byIcon(Icons.system_update_alt), findsOneWidget);
    expect(marker(tester).isLabelVisible, isFalse);
    expect(find.byTooltip('Check for updates'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.system_update_alt));
    expect(taps, 1);
  });

  testWidgets('wears a marker while an update is pending', (tester) async {
    await tester.pumpWidget(
      wrap(
        SidebarVersionControl(
          version: '1.0.8',
          checkUpdateLabel: 'Check for updates',
          updateVersion: 'v1.0.9',
          updateAvailableLabel: 'Update v1.0.9 available',
          onCheckUpdate: () {},
        ),
      ),
    );

    expect(marker(tester).isLabelVisible, isTrue);
    expect(find.byTooltip('Update v1.0.9 available'), findsOneWidget);
  });
}
