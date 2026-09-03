import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// Outcome of one launch step.
///
/// `retry` is a failure the next attempt may fix (the core did not connect,
/// the TUN device did not come up). `abort` is one it cannot: an elevation
/// prompt that was refused, a VPN permission that was denied. Retrying those
/// would only prompt the user again for the same answer.
sealed class StepOutcome {
  const StepOutcome();

  const factory StepOutcome.ok() = StepOk;

  const factory StepOutcome.retry(String message) = StepRetry;

  const factory StepOutcome.abort(LaunchFailure failure, String message) =
      StepAbort;
}

class StepOk extends StepOutcome {
  const StepOk();
}

class StepRetry extends StepOutcome {
  final String message;

  const StepRetry(this.message);
}

class StepAbort extends StepOutcome {
  final LaunchFailure failure;
  final String message;

  const StepAbort(this.failure, this.message);
}

/// The two dependencies of a VPN start, plus the verification that says
/// whether they are really there. Implemented against the core and the
/// platform by the setup action; faked in tests.
abstract class LaunchSteps {
  /// The core is running and initialised, or has just been brought up.
  Future<StepOutcome> ensureCore();

  /// The profile is loaded into the core, including any elevation TUN needs.
  Future<StepOutcome> applyConfig();

  /// Ask for the listeners: TUN on desktop, the VpnService on Android.
  Future<StepOutcome> startTunnel();

  /// One look at whether the tunnel is up. The launcher polls this; return
  /// `retry` while it is still coming up.
  Future<StepOutcome> verifyTunnel();

  /// Undo a failed or cancelled attempt so the next one starts clean.
  Future<void> teardown();
}

/// How hard to try. Three attempts with a short, growing pause is enough to
/// ride out a slow core start or a TUN device that is still being released,
/// and short enough that a real failure is reported while the person is
/// still looking at the button.
class LaunchPolicy {
  final int maxAttempts;
  final List<Duration> delays;
  final Duration verifyTimeout;
  final Duration verifyInterval;

  const LaunchPolicy({
    this.maxAttempts = 3,
    this.delays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    this.verifyTimeout = const Duration(seconds: 10),
    this.verifyInterval = const Duration(milliseconds: 300),
  });

  /// Pause after a failed attempt (1-based). Clamps to the last delay.
  Duration delayAfter(int attempt) {
    if (delays.isEmpty) return Duration.zero;
    final index = attempt - 1;
    return delays[index < delays.length ? index : delays.length - 1];
  }
}

class LaunchResult {
  final bool success;
  final LaunchFailure? failure;
  final String? message;

  /// A second launch while one is in progress does nothing and says so.
  final bool ignored;

  const LaunchResult._({
    required this.success,
    this.failure,
    this.message,
    this.ignored = false,
  });

  const LaunchResult.success() : this._(success: true);

  const LaunchResult.failed(LaunchFailure failure, String? message)
    : this._(success: false, failure: failure, message: message);

  const LaunchResult.ignored() : this._(success: false, ignored: true);
}

typedef LaunchWait = Future<void> Function(Duration duration);

Future<void> _defaultWait(Duration duration) => Future.delayed(duration);

/// Runs a VPN launch as a bounded retry loop over [LaunchSteps].
///
/// Pure Dart on purpose: no providers, no globals, no platform. Everything
/// that touches the world is behind [steps] and [wait], so the loop itself is
/// tested without a core.
class VpnLauncher {
  final LaunchSteps steps;
  final LaunchPolicy policy;
  final void Function(LaunchState state) onState;
  final LaunchWait _wait;

  bool _launching = false;
  bool _cancelled = false;
  LaunchFailure _cancelReason = LaunchFailure.cancelled;
  String? _cancelMessage;
  Completer<void>? _sleeping;

  VpnLauncher({
    required this.steps,
    required this.onState,
    this.policy = const LaunchPolicy(),
    LaunchWait wait = _defaultWait,
  }) : _wait = wait;

  bool get isLaunching => _launching;

  /// Stop the launch in progress. Checked between steps and interrupts a
  /// backoff pause. [reason] lets the platform say why (a denied VPN
  /// permission is a cancel from outside, not a retryable failure).
  void cancel({
    LaunchFailure reason = LaunchFailure.cancelled,
    String? message,
  }) {
    if (!_launching) return;
    _cancelled = true;
    _cancelReason = reason;
    _cancelMessage = message;
    final sleeping = _sleeping;
    if (sleeping != null && !sleeping.isCompleted) {
      sleeping.complete();
    }
  }

  Future<LaunchResult> launch({required bool requireTunnel}) async {
    if (_launching) return const LaunchResult.ignored();
    _launching = true;
    _cancelled = false;
    _cancelReason = LaunchFailure.cancelled;
    _cancelMessage = null;
    try {
      return await _run(requireTunnel: requireTunnel);
    } finally {
      _launching = false;
    }
  }

  Future<LaunchResult> _run({required bool requireTunnel}) async {
    final maxAttempts = policy.maxAttempts;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final failure = await _attempt(
        attempt: attempt,
        maxAttempts: maxAttempts,
        requireTunnel: requireTunnel,
      );
      if (failure == null) {
        _emit(LaunchStage.running, attempt, maxAttempts);
        return const LaunchResult.success();
      }
      await steps.teardown();
      if (_cancelled) {
        return _cancelledResult();
      }
      if (failure.terminal || attempt == maxAttempts) {
        return _fail(failure.kind, failure.message, attempt, maxAttempts);
      }
      await _pause(policy.delayAfter(attempt));
      if (_cancelled) {
        return _cancelledResult();
      }
    }
    // Unreachable with maxAttempts >= 1; keeps the analyzer honest.
    return _fail(LaunchFailure.core, null, maxAttempts, maxAttempts);
  }

  /// One attempt. Returns null on success, else what stopped it.
  Future<_AttemptFailure?> _attempt({
    required int attempt,
    required int maxAttempts,
    required bool requireTunnel,
  }) async {
    _emit(LaunchStage.startingCore, attempt, maxAttempts);
    var failure = _check(await steps.ensureCore(), LaunchFailure.core);
    if (failure != null) return failure;

    _emit(LaunchStage.applyingConfig, attempt, maxAttempts);
    failure = _check(await steps.applyConfig(), LaunchFailure.config);
    if (failure != null) return failure;

    _emit(LaunchStage.startingTunnel, attempt, maxAttempts);
    failure = _check(await steps.startTunnel(), LaunchFailure.tunnel);
    if (failure != null) return failure;

    if (!requireTunnel) return null;
    return _check(await _verify(), LaunchFailure.tunnel);
  }

  /// Turn a step outcome into a failure of the given kind, or null when the
  /// step passed. A cancel that arrived while the step ran counts as a
  /// failure so the loop tears down and reports it.
  _AttemptFailure? _check(StepOutcome outcome, LaunchFailure kind) {
    if (_cancelled) {
      return const _AttemptFailure(
        LaunchFailure.cancelled,
        null,
        terminal: true,
      );
    }
    return switch (outcome) {
      StepOk() => null,
      StepRetry(:final message) => _AttemptFailure(kind, message),
      StepAbort(:final failure, :final message) => _AttemptFailure(
        failure,
        message,
        terminal: true,
      ),
    };
  }

  /// Poll [LaunchSteps.verifyTunnel] until it is ok, aborts, or the timeout
  /// passes. On Android the first answers are "pending" while the permission
  /// dialog is up, which is waiting, not failing.
  Future<StepOutcome> _verify() async {
    var elapsed = Duration.zero;
    while (true) {
      final outcome = await steps.verifyTunnel();
      if (_cancelled || outcome is! StepRetry) return outcome;
      if (elapsed >= policy.verifyTimeout) return outcome;
      await _pause(policy.verifyInterval);
      elapsed += policy.verifyInterval;
      if (_cancelled) return outcome;
    }
  }

  Future<void> _pause(Duration duration) async {
    if (duration == Duration.zero) return;
    final sleeping = Completer<void>();
    _sleeping = sleeping;
    unawaited(
      _wait(duration).then((_) {
        if (!sleeping.isCompleted) sleeping.complete();
      }),
    );
    await sleeping.future;
    _sleeping = null;
  }

  void _emit(
    LaunchStage stage,
    int attempt,
    int maxAttempts, {
    LaunchFailure? failure,
    String? message,
  }) {
    onState(
      LaunchState(
        stage: stage,
        attempt: attempt,
        maxAttempts: maxAttempts,
        failure: failure,
        message: message,
      ),
    );
  }

  LaunchResult _fail(
    LaunchFailure failure,
    String? message,
    int attempt,
    int maxAttempts,
  ) {
    _emit(
      LaunchStage.failed,
      attempt,
      maxAttempts,
      failure: failure,
      message: message,
    );
    return LaunchResult.failed(failure, message);
  }

  LaunchResult _cancelledResult() {
    if (_cancelReason == LaunchFailure.cancelled) {
      _emit(LaunchStage.idle, 0, policy.maxAttempts);
      return const LaunchResult.failed(LaunchFailure.cancelled, null);
    }
    _emit(
      LaunchStage.failed,
      0,
      policy.maxAttempts,
      failure: _cancelReason,
      message: _cancelMessage,
    );
    return LaunchResult.failed(_cancelReason, _cancelMessage);
  }
}

class _AttemptFailure {
  final LaunchFailure kind;
  final String? message;
  final bool terminal;

  const _AttemptFailure(this.kind, this.message, {this.terminal = false});
}
