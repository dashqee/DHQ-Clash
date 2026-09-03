import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/button.dart';
import 'package:fl_clash/widgets/update_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Opens the prompt; [results] receives what it pops with.
  Future<void> pumpPrompt(WidgetTester tester, List<bool?> results) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(1000, 800)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  results.add(
                    await showDialog<bool>(
                      context: context,
                      builder: (_) => const UpdatePromptDialog(
                        version: 'v9.9.9',
                        notes: 'Everything is faster.',
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers exactly install and remind-later', (tester) async {
    await pumpPrompt(tester, []);

    expect(find.text('v9.9.9'), findsOneWidget);
    expect(find.text('Everything is faster.'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
    expect(find.text('Remind me later'), findsOneWidget);
    // The permanent opt-out is gone on purpose: the next launch asks again.
    expect(find.text("Don't remind again"), findsNothing);
    // Install is the highlighted, brand-styled action.
    expect(
      find.descendant(
        of: find.byType(BrandButton),
        matching: find.text('Install'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('install pops true, later pops false', (tester) async {
    final results = <bool?>[];

    await pumpPrompt(tester, results);
    await tester.tap(find.byKey(const ValueKey('update-install')));
    await tester.pumpAndSettle();
    expect(find.byType(UpdatePromptDialog), findsNothing);
    expect(results, [true]);

    await pumpPrompt(tester, results);
    await tester.tap(find.byKey(const ValueKey('update-remind-later')));
    await tester.pumpAndSettle();
    expect(find.byType(UpdatePromptDialog), findsNothing);
    expect(results, [true, false]);
  });
}
