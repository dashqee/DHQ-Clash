import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

String videoCallTunnelStatusText(
  BuildContext context,
  VideoCallTunnelStatus status,
) {
  return switch (status) {
    VideoCallTunnelStatus.disabled =>
      context.appLocalizations.turnTunnelDisabled,
    VideoCallTunnelStatus.checking =>
      context.appLocalizations.turnTunnelChecking,
    VideoCallTunnelStatus.notEntitled =>
      context.appLocalizations.turnTunnelNotEntitled,
    VideoCallTunnelStatus.temporarilyUnavailable =>
      context.appLocalizations.turnTunnelTemporarilyUnavailable,
    VideoCallTunnelStatus.starting =>
      context.appLocalizations.turnTunnelStarting,
    VideoCallTunnelStatus.connecting =>
      context.appLocalizations.turnTunnelConnecting,
    VideoCallTunnelStatus.captchaRequired =>
      context.appLocalizations.turnTunnelCaptchaTitle,
    VideoCallTunnelStatus.connected =>
      context.appLocalizations.turnTunnelConnected,
    VideoCallTunnelStatus.reconnecting =>
      context.appLocalizations.turnTunnelReconnecting,
    VideoCallTunnelStatus.stopped => context.appLocalizations.turnTunnelStopped,
    VideoCallTunnelStatus.error => context.appLocalizations.turnTunnelError,
  };
}

class VideoCallTunnelView extends StatelessWidget {
  const VideoCallTunnelView({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: context.appLocalizations.turnTunnel,
      body: const VideoCallTunnelPanel(),
    );
  }
}

class VideoCallTunnelPanel extends ConsumerWidget {
  const VideoCallTunnelPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      videoCallTunnelSettingProvider.select((state) => state.enable),
    );
    final pinned = ref.watch(
      videoCallTunnelSettingProvider.select((state) => state.pinned),
    );
    return ListView(
      key: const ValueKey('video-call-tunnel-panel'),
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.appLocalizations.turnTunnelEnable),
          subtitle: Text(context.appLocalizations.turnTunnelDesc),
          value: enabled,
          onChanged: (value) async {
            await ref
                .read(setupActionProvider.notifier)
                .setVideoCallTunnelEnabled(value);
          },
        ),
        // Everything, including what the rules would normally keep direct, goes
        // into the call while this is on. Left unsaid, that reads as the app
        // having broken rather than as the state the user asked for.
        if (enabled && pinned)
          Card.filled(
            key: const ValueKey('video-call-tunnel-pinned'),
            child: ListTile(
              leading: const Icon(Icons.alt_route),
              title: Text(context.appLocalizations.turnTunnelPinned),
              subtitle: Text(context.appLocalizations.turnTunnelPinnedDesc),
            ),
          ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: Listenable.merge([
            videoCallTunnelController.status,
            videoCallTunnelController.captchaUri,
          ]),
          builder: (_, child) {
            final status = videoCallTunnelController.status.value;
            final captchaUri = videoCallTunnelController.captchaUri.value;
            final canRetry =
                enabled &&
                {
                  VideoCallTunnelStatus.notEntitled,
                  VideoCallTunnelStatus.temporarilyUnavailable,
                  VideoCallTunnelStatus.error,
                  VideoCallTunnelStatus.stopped,
                }.contains(status);
            return Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    status == VideoCallTunnelStatus.connected
                        ? Icons.check_circle_outline
                        : Icons.videocam_outlined,
                  ),
                  title: Text(context.appLocalizations.status),
                  subtitle: Text(videoCallTunnelStatusText(context, status)),
                ),
                if (captchaUri != null)
                  Card.filled(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(
                        context.appLocalizations.turnTunnelCaptchaTitle,
                      ),
                      subtitle: Text(
                        context.appLocalizations.turnTunnelCaptchaDesc,
                      ),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => launchUrl(
                          captchaUri,
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_browser),
                        label: Text(
                          context.appLocalizations.turnTunnelCaptchaOpen,
                        ),
                      ),
                    ),
                  ),
                if (canRetry)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('retry-video-call-tunnel'),
                      onPressed: () async {
                        await ref
                            .read(setupActionProvider.notifier)
                            .refreshVideoCallTunnel(
                              startTunnel: ref.read(isStartProvider),
                            );
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(context.appLocalizations.turnTunnelRetry),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
