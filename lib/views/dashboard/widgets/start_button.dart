import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void _handleSwitchStart() {
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
          onPressed: _handleSwitchStart,
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
