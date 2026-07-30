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
    VideoCallTunnelStatus.starting =>
      context.appLocalizations.turnTunnelStarting,
    VideoCallTunnelStatus.connecting =>
      context.appLocalizations.turnTunnelConnecting,
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

class VideoCallTunnelPanel extends ConsumerStatefulWidget {
  const VideoCallTunnelPanel({super.key});

  @override
  ConsumerState<VideoCallTunnelPanel> createState() =>
      _VideoCallTunnelPanelState();
}

class _VideoCallTunnelPanelState extends ConsumerState<VideoCallTunnelPanel> {
  late final TextEditingController _joinLinkController;
  late final TextEditingController _displayNameController;
  late bool _enabled;
  late String _tunnelMode;
  String? _error;

  @override
  void initState() {
    super.initState();
    final props = ref.read(videoCallTunnelSettingProvider);
    _enabled = props.enable;
    _tunnelMode = props.tunnelMode;
    _joinLinkController = TextEditingController(text: props.joinLink);
    _displayNameController = TextEditingController(text: props.displayName);
  }

  @override
  void dispose() {
    _joinLinkController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final joinLink = _joinLinkController.text.trim();
    if (_enabled && !isValidVideoCallJoinLink(joinLink)) {
      setState(() => _error = context.appLocalizations.turnTunnelInvalidLink);
      return;
    }
    setState(() => _error = null);
    final previous = ref.read(videoCallTunnelSettingProvider);
    final next = previous.copyWith(
      enable: _enabled,
      joinLink: joinLink,
      displayName: _displayNameController.text.trim().isEmpty
          ? 'DHQ Clash'
          : _displayNameController.text.trim(),
      tunnelMode: _tunnelMode,
    );
    ref.read(videoCallTunnelSettingProvider.notifier).update((_) => next);
    if (ref.read(isStartProvider)) {
      if (next.enable) {
        await videoCallTunnelController.start(next);
      } else {
        await videoCallTunnelController.stop();
      }
      await ref
          .read(setupActionProvider.notifier)
          .applyProfile(force: true, silence: true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.appLocalizations.turnTunnelSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('video-call-tunnel-panel'),
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.appLocalizations.turnTunnelEnable),
          subtitle: Text(context.appLocalizations.turnTunnelDesc),
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _joinLinkController,
          enabled: _enabled,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: context.appLocalizations.turnTunnelJoinLink,
            hintText: 'https://vk.ru/call/join/…',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _displayNameController,
          enabled: _enabled,
          decoration: InputDecoration(
            labelText: context.appLocalizations.turnTunnelDisplayName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'dc',
              label: Text(context.appLocalizations.turnTunnelModeDc),
            ),
            ButtonSegment(
              value: 'video',
              label: Text(context.appLocalizations.turnTunnelModeVideo),
            ),
          ],
          selected: {_tunnelMode},
          onSelectionChanged: _enabled
              ? (value) => setState(() => _tunnelMode = value.single)
              : null,
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
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(context.appLocalizations.save),
        ),
      ],
    );
  }
}
