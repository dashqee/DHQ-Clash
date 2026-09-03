import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether pressing start should stop and explain instead of starting.
///
/// Without TUN the core still runs, but nothing is routed through it — the app
/// is a local proxy and the button looks exactly as it does when the tunnel is
/// up, which is the worst way to be unprotected.
///
/// Desktop only. On Android the tunnel is the system VpnService and this flag is
/// not the switch anybody sees; guarding on it there would block start for good.
bool needsTunToStart({
  required bool isStarting,
  required bool isDesktop,
  required bool tunEnabled,
}) => isStarting && isDesktop && !tunEnabled;

/// What the start button says for a launch in progress. The attempt count
/// only appears once a retry has happened: "attempt 1 of 3" on every start
/// would announce a problem nobody has yet.
String launchButtonLabel(
  LaunchState state, {
  required String connecting,
  required String Function(int attempt, int total) connectingAttempt,
}) {
  if (state.attempt > 1) {
    return connectingAttempt(state.attempt, state.maxAttempts);
  }
  return connecting;
}

class StartButton extends ConsumerWidget {
  const StartButton({super.key});

  Future<void> _handleSwitchStart(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
    required bool isLaunching,
  }) async {
    final setupAction = ref.read(setupActionProvider.notifier);
    if (isStart || isLaunching) {
      // Stopping is always allowed, including a launch still on its way.
      setupAction.updateStatus(false);
      return;
    }
    if (needsTunToStart(
      isStarting: true,
      isDesktop: system.isDesktop,
      tunEnabled: ref.read(
        patchClashConfigProvider.select((state) => state.tun.enable),
      ),
    )) {
      final appLocalizations = context.appLocalizations;
      final enable = await globalState.showMessage(
        title: appLocalizations.tun,
        message: TextSpan(text: appLocalizations.startRequiresTun),
        confirmText: appLocalizations.enableTun,
      );
      // The dialog is awaited, so the screen may be gone by the time it
      // returns; ref is disposed with it.
      if (enable != true || !context.mounted) return;
      setupAction.setTunEnabled(true);
    }
    // No debounce: the launcher ignores a second start while one is running.
    setupAction.updateStatus(true, isInit: !ref.read(initProvider));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suspend = ref.watch(suspendProvider);
    final isStart = ref.watch(isStartProvider);
    final launchState = ref.watch(launchStateProvider);
    final isLaunching = launchState.isLaunching;
    final appLocalizations = context.appLocalizations;
    final label = suspend
        ? appLocalizations.suspended
        : isLaunching
        ? launchButtonLabel(
            launchState,
            connecting: appLocalizations.connecting,
            connectingAttempt: appLocalizations.connectingAttempt,
          )
        : isStart
        ? appLocalizations.stop
        : appLocalizations.start;
    final icon = suspend
        ? Icons.pause_circle_outline
        : isStart
        ? Icons.stop_rounded
        : Icons.power_settings_new_rounded;
    final Widget iconWidget = isLaunching && !suspend
        ? const SizedBox(
            key: ValueKey('start-button-progress'),
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Icon(icon, key: ValueKey(icon), size: 26);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 156, minHeight: 64),
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          gradient: AppTheme.brandGradient,
          shape: StadiumBorder(side: BorderSide(color: Color(0x33FFFFFF))),
          shadows: [
            BoxShadow(
              color: Color(0x594877F4),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: () => _handleSwitchStart(
            context,
            ref,
            isStart: isStart,
            isLaunching: isLaunching,
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(156, 64),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          icon: AnimatedSwitcher(duration: commonDuration, child: iconWidget),
          label: AnimatedSwitcher(
            duration: commonDuration,
            child: Text(
              label,
              key: ValueKey(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
