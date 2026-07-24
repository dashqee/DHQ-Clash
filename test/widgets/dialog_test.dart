import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CommonDialog allows wider changelog content', (tester) async {
    const contentKey = Key('changelog-content');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(1000, 800)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CommonDialog(
              title: 'Latest version',
              maxWidth: 480,
              child: SizedBox(key: contentKey, width: 480, height: 40),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(contentKey)).width, 480);
  });
}
