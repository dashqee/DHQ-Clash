import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final testCase in [
    (UpdateChannel.stable, 'Stable'),
    (UpdateChannel.beta, 'Beta'),
  ]) {
    testWidgets('shows ${testCase.$2} update channel', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingProvider.overrideWithValue(
              AppSettingProps(updateChannel: testCase.$1),
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update channel'), findsOneWidget);
      expect(find.text(testCase.$2), findsOneWidget);
    });
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: const Scaffold(body: UpdateChannelItem()),
    );
  }
}
