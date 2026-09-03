import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'generated/action.g.dart';

@visibleForTesting
Profile profileForInstallUrl(
  List<Profile> profiles, {
  required String url,
  String? name,
}) {
  final existingProfile = profiles
      .where((profile) => profile.url == url)
      .firstOrNull;
  final profile =
      existingProfile ??
      Profile.normal(url: url, label: name?.isNotEmpty == true ? name : null);
  return profile.copyWith(
    label: name?.isNotEmpty == true ? name! : profile.label,
  );
}

bool shouldRestartCoreForTun({
  required bool isWindows,
  required bool isStarted,
  required bool? previousEnable,
  required bool nextEnable,
}) {
  return isWindows &&
      isStarted &&
      previousEnable == false &&
      nextEnable == true;
}

typedef ProfileRefresher = Future<Profile> Function(Profile profile);

/// Guard shared by every place that writes the outbound mode. Refusing is not
/// enough on its own — a tap that appears to do nothing reads as a bug — so it
/// also says why.
bool isModeChangeAllowed(Ref ref, Mode mode) {
  final props = ref.read(videoCallTunnelSettingProvider);
  if (videoCallTunnelAllowsMode(props, mode)) return true;
  // Taken from the tree rather than from AppLocalizations.current: that one
  // asserts when no delegate has loaded, and this guard runs from the tray and
  // the hotkey as well as from the dashboard.
  final context = globalState.navigatorKey.currentContext;
  if (context != null) {
    globalState.showNotifier(
      context.appLocalizations.turnTunnelPinnedModeLocked,
    );
  }
  return false;
}

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  @override
  void build() {}

  void updateStart() {
    ref
        .read(setupActionProvider.notifier)
        .updateStatus(!ref.read(isStartProvider));
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      final next = Mode.values[nextIndex];
      if (!isModeChangeAllowed(ref, next)) return state;
      return state.copyWith(mode: next);
    });
  }

  void updateRunTime() {
    final startTime = ref.read(setupActionProvider.notifier).startTime;
    if (startTime != null) {
      final startTimeStamp = startTime.millisecondsSinceEpoch;
      final nowTimeStamp = DateTime.now().millisecondsSinceEpoch;
      ref.read(runTimeProvider.notifier).value = nowTimeStamp - startTimeStamp;
    } else {
      ref.read(runTimeProvider.notifier).value = null;
    }
  }

  Future<void> updateTraffic() async {
    final onlyStatisticsProxy = ref.read(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    final traffic = await coreController.getTraffic(onlyStatisticsProxy);
    ref.read(trafficsProvider.notifier).addTraffic(traffic);
    ref.read(totalTrafficProvider.notifier).value = await coreController
        .getTotalTraffic(onlyStatisticsProxy);
  }

  Future<void> autoCheckUpdate() async {
    final appSetting = ref.read(appSettingProvider);
    if (!appSetting.autoCheckUpdate) return;
    final res = await request.checkForUpdate(channel: appSetting.updateChannel);
    checkUpdateResultHandle(data: res);
  }

  Future<void> checkForUpdate() async {
    final updateChannel = ref.read(appSettingProvider).updateChannel;
    final data = await globalState.safeRun<Map<String, dynamic>?>(
      () =>
          request.checkForUpdate(channel: updateChannel, includeCurrent: true),
      title: currentAppLocalizations.checkUpdate,
    );
    await checkUpdateResultHandle(data: data, isUser: true);
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool isUser = false,
  }) async {
    if (data == null) {
      if (isUser) {
        globalState.showMessage(
          title: currentAppLocalizations.checkUpdate,
          message: TextSpan(text: currentAppLocalizations.checkUpdateError),
        );
      }
      return;
    }
    final info = AppUpdateInfo.fromResponse(
      data,
      appVersion: globalState.appVersion,
    );
    if (!info.hasUpdate) {
      ref.read(pendingUpdateProvider.notifier).value = null;
      if (isUser) {
        final releaseNotes = utils.formatReleaseNotes(info.notes);
        final textTheme = globalState.navigatorKey.currentContext!.textTheme;
        await globalState.showMessage(
          title: currentAppLocalizations.latestVersion,
          message: TextSpan(
            text: '${info.version} \n',
            style: textTheme.headlineSmall,
            children: [
              TextSpan(
                text:
                    '\n${currentAppLocalizations.releaseNotes}\n\n'
                    '${releaseNotes.isEmpty ? currentAppLocalizations.noInfo : releaseNotes}',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
          cancelable: false,
          maxWidth: 480,
          maxHeight: 420,
        );
      }
      return;
    }
    ref.read(pendingUpdateProvider.notifier).value = info;
    await promptUpdate(info);
  }

  /// Offer to install [info] now. "Later" changes nothing: the marker in the
  /// sidebar stays, and the next launch asks again. The old "don't remind
  /// again" used to switch the automatic check off for good, which is how
  /// people ended up several releases behind without knowing.
  Future<void> promptUpdate(AppUpdateInfo info) async {
    final install = await globalState.showCommonDialog<bool>(
      child: UpdatePromptDialog(
        version: info.version,
        notes: utils.formatReleaseNotes(info.notes),
      ),
    );
    if (install == true) {
      await _downloadAndInstallUpdate(info);
    }
  }

  /// The sidebar entry: bring back what is already pending, otherwise look.
  Future<void> showPendingUpdateOrCheck() async {
    final pending = ref.read(pendingUpdateProvider);
    if (pending != null) {
      await promptUpdate(pending);
      return;
    }
    await checkForUpdate();
  }

  Future<void> _downloadAndInstallUpdate(AppUpdateInfo info) async {
    final url = info.url;
    final filename = info.filename;
    final sha256Hex = info.sha256;
    if (url.isEmpty || filename.isEmpty) return;

    // Platforms without an in-app installer path fall back to opening the
    // download in the browser.
    if (!AppUpdater.isSupported) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }

    final progress = ValueNotifier<double>(0);
    globalState.showCommonDialog<void>(
      dismissible: false,
      child: PopScope(
        canPop: false,
        child: CommonDialog(
          title: currentAppLocalizations.download,
          actions: const [],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, value, __) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: value > 0 ? value : null),
                  const SizedBox(height: 8),
                  Text('${(value * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final error = await AppUpdater.downloadAndInstall(
      url: url,
      filename: filename,
      sha256Hex: sha256Hex,
      onProgress: (p) => progress.value = p,
      // Desktop installs are unattended: once the new build is staged the app
      // has to go down cleanly (system proxy off, DNS restored, core stopped)
      // before the installer swaps it out and relaunches it.
      onQuit: () => ref.read(systemActionProvider.notifier).handleExit(),
    );

    // Close the progress dialog (on desktop the app has already exited).
    final ctx = globalState.navigatorKey.currentContext;
    if (ctx != null && Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).pop();
    }
    progress.dispose();

    if (error != null) {
      globalState.showMessage(
        title: currentAppLocalizations.checkUpdate,
        message: TextSpan(text: error),
      );
    }
  }
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  Timer? _updateTimer;
  Timer? _turnLinkRetryTimer;
  Timer? _turnAssignmentHeartbeatTimer;
  Timer? _turnEntitlementRecheckTimer;
  Timer? _turnReconnectGraceTimer;
  Timer? _turnPinGraceTimer;
  final Random _turnRetryRandom = Random();
  bool _isRefreshingTurnLink = false;
  int _turnRetryAttempt = 0;
  String? _turnJoinLink;
  String? _turnSubscriptionUrl;
  DateTime? startTime;
  Future<LaunchResult>? _activeLaunch;

  late final VpnLauncher _launcher = VpnLauncher(
    steps: _SetupLaunchSteps(this, ref),
    onState: (state) {
      ref.read(launchStateProvider.notifier).value = state;
    },
  );

  bool get isStart => startTime != null && startTime!.isBeforeNow;

  bool get isLaunching => _launcher.isLaunching;

  @override
  void build() {
    videoCallTunnelController.onTunnelLost = _handleVideoCallTunnelLost;
    videoCallTunnelController.onTunnelConnected =
        _handleVideoCallTunnelConnected;
    videoCallTunnelController.onTerminalError =
        _handleVideoCallTunnelTerminalError;
    videoCallTunnelController.onJoinTimeout = _handleVideoCallTunnelJoinTimeout;
    ref.onDispose(() {
      _turnLinkRetryTimer?.cancel();
      _turnAssignmentHeartbeatTimer?.cancel();
      _turnEntitlementRecheckTimer?.cancel();
      _turnReconnectGraceTimer?.cancel();
      _turnPinGraceTimer?.cancel();
      if (videoCallTunnelController.onTunnelLost ==
          _handleVideoCallTunnelLost) {
        videoCallTunnelController.onTunnelLost = null;
      }
      if (videoCallTunnelController.onTunnelConnected ==
          _handleVideoCallTunnelConnected) {
        videoCallTunnelController.onTunnelConnected = null;
      }
      if (videoCallTunnelController.onTerminalError ==
          _handleVideoCallTunnelTerminalError) {
        videoCallTunnelController.onTerminalError = null;
      }
      if (videoCallTunnelController.onJoinTimeout ==
          _handleVideoCallTunnelJoinTimeout) {
        videoCallTunnelController.onJoinTimeout = null;
      }
    });
  }

  void _cancelTurnLinkRetry() {
    _turnLinkRetryTimer?.cancel();
    _turnLinkRetryTimer = null;
    _turnRetryAttempt = 0;
  }

  void _scheduleTurnLinkRetry() {
    if (_turnLinkRetryTimer?.isActive == true) return;
    const retrySeconds = [5, 10, 20, 30, 60];
    final baseSeconds =
        retrySeconds[min(_turnRetryAttempt, retrySeconds.length - 1)];
    _turnRetryAttempt++;
    final jitter = 0.8 + (_turnRetryRandom.nextDouble() * 0.4);
    final delay = Duration(milliseconds: (baseSeconds * jitter * 1000).round());
    _turnLinkRetryTimer = Timer(delay, () {
      _turnLinkRetryTimer = null;
      if (!isStart) return;
      unawaited(refreshVideoCallTunnel());
    });
  }

  void _cancelTurnAssignmentHeartbeat() {
    _turnAssignmentHeartbeatTimer?.cancel();
    _turnAssignmentHeartbeatTimer = null;
  }

  void _cancelTurnEntitlementRecheck() {
    _turnEntitlementRecheckTimer?.cancel();
    _turnEntitlementRecheckTimer = null;
  }

  void _cancelTurnReconnectGrace() {
    _turnReconnectGraceTimer?.cancel();
    _turnReconnectGraceTimer = null;
  }

  void _cancelTurnPinGrace() {
    _turnPinGraceTimer?.cancel();
    _turnPinGraceTimer = null;
  }

  /// Bound how long everything may keep pointing at a tunnel that is not up.
  ///
  /// Pinned, the catch-all rule sends every route into the call, so a channel
  /// that never comes back is a machine with no internet and nothing on screen
  /// to say why. The sidecar keeps retrying either way — this only gives the
  /// routing back while it does.
  void _scheduleTurnPinGrace() {
    if (_turnPinGraceTimer?.isActive == true) return;
    _turnPinGraceTimer = Timer(videoCallTunnelPinGrace, () async {
      _turnPinGraceTimer = null;
      if (videoCallTunnelController.status.value ==
          VideoCallTunnelStatus.connected) {
        return;
      }
      if (!ref.read(videoCallTunnelSettingProvider).pinned) return;
      commonPrint.log(
        'TURN tunnel still down; releasing the routing pin',
        logLevel: LogLevel.warning,
      );
      await _unpinVideoCallTunnelRouting();
      if (isStart) {
        await applyProfile(force: true, silence: true);
      }
      globalState.showNotifier(currentAppLocalizations.turnTunnelPinReleased);
      unawaited(_reportVideoCallTunnelStatus(ok: false, reason: 'tunnel_down'));
    });
  }

  Future<void> _reportVideoCallTunnelStatus({
    required bool ok,
    String? reason,
  }) async {
    // Only the subscription we actually fetched a link from, never the current
    // profile: reading that provider opens the database, which drags
    // path_provider and its platform channel into every caller.
    final url = _turnSubscriptionUrl;
    if (url == null || url.isEmpty) return;
    await request.reportVideoCallTunnelStatus(url, ok: ok, reason: reason);
  }

  /// Restarts the silence window. Rescheduling (rather than keeping the first timer)
  /// is what makes this "no progress for 60s" instead of "no recovery in 60s" — the
  /// sidecar's own retry sequence can legitimately run longer than one window.
  void _scheduleTurnReconnectGrace() {
    _cancelTurnReconnectGrace();
    _turnReconnectGraceTimer = Timer(videoCallTunnelReconnectGrace, () {
      _turnReconnectGraceTimer = null;
      if (!ref.read(videoCallTunnelSettingProvider).enable) return;
      if (videoCallTunnelController.status.value ==
          VideoCallTunnelStatus.connected) {
        return;
      }
      commonPrint.log('TURN tunnel did not recover on its own; restarting');
      unawaited(_restartVideoCallTunnel());
    });
  }

  @visibleForTesting
  bool get hasPendingTurnReconnectGrace =>
      _turnReconnectGraceTimer?.isActive == true;

  @visibleForTesting
  bool get hasPendingTurnEntitlementRecheck =>
      _turnEntitlementRecheckTimer?.isActive == true;

  /// A slot bought (or moved to this device) in the mini app must be picked up
  /// without restarting the app, so `notEntitled` schedules a slow re-ask rather
  /// than giving up for good.
  void _scheduleTurnEntitlementRecheck() {
    if (_turnEntitlementRecheckTimer?.isActive == true) return;
    _turnEntitlementRecheckTimer = Timer(videoCallTunnelEntitlementRecheck, () {
      _turnEntitlementRecheckTimer = null;
      if (!ref.read(videoCallTunnelSettingProvider).enable) return;
      unawaited(refreshVideoCallTunnel(startTunnel: isStart));
    });
  }

  void _scheduleTurnAssignmentHeartbeat() {
    _cancelTurnAssignmentHeartbeat();
    _turnAssignmentHeartbeatTimer = Timer.periodic(
      videoCallTunnelAssignmentHeartbeat,
      (_) {
        if (!isStart || !ref.read(videoCallTunnelSettingProvider).enable) {
          _cancelTurnAssignmentHeartbeat();
          return;
        }
        unawaited(refreshVideoCallTunnel());
      },
    );
  }

  Future<VideoCallTunnelProps?> _resolveVideoCallTunnelProps({
    VideoCallTunnelLinkFetcher? fetchLink,
  }) async {
    final props = ref.read(videoCallTunnelSettingProvider);
    if (!props.enable) return null;
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.url.isEmpty) {
      _cancelTurnAssignmentHeartbeat();
      _turnJoinLink = null;
      _turnSubscriptionUrl = null;
      videoCallTunnelController.status.value = VideoCallTunnelStatus.error;
      return null;
    }

    final subscriptionChanged = _turnSubscriptionUrl != profile.url;
    if (subscriptionChanged) {
      _cancelTurnAssignmentHeartbeat();
      _turnJoinLink = null;
    }
    _turnSubscriptionUrl = profile.url;
    if (_turnJoinLink == null &&
        videoCallTunnelController.status.value !=
            VideoCallTunnelStatus.reconnecting) {
      videoCallTunnelController.status.value = VideoCallTunnelStatus.checking;
    }
    final result = await (fetchLink ?? request.getVideoCallTunnelLink)(
      profile.url,
    );
    switch (result.status) {
      case VideoCallTunnelLinkStatus.available:
        final joinLink = result.joinLink!;
        _cancelTurnLinkRetry();
        _cancelTurnEntitlementRecheck();
        _turnJoinLink = joinLink;
        // Only ever used to word a failure: whose call this is decides whether
        // "nobody is hosting it" is advice or noise.
        videoCallTunnelController.linkSource = result.source;
        return props;
      case VideoCallTunnelLinkStatus.notEntitled:
        _cancelTurnLinkRetry();
        _cancelTurnAssignmentHeartbeat();
        _turnJoinLink = null;
        videoCallTunnelController.status.value =
            VideoCallTunnelStatus.notEntitled;
        _scheduleTurnEntitlementRecheck();
        return null;
      case VideoCallTunnelLinkStatus.temporarilyUnavailable:
        if (_turnJoinLink == null) {
          _cancelTurnAssignmentHeartbeat();
          videoCallTunnelController.status.value =
              VideoCallTunnelStatus.temporarilyUnavailable;
        }
        _scheduleTurnLinkRetry();
        return null;
      case VideoCallTunnelLinkStatus.invalidSubscription:
        if (!subscriptionChanged &&
            isValidVideoCallJoinLink(_turnJoinLink ?? '')) {
          return props;
        }
        _cancelTurnAssignmentHeartbeat();
        videoCallTunnelController.status.value = VideoCallTunnelStatus.error;
        return null;
      case VideoCallTunnelLinkStatus.error:
        if (!subscriptionChanged &&
            isValidVideoCallJoinLink(_turnJoinLink ?? '')) {
          _scheduleTurnLinkRetry();
          return props;
        }
        _cancelTurnAssignmentHeartbeat();
        videoCallTunnelController.status.value = VideoCallTunnelStatus.error;
        _scheduleTurnLinkRetry();
        return null;
    }
  }

  Future<bool> refreshVideoCallTunnel({
    bool startTunnel = true,
    VideoCallTunnelLinkFetcher? fetchLink,
  }) async {
    if (_isRefreshingTurnLink) return false;
    _isRefreshingTurnLink = true;
    try {
      final previousJoinLink = _turnJoinLink;
      final props = await _resolveVideoCallTunnelProps(fetchLink: fetchLink);
      if (props == null) {
        if (startTunnel && isStart && previousJoinLink != _turnJoinLink) {
          await videoCallTunnelController.stop();
          await applyProfile(force: true, silence: true);
        }
        return false;
      }
      if (!startTunnel) {
        videoCallTunnelController.status.value = VideoCallTunnelStatus.stopped;
        return true;
      }
      final joinLink = _turnJoinLink;
      if (joinLink == null) return false;
      if (!shouldStartVideoCallTunnel(
        previousJoinLink: previousJoinLink,
        joinLink: joinLink,
        status: videoCallTunnelController.status.value,
      )) {
        return true;
      }
      final started = await videoCallTunnelController.start(
        props,
        joinLink: joinLink,
      );
      if (started && isStart) {
        await applyProfile(force: true, silence: true);
      }
      return started;
    } finally {
      _isRefreshingTurnLink = false;
    }
  }

  /// A lost transport is not a lost tunnel: the sidecar reconnects on its own and
  /// re-announces the loss before each attempt. Respawning it here would pre-empt that
  /// and force a new VK captcha, so only step in once it has gone quiet — every fresh
  /// TUNNEL_LOST pushes the deadline back.
  Future<void> _handleVideoCallTunnelLost() async {
    _cancelTurnAssignmentHeartbeat();
    _scheduleTurnReconnectGrace();
    _scheduleTurnPinGrace();
  }

  Future<void> _handleVideoCallTunnelConnected() async {
    _cancelTurnLinkRetry();
    _cancelTurnReconnectGrace();
    _cancelTurnPinGrace();
    _scheduleTurnAssignmentHeartbeat();
    await _pinVideoCallTunnelRouting();
    // The join worked, which is the only evidence the backend can get that a
    // user's own call link is still alive.
    unawaited(_reportVideoCallTunnelStatus(ok: true));
  }

  /// Send everything through the tunnel, and keep it that way until the switch
  /// on the dashboard says otherwise. A dropped transport does *not* lift this:
  /// the sidecar reconnects on its own, and unpinning on every blip would swing
  /// routing back and forth under the user.
  Future<void> _pinVideoCallTunnelRouting() async {
    final props = ref.read(videoCallTunnelSettingProvider);
    if (!props.enable || props.pinned) return;
    final currentMode = ref.read(patchClashConfigProvider).mode;
    ref
        .read(videoCallTunnelSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            pinned: true,
            // Only remember a mode we are actually taking away.
            restoreMode: currentMode == Mode.rule ? null : currentMode,
          ),
        );
    if (currentMode != Mode.rule) {
      ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mode: Mode.rule));
    }
    if (isStart) {
      await applyProfile(force: true, silence: true);
    }
  }

  Future<void> _unpinVideoCallTunnelRouting() async {
    final props = ref.read(videoCallTunnelSettingProvider);
    if (!props.pinned) return;
    final restoreMode = props.restoreMode;
    ref
        .read(videoCallTunnelSettingProvider.notifier)
        .update((state) => state.copyWith(pinned: false, restoreMode: null));
    if (restoreMode != null) {
      ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mode: restoreMode));
    }
  }

  /// Joined the call and nothing answered.
  ///
  /// On a user's own call that means nobody is hosting it, and retrying at speed
  /// would just ask for the captcha again and again. So this backs off through
  /// the existing ladder instead of restarting the way a terminal error does.
  Future<void> _handleVideoCallTunnelJoinTimeout() async {
    _cancelTurnAssignmentHeartbeat();
    _cancelTurnReconnectGrace();
    await _unpinVideoCallTunnelRouting();
    if (isStart) {
      await applyProfile(force: true, silence: true);
    }
    // The stage is what turns "it timed out" into something answerable: stuck
    // at the captcha is a different fault from stuck waiting for a peer.
    unawaited(
      _reportVideoCallTunnelStatus(
        ok: false,
        reason: 'join_timeout:${videoCallTunnelController.lastStage}',
      ),
    );
    await videoCallTunnelController.stop();
    _scheduleTurnLinkRetry();
  }

  /// The sidecar is single-shot — an ERROR or a process exit is unrecoverable, so this
  /// path still restarts immediately.
  Future<void> _handleVideoCallTunnelTerminalError() async {
    _cancelTurnAssignmentHeartbeat();
    _cancelTurnReconnectGrace();
    _scheduleTurnPinGrace();
    unawaited(_reportVideoCallTunnelStatus(ok: false, reason: 'sidecar_error'));
    await _restartVideoCallTunnel();
  }

  Future<void> _restartVideoCallTunnel() async {
    await videoCallTunnelController.stop();
    await refreshVideoCallTunnel();
  }

  Future<void> _refreshVideoCallTunnelProfile({
    ProfileRefresher? refreshProfile,
  }) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.url.isEmpty) return;
    try {
      final updatedProfile =
          await (refreshProfile ??
              (profile) {
                return profile.update();
              })(profile);
      ref.read(profilesProvider.notifier).put(updatedProfile);
    } catch (error) {
      commonPrint.log(
        'Unable to refresh profile before enabling video-call tunnel '
        '(${error.runtimeType})',
        logLevel: LogLevel.warning,
      );
    }
  }

  Profile? _applyVideoCallTunnelRouting() {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return null;
    final updatedProfile = profile.copyWith(
      selectedMap: applyVideoCallTunnelRoutingSelections(profile.selectedMap),
    );
    if (updatedProfile.selectedMap != profile.selectedMap) {
      ref.read(profilesProvider.notifier).put(updatedProfile);
    }
    return updatedProfile;
  }

  Future<void> setVideoCallTunnelEnabled(
    bool enabled, {
    ProfileRefresher? refreshProfile,
    VideoCallTunnelLinkFetcher? fetchLink,
  }) async {
    ref
        .read(videoCallTunnelSettingProvider.notifier)
        .update((state) => state.copyWith(enable: enabled));
    if (enabled) {
      await _refreshVideoCallTunnelProfile(refreshProfile: refreshProfile);
      _applyVideoCallTunnelRouting();
      await refreshVideoCallTunnel(startTunnel: isStart, fetchLink: fetchLink);
      return;
    }
    _cancelTurnLinkRetry();
    _cancelTurnAssignmentHeartbeat();
    _cancelTurnEntitlementRecheck();
    _cancelTurnReconnectGrace();
    _cancelTurnPinGrace();
    _turnJoinLink = null;
    _turnSubscriptionUrl = null;
    await _unpinVideoCallTunnelRouting();
    final stopped = await videoCallTunnelController.stop();
    if (isStart) {
      await applyProfile(force: true, silence: true);
    } else if (stopped) {
      videoCallTunnelController.status.value = VideoCallTunnelStatus.disabled;
    }
  }

  void handleVideoCallTunnelConnectivityRestored() {
    final enabled = ref.read(videoCallTunnelSettingProvider).enable;
    final status = videoCallTunnelController.status.value;
    if (!enabled ||
        !{
          VideoCallTunnelStatus.error,
          VideoCallTunnelStatus.temporarilyUnavailable,
          VideoCallTunnelStatus.stopped,
        }.contains(status)) {
      return;
    }
    unawaited(refreshVideoCallTunnel(startTunnel: isStart));
  }

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    return SetupParams(selectedMap: selectedMap, testUrl: testUrl);
  }

  void fullSetup() {
    if (!ref.read(initProvider)) return;
    ref.read(delayDataSourceProvider.notifier).value = {};
    applyProfile(force: true);
    ref.read(logsProvider.notifier).value = FixedList(500);
    ref.read(requestsProvider.notifier).value = FixedList(500);
  }

  /// Record a verified start. Only the launcher gets here, and only after the
  /// tunnel answered: isStart used to flip before anything was checked.
  void _markStarted() {
    startTime ??= DateTime.now();
    ref.read(commonActionProvider.notifier).updateRunTime();
    ref.read(commonActionProvider.notifier).updateTraffic();
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(commonActionProvider.notifier).updateRunTime();
      ref.read(commonActionProvider.notifier).updateTraffic();
    });
  }

  /// Forget a start without talking to the core: for a core that is already
  /// gone (crash) or about to be replaced (restart).
  void resetStarted() {
    startTime = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    ref.read(runTimeProvider.notifier).value = null;
  }

  Future _updateStartTime() async {
    startTime = await service?.getRunTime();
  }

  Future handleStop() async {
    startTime = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    _cancelTurnAssignmentHeartbeat();
    // A dead core answers nothing, and the invoke waits ten seconds to find
    // out. The listeners die with the process anyway.
    if (coreController.isCompleted) {
      await coreController.stopListener();
    }
    await videoCallTunnelController.stop();
  }

  Future<void> initStatus() async {
    if (!globalState.needInitStatus) {
      commonPrint.log('init status cancel');
      return;
    }
    commonPrint.log('init status');
    if (system.isAndroid) {
      await _updateStartTime();
    }
    final status = isStart == true
        ? true
        : ref.read(appSettingProvider).autoRun;
    if (status == true) {
      await updateStatus(true, isInit: true);
    } else {
      await applyProfile(force: true);
    }
  }

  /// Make sure TUN is on before anything starts, or say why it is not.
  ///
  /// Returns false to abort the start. The check lives here and not in the
  /// start button because the button is one of five ways in: the tray, the
  /// hotkey, the deep link and autostart all reach updateStatus directly and
  /// used to walk straight past the guard.
  Future<bool> _ensureTunBeforeStart({required bool isInit}) async {
    if (!system.isDesktop) return true;
    if (ref.read(patchClashConfigProvider).tun.enable) return true;
    if (!isInit) {
      // An interactive start explains itself; the button does this too, ahead
      // of time, and either dialog answered means the same thing here.
      final enable = await globalState.showMessage(
        title: currentAppLocalizations.tun,
        message: TextSpan(text: currentAppLocalizations.startRequiresTun),
        confirmText: currentAppLocalizations.enableTun,
      );
      if (enable != true) return false;
    }
    // Autostart and a core restart turn it on themselves. Asking at login is
    // asking at the moment people are least able to answer.
    setTunEnabled(true);
    return true;
  }

  Future<void> updateStatus(bool isStart, {bool isInit = false}) async {
    if (isStart) {
      await _start(isInit: isInit);
    } else {
      await _stop();
    }
  }

  /// Bring the VPN up through the launcher: core, config, tunnel, verified,
  /// with a bounded retry. Nothing here sets isStart; that happens once the
  /// launcher has seen the tunnel.
  Future<void> _start({required bool isInit}) async {
    if (_launcher.isLaunching || ref.read(isStartProvider)) return;
    if (!await _ensureTunBeforeStart(isInit: isInit)) return;
    globalState.needInitStatus = false;
    final videoCallTunnel = ref.read(videoCallTunnelSettingProvider);
    if (videoCallTunnel.enable) {
      final resolvedVideoCallTunnel = await _resolveVideoCallTunnelProps();
      if (resolvedVideoCallTunnel != null) {
        final joinLink = _turnJoinLink;
        if (joinLink != null) {
          await videoCallTunnelController.start(
            resolvedVideoCallTunnel,
            joinLink: joinLink,
          );
        }
      }
    }
    final launch = _launcher.launch(requireTunnel: _requireTunnel);
    _activeLaunch = launch;
    final result = await launch;
    _activeLaunch = null;
    if (result.ignored) return;
    if (result.success) {
      _markStarted();
      return;
    }
    // The launcher has already torn the attempt down.
    ref.read(runTimeProvider.notifier).value = null;
    if (result.failure == LaunchFailure.cancelled) return;
    _notifyLaunchFailed(result);
  }

  /// Whether a start must wait for the tunnel. The setting is the user's
  /// wish; on desktop the guard above has just made sure it is on. Suspended,
  /// nothing listens, so there is nothing to verify.
  bool get _requireTunnel {
    if (ref.read(suspendProvider)) return false;
    return system.isDesktop
        ? ref.read(patchClashConfigProvider).tun.enable
        : ref.read(vpnSettingProvider).enable;
  }

  Future<void> _stop() async {
    if (_launcher.isLaunching) {
      await cancelLaunch();
    } else {
      await handleStop();
    }
    coreController.resetTraffic();
    ref.read(trafficsProvider.notifier).clear();
    ref.read(totalTrafficProvider.notifier).value = const Traffic();
    ref.read(runTimeProvider.notifier).value = null;
    ref.read(checkIpNumProvider.notifier).add();
    ref.read(launchStateProvider.notifier).value = const LaunchState();
  }

  /// Stop a launch in progress and wait for it to unwind.
  Future<void> cancelLaunch() async {
    _launcher.cancel();
    await _activeLaunch;
  }

  /// Stop and start again: for a changed VPN configuration or a core that was
  /// replaced underneath a running tunnel.
  Future<void> restartVpn() async {
    await _stop();
    await _start(isInit: true);
  }

  /// The core or the tunnel went away under a running VPN. Same launch loop,
  /// same limit; a launch already in progress absorbs the event itself.
  Future<void> relaunchAfterCrash(String message) async {
    if (_launcher.isLaunching || !ref.read(isStartProvider)) return;
    commonPrint.log('relaunch after crash: $message');
    resetStarted();
    await _start(isInit: true);
  }

  /// Android refused the VPN consent dialog. Not a retryable failure: asking
  /// again is asking the same question.
  void handleVpnPermissionDenied() {
    _launcher.cancel(
      reason: LaunchFailure.vpnPermission,
      message: currentAppLocalizations.vpnPermissionDenied,
    );
  }

  void _notifyLaunchFailed(LaunchResult result) {
    final l10n = currentAppLocalizations;
    final message = result.message?.isNotEmpty == true
        ? result.message!
        : switch (result.failure) {
            LaunchFailure.config => l10n.launchFailedConfig,
            LaunchFailure.tunnel =>
              system.isDesktop ? l10n.launchFailedTunnel : l10n.launchFailedVpn,
            LaunchFailure.vpnPermission => l10n.vpnPermissionDenied,
            _ => l10n.launchFailedCore,
          };
    ref
        .read(launchStateProvider.notifier)
        .update((state) => state.copyWith(message: message));
    globalState.showNotifier(
      message,
      actionState: MessageActionState(
        actionText: l10n.retry,
        action: () {
          updateStatus(true);
        },
      ),
    );
  }

  void setTunEnabled(bool enable) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(enable: enable));
    ref
        .read(vpnSettingProvider.notifier)
        .update((state) => state.copyWith(enable: enable));
  }

  void prepareDeepLinkConnection() {
    setTunEnabled(true);
  }

  Future<void> connectFromDeepLink() async {
    prepareDeepLinkConnection();
    if (ref.read(isStartProvider)) {
      await applyProfile(force: true);
      return;
    }
    await updateStatus(true);
  }

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, () async {
      await globalState.safeRun(() async {
        final updateParams = ref.read(updateParamsProvider);
        final admin = await _requestAdmin(
          updateParams.tun.enable,
          forceMacOSHelperInstall: true,
        );
        if (!admin.ok) return;
        if (admin.reconnected) {
          // The elevated core is fresh: a patch is not enough, it needs the
          // whole profile, and the tunnel again if one was running.
          await ref
              .read(coreActionProvider.notifier)
              .restartCore(reconnect: false);
          return;
        }
        final realTunEnable = ref.read(realTunEnableProvider);
        final message = await coreController.updateConfig(
          updateParams.copyWith.tun(enable: realTunEnable),
        );
        ref.read(checkIpNumProvider.notifier).add();
        if (message.isNotEmpty) throw message;
      });
    });
  }

  Future<void> restartCoreForTun() async {
    final admin = await _requestAdmin(true);
    if (!admin.ok) return;
    final restarted = await ref
        .read(coreActionProvider.notifier)
        .restartCore(start: true, reconnect: !admin.reconnected);
    if (restarted) return;
    setTunEnabled(false);
    ref.read(realTunEnableProvider.notifier).value = false;
  }

  void tryCheckIp() {
    final isTimeout = ref.read(
      networkDetectionProvider.select(
        (state) => state.ipInfo == null && state.isLoading == false,
      ),
    );
    if (!isTimeout) return;
    ref.read(checkIpNumProvider.notifier).add();
  }

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    debouncer.call(FunctionTag.applyProfile, (silence, force) {
      applyProfile(silence: silence, force: force);
    }, args: [silence, force]);
  }

  Future<void> changeMode(Mode mode) async {
    if (!isModeChangeAllowed(ref, mode)) return;
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      const globalGroupName = 'GLOBAL';
      const defaultProxyName = 'PROXY';
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(globalGroupName);
      final selectedMap = ref.read(selectedMapProvider);
      if ((selectedMap[globalGroupName] ?? '').isNotEmpty) {
        return;
      }
      ref
          .read(profilesActionProvider.notifier)
          .updateCurrentSelectedMap(globalGroupName, defaultProxyName);
      final globalGroup = ref.read(groupsProvider).getGroup(globalGroupName);
      final hasDefaultProxy =
          globalGroup?.all.any((proxy) => proxy.name == defaultProxyName) ??
          false;
      if (hasDefaultProxy) {
        await ref
            .read(proxiesActionProvider.notifier)
            .changeProxy(
              groupName: globalGroupName,
              proxyName: defaultProxyName,
            );
      }
    }
  }

  void autoApplyProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyProfile();
    });
  }

  /// Load the current profile into the core. False means the core does not
  /// have it: elevation was refused, or the core rejected the config.
  Future<bool> applyProfile({bool silence = false, bool force = false}) async {
    return _setupConfig(
      force: force,
      silence: silence,
      onUpdated: () async {
        await ref.read(proxiesActionProvider.notifier).updateGroups();
        await ref.read(providersProvider.notifier).syncProviders();
      },
    );
  }

  Future<VM2<String, String>> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    final profileId = setupState.profileId;
    if (profileId == null) return const VM2('', '');
    final defaultUA = globalState.packageInfo.ua;
    final networkVM2 = ref.read(
      networkSettingProvider.select(
        (state) => VM2(state.appendSystemDns, state.routeMode),
      ),
    );
    final overrideDns = ref.read(overrideDnsProvider);
    final appendSystemDns = networkVM2.a;
    final routeMode = networkVM2.b;
    final configMap = await coreController.getConfig(profileId);
    String? scriptContent;
    final List<Rule> addedRules = [];
    final List<ProxyGroup> proxyGroups = [];
    final List<Rule> rules = [];
    if (setupState.overwriteType == OverwriteType.script) {
      scriptContent = await setupState.script?.content;
    } else if (setupState.overwriteType == OverwriteType.standard) {
      addedRules.addAll(setupState.addedRules);
    } else {
      proxyGroups.addAll(setupState.proxyGroups);
      rules.addAll(setupState.rules);
    }
    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(routeMode),
    );
    final videoCallTunnel = ref.read(videoCallTunnelSettingProvider);
    final turnJoinLink = _turnJoinLink ?? '';
    final videoCallCredentials = deriveVideoCallTunnelCredentials(turnJoinLink);
    Map<String, dynamic> rawConfig = configMap;
    if (scriptContent?.isNotEmpty == true) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    final directory = await appPath.profilesPath;
    final res = makeRealProfileTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        profilesPath: directory,
        profileId: profileId,
        rawConfig: rawConfig,
        realPatchConfig: realPatchConfig,
        overrideDns: overrideDns,
        appendSystemDns: appendSystemDns,
        addedRules: addedRules,
        defaultUA: defaultUA,
        videoCallTunnelEnabled:
            videoCallTunnel.enable && turnJoinLink.isNotEmpty,
        videoCallTunnelPinned:
            videoCallTunnel.enable &&
            videoCallTunnel.pinned &&
            turnJoinLink.isNotEmpty,
        videoCallTunnelPort: videoCallTunnelSocksPort,
        videoCallTunnelUsername: videoCallCredentials.username,
        videoCallTunnelPassword: videoCallCredentials.password,
      ),
    );
    return res;
  }

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final patchClashConfig = ref.read(patchClashConfigProvider);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: patchClashConfig,
      );
      return res.a;
    } catch (e) {
      globalState.showNotifier(e.toString());
    }
    return '';
  }

  /// Get the privileges TUN needs, once. `reconnected` says the core was
  /// replaced by an elevated one and has no config yet.
  Future<({bool ok, bool reconnected})> _requestAdmin(
    bool enableTun, {
    bool forceMacOSHelperInstall = false,
  }) async {
    final realTunEnable = ref.read(realTunEnableProvider);
    var reconnected = false;
    if (enableTun != realTunEnable && realTunEnable == false) {
      final code = await system.authorizeCore(
        forceMacOSHelperInstall: forceMacOSHelperInstall,
      );
      switch (code) {
        case AuthorizeCode.success:
          reconnected = await ref
              .read(coreActionProvider.notifier)
              .reconnectCore();
          if (!reconnected) {
            ref.read(realTunEnableProvider.notifier).value = false;
            globalState.showNotifier(
              currentAppLocalizations.tunHelperUnavailable,
            );
            return (ok: false, reconnected: false);
          }
        case AuthorizeCode.none:
          break;
        case AuthorizeCode.error:
          // The setting is what the user asked for and stays as it is; only the
          // runtime fact changes. Clearing tun.enable here used to turn a failed
          // elevation into a VPN that starts and routes nothing, which looks
          // exactly like a working one.
          ref.read(realTunEnableProvider.notifier).value = false;
          globalState.showNotifier(
            currentAppLocalizations.tunHelperUnavailable,
          );
          return (ok: false, reconnected: false);
      }
    }
    ref.read(realTunEnableProvider.notifier).value = enableTun;
    return (ok: true, reconnected: reconnected);
  }

  Future<bool> _setupConfig({
    bool force = false,
    bool silence = false,
    FutureOr Function()? onUpdated,
  }) async {
    var profile = ref.read(currentProfileProvider);
    final nextProfile = await profile?.checkAndUpdateAndCopy();
    if (nextProfile != null) {
      profile = nextProfile;
      ref.read(profilesProvider.notifier).put(nextProfile);
    }
    final videoCallTunnel = ref.read(videoCallTunnelSettingProvider);
    if (videoCallTunnel.enable) {
      profile = _applyVideoCallTunnelRouting() ?? profile;
    }
    if (videoCallTunnel.enable &&
        profile?.url.isNotEmpty == true &&
        profile?.url != _turnSubscriptionUrl) {
      final resolvedVideoCallTunnel = await _resolveVideoCallTunnelProps();
      if (resolvedVideoCallTunnel != null && isStart) {
        final joinLink = _turnJoinLink;
        if (joinLink != null) {
          await videoCallTunnelController.start(
            resolvedVideoCallTunnel,
            joinLink: joinLink,
          );
        }
      }
    }
    commonPrint.log('setup ===> ${profile?.id}');
    final patchConfig = ref.read(patchClashConfigProvider);
    final admin = await _requestAdmin(patchConfig.tun.enable);
    if (!admin.ok) return false;
    if (admin.reconnected &&
        ref.read(isStartProvider) &&
        !_launcher.isLaunching) {
      // Elevation replaced the core under a running tunnel. The launcher
      // brings both the config and the listeners back; this call would only
      // do the first half.
      await ref.read(coreActionProvider.notifier).restartCore(reconnect: false);
      return ref.read(isStartProvider);
    }
    final realTunEnable = ref.read(realTunEnableProvider);
    final realPatchConfig = patchConfig.copyWith.tun(enable: realTunEnable);
    final setupState = await ref.read(setupStateProvider(profile?.id).future);
    if (system.isAndroid) {
      globalState.lastVpnState = ref.read(vpnStateProvider);
      final sharedState = ref.read(sharedStateProvider);
      preferences.saveShareState(sharedState);
    }
    final vm2 = await getProfile(
      setupState: setupState,
      patchConfig: realPatchConfig,
    );
    final yamlString = vm2.a;
    final yamlMd5 = vm2.b;
    if (yamlMd5 == globalState.lastConfigMd5 && force == false) return true;
    // loadingRun swallows the throw into a notifier and answers null, which
    // is how a rejected config used to look exactly like an accepted one.
    final applied = await globalState.loadingRun<bool>(
      () async {
        final configFilePath = await appPath.configFilePath;
        await File(configFilePath).safeWriteAsString(yamlString);
        globalState.lastConfigMd5 = yamlMd5;
        final message = await coreController.setupConfig(
          setupState: setupState,
          params: _setupParams,
        );
        if (message.isNotEmpty && !message.endsWith('is empty')) {
          throw message;
        }
        ref.read(checkIpNumProvider.notifier).add();
        await onUpdated?.call();
        return true;
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
    return applied == true;
  }
}

/// The launcher's view of the app: each step is one dependency of a start,
/// answered by the core or the platform rather than by a flag.
class _SetupLaunchSteps implements LaunchSteps {
  final SetupAction action;
  final Ref ref;

  const _SetupLaunchSteps(this.action, this.ref);

  @override
  Future<StepOutcome> ensureCore() async {
    if (coreController.isCompleted && await coreController.isInit) {
      return const StepOutcome.ok();
    }
    final connected = await ref
        .read(coreActionProvider.notifier)
        .reconnectCore();
    if (connected) return const StepOutcome.ok();
    return StepOutcome.retry(currentAppLocalizations.launchFailedCore);
  }

  @override
  Future<StepOutcome> applyConfig() async {
    final tunRequested =
        system.isDesktop && ref.read(patchClashConfigProvider).tun.enable;
    final applied = await action.applyProfile(force: true, silence: true);
    if (applied) return const StepOutcome.ok();
    if (tunRequested && !ref.read(realTunEnableProvider)) {
      // Elevation was refused or the elevated core never came up. Trying
      // again means prompting again; the person has already answered.
      return StepOutcome.abort(
        LaunchFailure.config,
        currentAppLocalizations.tunHelperUnavailable,
      );
    }
    return StepOutcome.retry(currentAppLocalizations.launchFailedConfig);
  }

  @override
  Future<StepOutcome> startTunnel() async {
    if (!ref.read(suspendProvider)) {
      await coreController.startListener();
    }
    return const StepOutcome.ok();
  }

  @override
  Future<StepOutcome> verifyTunnel() async {
    if (system.isAndroid) {
      // start() only launches the service; the consent dialog and the
      // establish() call happen after it returns. Anything but `start` is
      // still on its way (or already refused, which arrives as a cancel).
      final runState = await service?.getRunState() ?? 'stop';
      if (runState != 'start') return const StepOutcome.retry('');
    }
    final status = await coreController.getRunStatus();
    if (status.tun) return const StepOutcome.ok();
    return StepOutcome.retry(
      system.isDesktop
          ? currentAppLocalizations.launchFailedTunnel
          : currentAppLocalizations.launchFailedVpn,
    );
  }

  @override
  Future<void> teardown() => action.handleStop();
}

@Riverpod(keepAlive: true)
class BackupAction extends _$BackupAction {
  @override
  void build() {}

  Future<String> backup() async {
    final res = await Future.wait([
      database.profilesDao.fileNames().get(),
      database.scriptsDao.fileNames().get(),
    ]);
    final profileFileNames = res[0];
    final scriptFileNames = res[1];
    final configMap = ref.read(configProvider).toJson();
    configMap['version'] = await preferences.getVersion();
    return backupTask(configMap, [...profileFileNames, ...scriptFileNames]);
  }

  Future<void> restore(RestoreOption option) async {
    final restoreDirPath = await appPath.restoreDirPath;
    final restoreDir = Directory(restoreDirPath);
    final restoreStrategy = ref.read(
      appSettingProvider.select((state) => state.restoreStrategy),
    );
    final isOverride = restoreStrategy == RestoreStrategy.override;
    try {
      final migrationData = await restoreTask();
      if (!await restoreDir.exists()) {
        throw currentAppLocalizations.restoreException;
      }
      await database.restore(
        migrationData.profiles,
        migrationData.scripts,
        migrationData.rules,
        migrationData.links,
        migrationData.proxyGroups,
        isOverride: isOverride,
      );
      final configMap = migrationData.configMap;
      if (option == RestoreOption.onlyProfiles || configMap == null) return;
      final config = Config.fromJson(configMap);
      ref.read(patchClashConfigProvider.notifier).value =
          config.patchClashConfig;
      ref.read(appSettingProvider.notifier).value = config.appSettingProps;
      ref.read(currentProfileIdProvider.notifier).value =
          config.currentProfileId;
      ref.read(davSettingProvider.notifier).value = config.davProps;
      ref.read(themeSettingProvider.notifier).value = config.themeProps;
      ref.read(windowSettingProvider.notifier).value = config.windowProps;
      ref.read(vpnSettingProvider.notifier).value = config.vpnProps;
      ref.read(proxiesStyleSettingProvider.notifier).value =
          config.proxiesStyleProps;
      ref.read(overrideDnsProvider.notifier).value = config.overrideDns;
      ref.read(networkSettingProvider.notifier).value = config.networkProps;
      ref.read(hotKeyActionsProvider.notifier).value = config.hotKeyActions;
      return;
    } finally {
      await restoreDir.safeDelete(recursive: true);
    }
  }
}

@Riverpod(keepAlive: true)
class CoreAction extends _$CoreAction {
  @override
  void build() {}

  Future<void> initCore() async {
    final isInit = await coreController.isInit;

    final version = ref.read(versionProvider);
    if (!isInit) {
      final res = await coreController.init(version);
      commonPrint.log('init result: $res');
    } else {
      await ref.read(proxiesActionProvider.notifier).updateGroups();
    }
  }

  Future<void> connectCore() async {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    final result = await Future.wait([
      coreController.preload(),
      Future.delayed(const Duration(milliseconds: 300)),
    ]);
    final String message = result[0];
    if (message.isNotEmpty) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      globalState.showNotifier(message);
      return;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  }

  Future<bool> reinstallWindowsHelper() async {
    if (!system.isWindows) return false;
    final wasStarted = ref.read(isStartProvider);
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await coreController.shutdown(false);
    final installed = await system.reinstallWindowsHelper();
    if (!installed) {
      ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith.tun(enable: false));
      ref.read(realTunEnableProvider.notifier).value = false;
      return false;
    }
    return restartCore(start: wasStarted);
  }

  /// Replace the core process and initialise it. Says nothing to the setup
  /// action: the launcher calls this as its first step, and everything else
  /// goes through [restartCore].
  Future<bool> reconnectCore() async {
    final isDisconnected =
        ref.read(coreStatusProvider) == CoreStatus.disconnected;
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await coreController.shutdown(!isDisconnected);
    await connectCore();
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return false;
    }
    await initCore();
    return true;
  }

  /// Restart the core and put back whatever was on it: the tunnel if the VPN
  /// was running (or [start] asks for it), else just the profile. Returns
  /// whether the core came back; a failed relaunch reports itself.
  Future<bool> restartCore({bool start = false, bool reconnect = true}) async {
    final setupAction = ref.read(setupActionProvider.notifier);
    final wasStarted =
        start || ref.read(isStartProvider) || setupAction.isLaunching;
    if (setupAction.isLaunching) {
      await setupAction.cancelLaunch();
    }
    if (ref.read(isStartProvider)) {
      // The listeners go down with the process; shutdown asks the core to
      // close them. Only the app-side record needs clearing.
      setupAction.resetStarted();
    }
    if (reconnect && !await reconnectCore()) {
      return false;
    }
    if (wasStarted) {
      await setupAction.updateStatus(true, isInit: true);
    } else {
      await setupAction.applyProfile(force: true);
    }
    return true;
  }

  void handleCoreDisconnected() {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
  }
}

@Riverpod(keepAlive: true)
class SystemAction extends _$SystemAction {
  @override
  void build() {}

  Future<List<Package>> getPackages() async {
    if (ref.read(isMobileViewProvider)) {
      await Future.delayed(commonDuration);
    }
    if (ref.read(packagesProvider).isEmpty) {
      ref.read(packagesProvider.notifier).value =
          await app?.getPackages() ?? [];
    }
    return ref.read(packagesProvider);
  }

  Future<void> handleExit([bool needSave = false]) async {
    Future.delayed(const Duration(seconds: 8), () {
      system.exit();
    });
    try {
      await Future.wait([
        if (needSave) preferences.saveConfig(ref.read(configProvider)),
        if (macOS != null) macOS!.updateDns(true),
        if (proxy != null) proxy!.stopProxy(),
        if (tray != null) tray!.destroy(),
        videoCallTunnelController.stop(),
      ]);
      await window?.close();
      await coreController.destroy();
      commonPrint.log('exit');
    } finally {
      system.exit();
    }
  }

  Future<void> handleClose([bool exit = true]) async {
    if (!system.isDesktop) {
      if (ref.read(backBlockProvider)) return;
    }
    if (ref.read(appSettingProvider).minimizeOnExit || !exit) {
      if (system.isDesktop) {
        await preferences.saveConfig(ref.read(configProvider));
      }
      await system.back();
    } else {
      await handleExit();
    }
  }

  Future<void> updateVisible() async {
    final visible = await window?.isVisible;
    if (visible != null && !visible) {
      window?.show();
    } else {
      window?.hide();
    }
  }

  void updateTun() {
    final setupAction = ref.read(setupActionProvider.notifier);
    final enable = !ref.read(patchClashConfigProvider).tun.enable;
    setupAction.setTunEnabled(enable);
  }

  void updateSystemProxy() {
    ref
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(systemProxy: !state.systemProxy));
  }

  void updateAutoLaunch() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoLaunch: !state.autoLaunch));
  }

  Future<void> updateTray() async {
    tray?.update(
      trayState: ref.read(trayStateProvider),
      traffic: ref.read(
        trafficsProvider.select(
          (state) => state.list.safeLast(const Traffic()),
        ),
      ),
    );
  }

  Future<void> updateLocalIp() async {
    ref.read(localIpProvider.notifier).value = null;
    await Future.delayed(commonDuration);
    ref.read(localIpProvider.notifier).value = await utils.getLocalIpAddress();
  }
}

@Riverpod(keepAlive: true)
class StoreAction extends _$StoreAction {
  @override
  void build() {}

  Future<void> shakingStore() async {
    final profileIds = ref.read(
      profilesProvider.select((state) => state.map((item) => item.id)),
    );
    final scriptIds = await ref.read(
      scriptsProvider.future.select(
        (state) async => (await state).map((item) => item.id),
      ),
    );
    final pathsToDelete = await shakingProfileTask(VM2(profileIds, scriptIds));
    if (pathsToDelete.isNotEmpty) {
      final deleteFutures = pathsToDelete.map((path) async {
        try {
          final res = await coreController.deleteFile(path);
          if (res.isNotEmpty) throw res;
        } catch (e) {
          rethrow;
        }
      });
      await Future.wait(deleteFutures);
    }
  }

  void savePreferencesDebounce() {
    debouncer.call(FunctionTag.savePreferences, () async {
      await preferences.saveConfig(ref.read(configProvider));
    });
  }

  Future handleClear() async {
    await preferences.clearPreferences();
    commonPrint.log('clear preferences');
    await database.close();
    await File(await appPath.databasePath).safeDelete(recursive: true);
    final homeDir = Directory(await appPath.profilesPath);
    await for (final file in homeDir.list(recursive: true)) {
      await coreController.deleteFile(file.path);
    }
    await preferences.clearPreferences();
    ref.read(systemActionProvider.notifier).handleExit(false);
  }
}

@Riverpod(keepAlive: true)
class ThemeAction extends _$ThemeAction {
  @override
  void build() {}

  void updateBrightness() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(systemBrightnessProvider.notifier).value =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  void updateViewSize(Size size) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(viewSizeProvider.notifier).value = size;
    });
  }
}

@Riverpod(keepAlive: true)
class ProxiesAction extends _$ProxiesAction {
  @override
  void build() {}

  void updateGroupsDebounce([Duration? duration]) {
    debouncer.call(FunctionTag.updateGroups, updateGroups, duration: duration);
  }

  void changeProxyDebounce(String groupName, String proxyName) {
    debouncer.call(FunctionTag.changeProxy, (
      String groupName,
      String proxyName,
    ) async {
      await changeProxy(groupName: groupName, proxyName: proxyName);
      updateGroupsDebounce();
    }, args: [groupName, proxyName]);
  }

  Future<void> updateGroups() async {
    try {
      commonPrint.log('updateGroups');
      ref.read(groupsProvider.notifier).value = await retry(
        task: () async {
          final sortType = ref.read(
            proxiesStyleSettingProvider.select((state) => state.sortType),
          );
          final delayMap = ref.read(delayDataSourceProvider);
          final testUrl = ref.read(
            appSettingProvider.select((state) => state.testUrl),
          );
          final selectedMap = ref.read(
            currentProfileProvider.select((state) => state?.selectedMap ?? {}),
          );
          return coreController.getProxiesGroups(
            selectedMap: selectedMap,
            sortType: sortType,
            delayMap: delayMap,
            defaultTestUrl: testUrl,
          );
        },
        retryIf: (res) => res.isEmpty,
      );
    } catch (e) {
      commonPrint.log('updateGroups error: $e');
      ref.read(groupsProvider.notifier).value = [];
    }
  }

  void updateCurrentGroupName(String groupName) {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.currentGroupName == groupName) return;
    ref
        .read(profilesProvider.notifier)
        .put(profile.copyWith(currentGroupName: groupName));
  }

  void updateCurrentUnfoldSet(Set<String> value) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null) return;
    ref
        .read(profilesProvider.notifier)
        .put(currentProfile.copyWith(unfoldSet: value));
  }

  void setDelay(Delay delay) {
    ref.read(delayDataSourceProvider.notifier).setDelay(delay);
  }

  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    await coreController.changeProxy(
      ChangeProxyParams(groupName: groupName, proxyName: proxyName),
    );
    if (ref.read(appSettingProvider).closeConnections) {
      await coreController.closeConnections();
    } else {
      await coreController.resetConnections();
    }
    ref.read(checkIpNumProvider.notifier).add();
  }

  Future<String> updateProvider(
    ExternalProvider provider, {
    bool showLoading = false,
  }) async {
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(provider.updatingKey).notifier).value =
            true;
      }
      final message = await coreController.updateExternalProvider(
        providerName: provider.name,
      );
      if (message.isNotEmpty) return message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await coreController.getExternalProvider(provider.name));
      return '';
    } finally {
      ref.read(isUpdatingProvider(provider.updatingKey).notifier).value = false;
    }
  }
}

@Riverpod(keepAlive: true)
class ProfilesAction extends _$ProfilesAction {
  @override
  void build() {}

  void updateCurrentSelectedMap(String groupName, String proxyName) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != proxyName) {
      final selectedMap = Map<String, String>.from(currentProfile.selectedMap)
        ..[groupName] = proxyName;
      ref
          .read(profilesProvider.notifier)
          .put(currentProfile.copyWith(selectedMap: selectedMap));
    }
  }

  Future<void> deleteProfile(int id) async {
    ref.read(profilesProvider.notifier).del(id);
    clearEffect(id);
    final currentProfileId = ref.read(currentProfileIdProvider);
    if (currentProfileId == id) {
      final profiles = ref.read(profilesProvider);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        ref.read(currentProfileIdProvider.notifier).value = updateId;
      } else {
        ref.read(currentProfileIdProvider.notifier).value = null;
        ref.read(setupActionProvider.notifier).updateStatus(false);
      }
    }
  }

  Future<void> autoUpdateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (!profile.autoUpdate) continue;
      final isNotNeedUpdate = profile.lastUpdateDate
          ?.add(profile.autoUpdateDuration)
          .isBeforeNow;
      if (isNotNeedUpdate == false || profile.type == ProfileType.file) {
        continue;
      }
      try {
        await updateProfile(profile);
      } catch (e) {
        commonPrint.log(e.toString(), logLevel: LogLevel.warning);
      }
    }
  }

  void putProfile(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (ref.read(currentProfileIdProvider) != null) return;
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  Future<void> updateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) continue;
      await updateProfile(profile);
    }
  }

  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
    ProfileRefresher? refreshProfile,
  }) async {
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = true;
      }
      ref.read(profilesProvider.notifier).put(profile);
      final newProfile = await (refreshProfile ?? (value) => value.update())(
        profile,
      );
      ref.read(profilesProvider.notifier).put(newProfile);
      ref.invalidate(clashConfigProvider(profile.id));
      if (profile.id == ref.read(currentProfileIdProvider)) {
        await ref
            .read(setupActionProvider.notifier)
            .applyProfile(force: true, silence: true);
      }
    } finally {
      ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = false;
    }
  }

  Future<void> addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile == null) return;
    final bytes = await platformFile.readBytes();
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    ref.read(currentPageLabelProvider.notifier).toProfiles();
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        return Profile.normal(label: platformFile.name).saveFile(bytes);
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  Future<Profile?> addProfileFormURL(String url, {String? name}) async {
    return _addProfileFormURL(url, name: name);
  }

  Future<Profile?> installProfileFormURL(String url, {String? name}) async {
    return _addProfileFormURL(url, name: name, updateExisting: true);
  }

  Future<Profile?> _addProfileFormURL(
    String url, {
    String? name,
    bool updateExisting = false,
  }) async {
    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    ref.read(currentPageLabelProvider.notifier).value = PageLabel.profiles;
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        final profile = updateExisting
            ? profileForInstallUrl(
                ref.read(profilesProvider),
                url: url,
                name: name,
              )
            : Profile.normal(
                url: url,
                label: name?.isNotEmpty == true ? name : null,
              );
        return profile.update();
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
    return profile;
  }

  void setProfileAndAutoApply(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (profile.id == ref.read(currentProfileIdProvider)) {
      ref.read(setupActionProvider.notifier).applyProfileDebounce();
    }
  }

  Future<void> addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    addProfileFormURL(url);
  }

  void reorder(List<Profile> profiles) {
    ref.read(profilesProvider.notifier).reorder(profiles);
  }

  Future<void> clearEffect(int profileId) async {
    final profilePath = await appPath.getProfilePath(profileId.toString());
    final providersDirPath = await appPath.getProvidersDirPath(
      profileId.toString(),
    );
    final profileFile = File(profilePath);
    final isExists = await profileFile.exists();
    if (isExists) {
      await profileFile.safeDelete(recursive: true);
    }
    await coreController.deleteFile(providersDirPath);
  }
}

@Riverpod(keepAlive: true)
class GeoResourceAction extends _$GeoResourceAction {
  @override
  void build() {}

  Future<void> updateGeoResource(GeoResource geoResource) async {
    await coreController.updateGeoData(geoResource.name);
  }

  void updateGeoResourceUrl(GeoResource geoResource, String newUrl) {
    if (!newUrl.isUrl) {
      throw 'Invalid url';
    }
    ref.read(patchClashConfigProvider.notifier).update((state) {
      return state.copyWith(geoXUrl: {...state.geoXUrl, geoResource: newUrl});
    });
  }
}
