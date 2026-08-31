import 'package:fl_clash/widgets/starfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the starfield animates without breaking the frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox.expand(child: Starfield())),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 7));
    expect(find.byType(Starfield), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion leaves a static sky', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: SizedBox.expand(child: Starfield())),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    // A stopped controller schedules no frames: pumping settles immediately.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
