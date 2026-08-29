import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
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

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton> {
  late bool _isStart;

  @override
  void initState() {
    super.initState();
    _isStart = ref.read(isStartProvider);
    ref.listenManual(isStartProvider, (_, next) {
      if (mounted && next != _isStart) {
        setState(() {
          _isStart = next;
        });
      }
    }, fireImmediately: true);
  }

  Future<void> _handleSwitchStart() async {
    if (!_isStart &&
        needsTunToStart(
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
      if (enable != true || !mounted) return;
      ref.read(setupActionProvider.notifier).setTunEnabled(true);
    }

    setState(() {
      _isStart = !_isStart;
    });
    debouncer.call(FunctionTag.updateStatus, () {
      globalState.container
          .read(setupActionProvider.notifier)
          .updateStatus(_isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final suspend = ref.watch(suspendProvider);
    final appLocalizations = context.appLocalizations;
    final label = suspend
        ? appLocalizations.suspended
        : _isStart
        ? appLocalizations.stop
        : appLocalizations.start;
    final icon = suspend
        ? Icons.pause_circle_outline
        : _isStart
        ? Icons.stop_rounded
        : Icons.power_settings_new_rounded;

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
          onPressed: () => _handleSwitchStart(),
          style: FilledButton.styleFrom(
            minimumSize: const Size(156, 64),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          icon: AnimatedSwitcher(
            duration: commonDuration,
            child: Icon(icon, key: ValueKey(icon), size: 26),
          ),
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
