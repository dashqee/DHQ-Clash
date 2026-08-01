import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual update item starts an update check', (tester) async {
    var updateChecks = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: CheckUpdateItem(
              onCheckUpdate: () {
                updateChecks++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.byIcon(Icons.system_update_alt), findsOneWidget);

    await tester.tap(find.text('Check for updates'));

    expect(updateChecks, 1);
  });
}
