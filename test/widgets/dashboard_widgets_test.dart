import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_mode.dart';
import 'package:fl_clash/views/dashboard/widgets/quick_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rule gradient rotation closes its loop without a jump', () {
    const epsilon = 1e-10;
    expect(
      outboundRuleGradientAngle(0),
      closeTo(outboundRuleGradientAngle(1), epsilon),
    );
    expect(
      outboundRuleGradientAngle(0),
      closeTo(outboundRuleGradientAngle(2), epsilon),
    );
    expect(
      outboundRuleGradientAngle(0.25),
      isNot(closeTo(outboundRuleGradientAngle(0), epsilon)),
    );
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

  testWidgets(
    'rule gradient keeps animating after completing a cycle',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: _TestApp(child: OutboundModeV2())),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final initialAngle = _ruleFooterAngle(tester);
      expect(_ruleSegmentAngle(tester), closeTo(initialAngle, 1e-6));

      await tester.pump(const Duration(milliseconds: 600));
      final movingAngle = _ruleFooterAngle(tester);
      expect(movingAngle, isNot(closeTo(initialAngle, 1e-6)));
      expect(_ruleSegmentAngle(tester), closeTo(movingAngle, 1e-6));

      await tester.pump(const Duration(milliseconds: 2400));
      expect(_ruleFooterAngle(tester), closeTo(movingAngle, 1e-6));
      expect(_ruleSegmentAngle(tester), closeTo(movingAngle, 1e-6));

      await tester.pump(const Duration(milliseconds: 300));
      expect(_ruleFooterAngle(tester), isNot(closeTo(movingAngle, 1e-6)));
      expect(
        _ruleSegmentAngle(tester),
        closeTo(_ruleFooterAngle(tester), 1e-6),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.all(),
  );

  testWidgets('start control stays inside status card on compact layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profilesProvider.overrideWith(
            () => _TestProfiles([
              Profile.normal(url: 'https://example.com/subscription'),
            ]),
          ),
        ],
        child: const _TestApp(
          child: SizedBox(width: 360, child: DashboardConnectionOverview()),
        ),
      ),
    );
    await tester.pump();

    final overview = find.byKey(
      const ValueKey('dashboard-connection-overview'),
    );
    final startButton = find.byKey(const ValueKey('connection-start-button'));
    final metrics = find.byKey(const ValueKey('connection-overview-metrics'));
    expect(overview, findsOneWidget);
    expect(
      find.descendant(of: overview, matching: startButton),
      findsOneWidget,
    );
    expect(
      tester.getTopRight(startButton).dy,
      lessThan(tester.getTopLeft(metrics).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('start control stays at the top on wide desktop layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profilesProvider.overrideWith(
            () => _TestProfiles([
              Profile.normal(url: 'https://example.com/subscription'),
            ]),
          ),
        ],
        child: const _TestApp(
          child: SizedBox(width: 900, child: DashboardConnectionOverview()),
        ),
      ),
    );
    await tester.pump();

    final startButton = find.byKey(const ValueKey('connection-start-button'));
    final metrics = find.byKey(const ValueKey('connection-overview-metrics'));
    expect(
      tester.getTopLeft(startButton).dy,
      closeTo(tester.getTopLeft(metrics).dy, 0.01),
    );
    expect(tester.takeException(), isNull);
  });
}

double _ruleFooterAngle(WidgetTester tester) {
  final footer = tester.widget<Container>(
    find.byKey(const ValueKey('outbound-mode-footer')),
  );
  final decoration = footer.decoration! as BoxDecoration;
  final gradient = decoration.gradient! as LinearGradient;
  return (gradient.transform! as GradientRotation).radians;
}

double _ruleSegmentAngle(WidgetTester tester) {
  final segment = find.byKey(const ValueKey('outbound-mode-rule'));
  final decoratedBox = tester.widget<DecoratedBox>(
    find.descendant(of: segment, matching: find.byType(DecoratedBox)).first,
  );
  final decoration = decoratedBox.decoration as BoxDecoration;
  final gradient = decoration.gradient! as LinearGradient;
  return (gradient.transform! as GradientRotation).radians;
}

class _TestProfiles extends Profiles {
  final List<Profile> initial;

  _TestProfiles(this.initial);

  @override
  List<Profile> build() => initial;
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
