import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MacosTunManager extends ConsumerStatefulWidget {
  final Widget child;

  const MacosTunManager({super.key, required this.child});

  @override
  ConsumerState<MacosTunManager> createState() => _MacosTunManagerState();
}

class _MacosTunManagerState extends ConsumerState<MacosTunManager> {
  Future<void> _pendingUpdate = Future.value();

  Future<void> _update(TrayState state) async {
    if (!macosTun.isPrepared) return;

    final shouldRun = state.isStart && state.tunEnable;
    final result = shouldRun
        ? await macosTun.start(state.port)
        : await macosTun.stop();
    if (!result) {
      commonPrint.log(
        'update macOS Network Extension failed',
        logLevel: LogLevel.warning,
      );
    }
  }

  void _scheduleUpdate(TrayState state) {
    _pendingUpdate = _pendingUpdate.then((_) => _update(state)).catchError((
      Object error,
    ) {
      commonPrint.log(
        'update macOS Network Extension failed: $error',
        logLevel: LogLevel.warning,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    macosTun.addListener(_handlePrepared);
    ref.listenManual(trayStateProvider, (previous, next) {
      final previousTunState = previous == null
          ? null
          : (previous.isStart, previous.tunEnable, previous.port);
      final nextTunState = (next.isStart, next.tunEnable, next.port);
      if (previousTunState != nextTunState) {
        _scheduleUpdate(next);
      }
    }, fireImmediately: true);
  }

  void _handlePrepared() {
    _scheduleUpdate(ref.read(trayStateProvider));
  }

  @override
  void dispose() {
    macosTun.removeListener(_handlePrepared);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
