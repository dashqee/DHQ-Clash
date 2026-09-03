import 'package:fl_clash/common/vpn_launcher.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

/// A scripted launch: each step answers from its queue, the last answer
/// repeating once the queue runs dry.
class FakeSteps implements LaunchSteps {
  final List<StepOutcome> core;
  final List<StepOutcome> config;
  final List<StepOutcome> tunnel;
  final List<StepOutcome> verify;
  final List<String> calls = [];
  int teardowns = 0;
  void Function()? onVerify;

  FakeSteps({
    this.core = const [StepOutcome.ok()],
    this.config = const [StepOutcome.ok()],
    this.tunnel = const [StepOutcome.ok()],
    this.verify = const [StepOutcome.ok()],
  });

  StepOutcome _next(List<StepOutcome> queue, String name) {
    calls.add(name);
    final index = calls.where((call) => call == name).length - 1;
    return queue[index < queue.length ? index : queue.length - 1];
  }

  @override
  Future<StepOutcome> ensureCore() async => _next(core, 'core');

  @override
  Future<StepOutcome> applyConfig() async => _next(config, 'config');

  @override
  Future<StepOutcome> startTunnel() async => _next(tunnel, 'tunnel');

  @override
  Future<StepOutcome> verifyTunnel() async {
    onVerify?.call();
    return _next(verify, 'verify');
  }

  @override
  Future<void> teardown() async {
    teardowns++;
    calls.add('teardown');
  }
}

void main() {
  const policy = LaunchPolicy(
    maxAttempts: 3,
    delays: [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)],
    verifyTimeout: Duration(milliseconds: 900),
    verifyInterval: Duration(milliseconds: 300),
  );

  late List<LaunchState> states;
  late List<Duration> waits;

  VpnLauncher launcher(FakeSteps steps, {LaunchPolicy policy = policy}) {
    states = [];
    waits = [];
    return VpnLauncher(
      steps: steps,
      policy: policy,
      onState: states.add,
      wait: (duration) async {
        waits.add(duration);
      },
    );
  }

  test('a clean start runs every step once and ends running', () async {
    final steps = FakeSteps();
    final result = await launcher(steps).launch(requireTunnel: true);

    expect(result.success, isTrue);
    expect(steps.calls, ['core', 'config', 'tunnel', 'verify']);
    expect(states.map((s) => s.stage), [
      LaunchStage.startingCore,
      LaunchStage.applyingConfig,
      LaunchStage.startingTunnel,
      LaunchStage.running,
    ]);
    expect(states.last.attempt, 1);
    expect(waits, isEmpty);
  });

  test('a tunnel that comes up on the third try is a success', () async {
    // Two failed attempts, each torn down, with the growing pause between.
    final steps = FakeSteps(
      verify: const [
        StepOutcome.retry('down'),
        StepOutcome.retry('down'),
        StepOutcome.ok(),
      ],
    );
    final result = await launcher(
      steps,
      policy: policy.copyWithVerify(timeout: Duration.zero),
    ).launch(requireTunnel: true);

    expect(result.success, isTrue);
    expect(steps.teardowns, 2);
    expect(waits, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    expect(states.last.stage, LaunchStage.running);
    expect(states.last.attempt, 3);
    // The button sees the attempt number while the retry is on its way.
    expect(
      states
          .where((s) => s.stage == LaunchStage.startingCore)
          .map((s) => s.attempt),
      [1, 2, 3],
    );
  });

  test('a tunnel that never comes up fails after the last attempt', () async {
    final steps = FakeSteps(verify: const [StepOutcome.retry('down')]);
    final result = await launcher(
      steps,
      policy: policy.copyWithVerify(timeout: Duration.zero),
    ).launch(requireTunnel: true);

    expect(result.success, isFalse);
    expect(result.failure, LaunchFailure.tunnel);
    expect(result.message, 'down');
    expect(steps.teardowns, 3);
    expect(states.last.stage, LaunchStage.failed);
    expect(states.last.attempt, 3);
    expect(states.last.maxAttempts, 3);
    expect(states.last.message, 'down');
    // No pause after the final attempt: there is nothing left to wait for.
    expect(waits, [const Duration(seconds: 1), const Duration(seconds: 2)]);
  });

  test('a core that will not connect is a core failure', () async {
    final steps = FakeSteps(core: const [StepOutcome.retry('no core')]);
    final result = await launcher(steps).launch(requireTunnel: true);

    expect(result.failure, LaunchFailure.core);
    expect(steps.calls.where((c) => c == 'config'), isEmpty);
    expect(steps.teardowns, 3);
  });

  test('an abort stops on the spot without retrying', () async {
    // A refused elevation prompt: asking again is asking the same question.
    final steps = FakeSteps(
      config: const [StepOutcome.abort(LaunchFailure.config, 'refused')],
    );
    final result = await launcher(steps).launch(requireTunnel: true);

    expect(result.failure, LaunchFailure.config);
    expect(result.message, 'refused');
    expect(steps.teardowns, 1);
    expect(waits, isEmpty);
    expect(states.last.stage, LaunchStage.failed);
    expect(states.last.attempt, 1);
  });

  test('a start that does not need the tunnel skips verification', () async {
    final steps = FakeSteps(verify: const [StepOutcome.retry('down')]);
    final result = await launcher(steps).launch(requireTunnel: false);

    expect(result.success, isTrue);
    expect(steps.calls, ['core', 'config', 'tunnel']);
  });

  test('verification polls until the tunnel answers', () async {
    // Android answers "pending" while the consent dialog is up.
    final steps = FakeSteps(
      verify: const [
        StepOutcome.retry(''),
        StepOutcome.retry(''),
        StepOutcome.ok(),
      ],
    );
    final result = await launcher(steps).launch(requireTunnel: true);

    expect(result.success, isTrue);
    expect(steps.calls.where((c) => c == 'verify').length, 3);
    expect(waits, [
      const Duration(milliseconds: 300),
      const Duration(milliseconds: 300),
    ]);
    expect(steps.teardowns, 0);
  });

  test(
    'verification gives up after the timeout and the attempt fails',
    () async {
      final steps = FakeSteps(verify: const [StepOutcome.retry('pending')]);
      final result = await launcher(
        steps,
        policy: const LaunchPolicy(
          maxAttempts: 1,
          verifyTimeout: Duration(milliseconds: 900),
          verifyInterval: Duration(milliseconds: 300),
        ),
      ).launch(requireTunnel: true);

      expect(result.failure, LaunchFailure.tunnel);
      // 0, 300, 600, 900 ms: four looks before the timeout is reached.
      expect(steps.calls.where((c) => c == 'verify').length, 4);
      expect(steps.teardowns, 1);
    },
  );

  test('cancel during the backoff pause ends the launch quietly', () async {
    final steps = FakeSteps(verify: const [StepOutcome.retry('down')]);
    late VpnLauncher vpn;
    vpn = VpnLauncher(
      steps: steps,
      policy: policy.copyWithVerify(timeout: Duration.zero),
      onState: (state) => states.add(state),
      wait: (duration) async {
        // The pause never elapses; the cancel is what wakes the loop.
        vpn.cancel();
      },
    );
    states = [];
    final result = await vpn.launch(requireTunnel: true);

    expect(result.failure, LaunchFailure.cancelled);
    expect(result.message, isNull);
    expect(steps.teardowns, 1);
    expect(steps.calls.where((c) => c == 'core').length, 1);
    expect(states.last.stage, LaunchStage.idle);
    expect(vpn.isLaunching, isFalse);
  });

  test('cancel with a reason is reported as that failure', () async {
    // The VPN consent dialog was refused while verification was polling.
    final steps = FakeSteps(verify: const [StepOutcome.retry('')]);
    late VpnLauncher vpn;
    vpn = launcher(steps);
    steps.onVerify = () {
      vpn.cancel(reason: LaunchFailure.vpnPermission, message: 'denied');
    };
    final result = await vpn.launch(requireTunnel: true);

    expect(result.failure, LaunchFailure.vpnPermission);
    expect(result.message, 'denied');
    expect(steps.teardowns, 1);
    expect(states.last.stage, LaunchStage.failed);
    expect(states.last.failure, LaunchFailure.vpnPermission);
  });

  test('a second launch while one is running is ignored', () async {
    final steps = FakeSteps();
    final vpn = launcher(steps);
    final first = vpn.launch(requireTunnel: true);
    expect(vpn.isLaunching, isTrue);
    final second = await vpn.launch(requireTunnel: true);

    expect(second.ignored, isTrue);
    expect(second.success, isFalse);
    expect((await first).success, isTrue);
    expect(steps.calls.where((c) => c == 'core').length, 1);
    expect(vpn.isLaunching, isFalse);
  });

  test('cancel when nothing is launching does nothing', () {
    final vpn = launcher(FakeSteps());
    vpn.cancel();
    expect(vpn.isLaunching, isFalse);
    expect(states, isEmpty);
  });

  test('the pause after an attempt clamps to the last delay', () {
    const short = LaunchPolicy(
      maxAttempts: 5,
      delays: [Duration(seconds: 1), Duration(seconds: 2)],
    );
    expect(short.delayAfter(1), const Duration(seconds: 1));
    expect(short.delayAfter(2), const Duration(seconds: 2));
    expect(short.delayAfter(4), const Duration(seconds: 2));
    expect(const LaunchPolicy(delays: []).delayAfter(1), Duration.zero);
  });
}

extension on LaunchPolicy {
  LaunchPolicy copyWithVerify({required Duration timeout}) => LaunchPolicy(
    maxAttempts: maxAttempts,
    delays: delays,
    verifyTimeout: timeout,
    verifyInterval: verifyInterval,
  );
}
