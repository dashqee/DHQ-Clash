import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/dashboard/widgets/start_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('needsTunToStart', () {
    test('blocks a desktop start while TUN is off', () {
      // The core still runs without TUN, but nothing is routed through it and
      // the button looks identical to a working tunnel.
      expect(
        needsTunToStart(isStarting: true, isDesktop: true, tunEnabled: false),
        isTrue,
      );
    });

    test('never blocks off desktop', () {
      // On Android the tunnel is the system VpnService and tun.enable is not
      // the switch anybody sees; guarding on it would block start for good.
      expect(
        needsTunToStart(isStarting: true, isDesktop: false, tunEnabled: false),
        isFalse,
      );
    });

    test('does not block once TUN is on', () {
      expect(
        needsTunToStart(isStarting: true, isDesktop: true, tunEnabled: true),
        isFalse,
      );
    });

    test('never blocks stopping', () {
      // Turning protection off must always work, whatever TUN is set to.
      expect(
        needsTunToStart(isStarting: false, isDesktop: true, tunEnabled: false),
        isFalse,
      );
    });
  });

  group('launchButtonLabel', () {
    String attempt(int n, int total) => 'attempt $n of $total';

    test('says only "connecting" on the first attempt', () {
      // "attempt 1 of 3" on every start would announce a problem nobody has.
      expect(
        launchButtonLabel(
          const LaunchState(stage: LaunchStage.startingCore, attempt: 1),
          connecting: 'connecting',
          connectingAttempt: attempt,
        ),
        'connecting',
      );
    });

    test('counts attempts once a retry has happened', () {
      expect(
        launchButtonLabel(
          const LaunchState(
            stage: LaunchStage.startingTunnel,
            attempt: 2,
            maxAttempts: 3,
          ),
          connecting: 'connecting',
          connectingAttempt: attempt,
        ),
        'attempt 2 of 3',
      );
    });
  });

  group('StartButton', () {
    Future<void> pump(WidgetTester tester, LaunchState launchState) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            launchStateProvider.overrideWithBuild((_, _) => launchState),
          ],
          child: const _TestApp(child: StartButton()),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows progress while a launch is on its way', (tester) async {
      await pump(
        tester,
        const LaunchState(
          stage: LaunchStage.startingTunnel,
          attempt: 2,
          maxAttempts: 3,
        ),
      );

      expect(
        find.byKey(const ValueKey('start-button-progress')),
        findsOneWidget,
      );
      expect(find.text('Connecting… attempt 2 of 3'), findsOneWidget);
    });

    testWidgets('offers start when idle', (tester) async {
      await pump(tester, const LaunchState());

      expect(find.byKey(const ValueKey('start-button-progress')), findsNothing);
      expect(find.text('Start'), findsOneWidget);
    });
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
