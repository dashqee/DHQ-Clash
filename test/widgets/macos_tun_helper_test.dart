import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('allows a manual macOS TUN helper install', (tester) async {
    var installed = false;
    var installCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: _TestApp(
          child: MacOSTunHelperItem(
            checkInstalled: () async => installed,
            install: () async {
              installCalls++;
              return AuthorizeCode.success;
            },
            onInstalled: () async {
              installed = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TUN access'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);

    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();

    expect(installCalls, 1);
    expect(find.text('TUN access is installed'), findsOneWidget);
    expect(find.text('Authorized'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

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
      home: Scaffold(body: child),
    );
  }
}
