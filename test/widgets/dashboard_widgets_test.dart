import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_mode.dart';
import 'package:fl_clash/views/dashboard/widgets/quick_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rule gradient animation closes its loop without a jump', () {
    const epsilon = 1e-10;
    expect(outboundRuleShimmerOffset(0), closeTo(0, epsilon));
    expect(outboundRuleShimmerOffset(0.25), closeTo(1, epsilon));
    expect(outboundRuleShimmerOffset(0.75), closeTo(-1, epsilon));
    expect(outboundRuleShimmerOffset(1), closeTo(0, epsilon));
  });

  testWidgets('network quick options keep their switches inside the cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: _TestApp(
          child: SizedBox(
            width: 360,
            child: Column(
              children: [
                TUNButton(),
                SizedBox(height: 12),
                SystemProxyButton(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(TUNButton)).height, 104);
    expect(tester.getSize(find.byType(SystemProxyButton)).height, 104);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new outbound mode renders all three choices', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: _TestApp(child: OutboundModeV2())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Rule'), findsOneWidget);
    expect(find.text('Global'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    final footer = tester.widget<Container>(
      find.byKey(const ValueKey('outbound-mode-footer')),
    );
    final decoration = footer.decoration! as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
    expect(decoration.color, isNull);
    expect(tester.takeException(), isNull);
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
      builder: (context, child) {
        globalState.theme = CommonTheme.of(context, 1);
        globalState.measure = Measure.of(context, 1);
        return child!;
      },
      home: Scaffold(body: Center(child: child)),
    );
  }
}
