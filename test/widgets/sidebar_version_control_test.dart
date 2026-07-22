import 'package:fl_clash/manager/app_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the version and starts a manual update check', (
    tester,
  ) async {
    var updateChecks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SidebarVersionControl(
            version: '1.0.8',
            checkUpdateLabel: 'Check for updates',
            onCheckUpdate: () {
              updateChecks++;
            },
          ),
        ),
      ),
    );

    expect(find.text('v1.0.8'), findsOneWidget);
    expect(find.byIcon(Icons.system_update_alt), findsOneWidget);

    await tester.tap(find.byIcon(Icons.system_update_alt));

    expect(updateChecks, 1);
  });
}
