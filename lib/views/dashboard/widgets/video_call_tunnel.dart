import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/video_call_tunnel.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardVideoCallTunnelSection extends ConsumerWidget {
  const DashboardVideoCallTunnelSection({super.key});

  void _openSettings(BuildContext context) {
    showSheet(
      context: context,
      builder: (_) {
        return AdaptiveSheetScaffold(
          title: context.appLocalizations.turnTunnel,
          body: const VideoCallTunnelPanel(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      videoCallTunnelSettingProvider.select((state) => state.enable),
    );

    return ListenableBuilder(
      listenable: videoCallTunnelController.status,
      builder: (context, _) {
        final currentStatus = enabled
            ? videoCallTunnelController.status.value
            : VideoCallTunnelStatus.disabled;
        final statusColor = switch (currentStatus) {
          VideoCallTunnelStatus.connected => AppTheme.cyan,
          VideoCallTunnelStatus.starting ||
          VideoCallTunnelStatus.checking ||
          VideoCallTunnelStatus.connecting ||
          VideoCallTunnelStatus.captchaRequired ||
          VideoCallTunnelStatus.reconnecting => AppTheme.blue,
          VideoCallTunnelStatus.error ||
          VideoCallTunnelStatus.notEntitled => AppTheme.danger,
          VideoCallTunnelStatus.temporarilyUnavailable => AppTheme.violet,
          VideoCallTunnelStatus.disabled ||
          VideoCallTunnelStatus.stopped => AppTheme.muted,
        };
        return Container(
          key: const ValueKey('dashboard-video-call-tunnel'),
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh.withValues(alpha: 0.72),
            border: Border.all(color: AppTheme.line),
            borderRadius: AppTheme.borderRadiusLg,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final details = Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: AppTheme.borderRadiusMd,
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(Icons.video_call_outlined, color: statusColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.appLocalizations.turnTunnel,
                          style: context.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          enabled
                              ? videoCallTunnelStatusText(
                                  context,
                                  currentStatus,
                                )
                              : context.appLocalizations.turnTunnelDisabled,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final action = FilledButton.tonalIcon(
                key: const ValueKey('open-video-call-tunnel-settings'),
                onPressed: () => _openSettings(context),
                icon: const Icon(Icons.tune),
                label: Text(context.appLocalizations.options),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [details, const SizedBox(height: 14), action],
                );
              }
              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 18),
                  action,
                ],
              );
            },
          ),
        );
      },
    );
  }
}
