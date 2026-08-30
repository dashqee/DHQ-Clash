import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/foundation.dart';

import 'path.dart';
import 'print.dart';
import 'system.dart';

const videoCallTunnelProxyName = 'DHQ TURN';
const videoCallTunnelProviderName = 'DHQ TURN provider';
const videoCallTunnelDisplayName = 'DHQ Clash';
const videoCallTunnelSocksPort = 11789;
const videoCallTunnelMode = 'dc';
const videoCallTunnelHealthCheckUrl = 'https://cp.cloudflare.com/generate_204';
const videoCallTunnelHealthCheckInterval = 30;
const videoCallTunnelRestartDebounce = Duration(seconds: 2);
const videoCallTunnelAssignmentHeartbeat = Duration(seconds: 60);
// Entitlement is bought in the mini app, not here, so a 403 is not final: re-ask on a
// slow timer instead of waiting for a restart to notice the slot has been assigned.
const videoCallTunnelEntitlementRecheck = Duration(minutes: 5);
// A dropped transport is routine — the sidecar reconnects on its own (10 attempts,
// 1→16s backoff) and re-emits TUNNEL_LOST before each try. So this is a *silence*
// timeout, restarted by every sign of life, not a deadline for full recovery.
// Respawning the process instead pre-empts that retry loop and, because the VK
// session is not cached, costs the user a fresh captcha.
const videoCallTunnelReconnectGrace = Duration(seconds: 60);
// How long everything may keep pointing at a tunnel that is not up before the
// pin is lifted. The sidecar's own retry sequence runs about a minute, so this
// leaves room for a real recovery and still bounds the outage: pinned to a dead
// channel there is no internet at all, and the only sign is that nothing loads.
const videoCallTunnelPinGrace = Duration(minutes: 3);
// How long the sidecar may sit between "joining" and "joined" before we call it
// a failure. Nothing else bounds it: the sidecar reports TUNNEL_LOST and ERROR
// but has nothing to say about a call it entered where no one is waiting, so
// without this the app shows "connecting" for ever. A managed call connects in
// seconds; the slack is for a slow network, not for the captcha, which stops
// this clock entirely.
const videoCallTunnelJoinDeadline = Duration(seconds: 90);
// The same deadline, widened to human scale while a captcha is on screen.
// Stopping the clock instead — which is what this used to do — hands the wait
// back to the sidecar, and a sidecar that has gone quiet is the failure being
// guarded against. Long enough to walk away and come back; not forever.
const videoCallTunnelCaptchaDeadline = Duration(minutes: 10);
// Upper bound on resolving a hostname for the sidecar. It blocks on our answer while
// holding its resolve mutex, so a lookup that never returns wedges the tunnel for good.
const videoCallTunnelResolveTimeout = Duration(seconds: 5);
// Budget for fetching the join link. The proxied attempt can be routed through the
// tunnel we are trying to repair, where the relay waits 20s for MsgConnectOK before
// giving up — stay well under that so the direct retry still happens.
const videoCallTunnelLinkTimeout = Duration(seconds: 6);
// The sidecar's own traffic to VK. TUN takes every route on desktop, so without
// these its connection comes back through the core and into its own SOCKS port.
//
// Two independent contours on purpose. The process rules are exact but they all
// depend on one thing — the core resolving which process owns a connection — and
// on Windows the core runs in a separate elevated service, where that resolution
// is the part most likely to come back empty. When it does, all four rules miss
// at once and the sidecar dials itself, which looks from outside exactly like
// the reported symptom: the proxy red, no traffic passing.
//
// The destination rules do not depend on process matching, and they are correct
// on their own terms regardless of platform: the tunnel *is* a VK call, so VK
// has to be reachable without it or there is no tunnel to reach it through.
const videoCallTunnelBypassRules = <String>[
  'PROCESS-NAME,DHQClashTurn,DIRECT',
  'PROCESS-NAME,DHQClashTurn.exe,DIRECT',
  'PROCESS-NAME,libDHQClashTurn.so,DIRECT',
  'PROCESS-NAME,app.dhqclash,DIRECT',
  'DOMAIN-SUFFIX,vk.ru,DIRECT',
  'DOMAIN-SUFFIX,vk.com,DIRECT',
  'DOMAIN-SUFFIX,vk-apps.com,DIRECT',
  'DOMAIN-SUFFIX,vkuservideo.net,DIRECT',
  'DOMAIN-SUFFIX,userapi.com,DIRECT',
  'DOMAIN-SUFFIX,mycdn.me,DIRECT',
  'DOMAIN-SUFFIX,vk-cdn.net,DIRECT',
];

// What replaces the rule list once the tunnel is pinned. Private ranges are
// spelled out rather than left to `GEOIP,private`, which needs the mmdb: with
// the catch-all above them the LAN and the core's own external-controller would
// both be routed into the call.
const videoCallTunnelPinRules = <String>[
  'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve',
  'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
  'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve',
  'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
  'IP-CIDR,169.254.0.0/16,DIRECT,no-resolve',
  'IP-CIDR6,::1/128,DIRECT,no-resolve',
  'IP-CIDR6,fc00::/7,DIRECT,no-resolve',
  'IP-CIDR6,fe80::/10,DIRECT,no-resolve',
  'MATCH,$videoCallTunnelProxyName',
];

const videoCallTunnelRoutingSelections = <String, String>{
  'PROXY': 'Fallback',
  'Telegram': 'PROXY',
  'YouTube': 'PROXY',
};

enum VideoCallTunnelStatus {
  disabled,
  checking,
  notEntitled,
  temporarilyUnavailable,
  starting,
  connecting,
  captchaRequired,
  connected,
  reconnecting,
  stopped,
  // Entered the call and waited, and nothing answered. Its own state, not
  // `error`, because the thing to tell the user is specific: on a call of their
  // own it means nobody is hosting it.
  joinTimedOut,
  error,
}

enum VideoCallTunnelLinkStatus {
  available,
  notEntitled,
  temporarilyUnavailable,
  invalidSubscription,
  error,
}

bool shouldStartVideoCallTunnel({
  required String? previousJoinLink,
  required String joinLink,
  required VideoCallTunnelStatus status,
}) {
  if (previousJoinLink != joinLink) return true;
  return !{
    VideoCallTunnelStatus.starting,
    VideoCallTunnelStatus.connecting,
    VideoCallTunnelStatus.captchaRequired,
    VideoCallTunnelStatus.connected,
  }.contains(status);
}

/// Whose call the link points at. The client cannot tell by looking — the two
/// are the same kind of VK link — so the backend says.
enum VideoCallTunnelSource { managed, custom }

VideoCallTunnelSource? parseVideoCallTunnelSource(Object? value) =>
    switch (value) {
      'managed' => VideoCallTunnelSource.managed,
      'custom' => VideoCallTunnelSource.custom,
      _ => null,
    };

@immutable
class VideoCallTunnelLinkResult {
  final VideoCallTunnelLinkStatus status;
  final String? joinLink;
  final VideoCallTunnelSource? source;

  const VideoCallTunnelLinkResult(this.status, {this.joinLink, this.source});
}

typedef VideoCallTunnelLinkFetcher =
    Future<VideoCallTunnelLinkResult> Function(String subscriptionUrl);

/// Whether the outbound mode may be changed to [mode] right now.
///
/// The pin is a rule, and the core matches no rules at all in global or direct
/// (`proxy = proxies["GLOBAL"]`), so switching modes would silently route around
/// the tunnel the dashboard says everything is going through.
bool videoCallTunnelAllowsMode(VideoCallTunnelProps props, Mode mode) {
  if (mode == Mode.rule) return true;
  return !(props.enable && props.pinned);
}

Map<String, String> applyVideoCallTunnelRoutingSelections(
  Map<String, String> selectedMap,
) {
  return {...selectedMap, ...videoCallTunnelRoutingSelections};
}

@immutable
class VideoCallTunnelCredentials {
  final String username;
  final String password;

  const VideoCallTunnelCredentials({
    required this.username,
    required this.password,
  });
}

/// Where the client reports whether it managed to join the call it was given.
///
/// The server hands out a user's own VK link unchecked and cannot check it: VK
/// answers a live call and a fabricated one with the same page, because call
/// state resolves client-side behind auth. The joiner is the only witness.
Uri? buildVideoCallTunnelStatusUri(String subscriptionUrl) {
  final link = buildVideoCallTunnelLinkUri(subscriptionUrl);
  if (link == null) return null;
  final segments = List<String>.from(link.pathSegments);
  // .../turn/link/<public_file> -> .../turn/status/<public_file>
  final turnIndex = segments.lastIndexOf('link');
  if (turnIndex < 0) return null;
  segments[turnIndex] = 'status';
  return link.replace(pathSegments: segments);
}

Uri? buildVideoCallTunnelLinkUri(String subscriptionUrl) {
  final subscriptionUri = Uri.tryParse(subscriptionUrl.trim());
  if (subscriptionUri == null ||
      !subscriptionUri.hasScheme ||
      subscriptionUri.host.isEmpty ||
      !{'http', 'https'}.contains(subscriptionUri.scheme.toLowerCase())) {
    return null;
  }
  final pathSegments = subscriptionUri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (pathSegments.isEmpty) return null;
  final pathPrefix = pathSegments.sublist(0, pathSegments.length - 1);
  return Uri(
    scheme: subscriptionUri.scheme,
    host: subscriptionUri.host,
    port: subscriptionUri.hasPort ? subscriptionUri.port : null,
    pathSegments: [...pathPrefix, 'turn', 'link', pathSegments.last],
  );
}

VideoCallTunnelLinkResult parseVideoCallTunnelLinkResponse(
  int? statusCode,
  Object? data,
) {
  if (statusCode == HttpStatus.forbidden) {
    return const VideoCallTunnelLinkResult(
      VideoCallTunnelLinkStatus.notEntitled,
    );
  }
  if (statusCode == HttpStatus.serviceUnavailable) {
    return const VideoCallTunnelLinkResult(
      VideoCallTunnelLinkStatus.temporarilyUnavailable,
    );
  }
  if (statusCode != HttpStatus.ok || data is! Map) {
    return const VideoCallTunnelLinkResult(VideoCallTunnelLinkStatus.error);
  }
  final joinLink = data['join_link']?.toString().trim() ?? '';
  if (!isValidVideoCallJoinLink(joinLink)) {
    return const VideoCallTunnelLinkResult(VideoCallTunnelLinkStatus.error);
  }
  return VideoCallTunnelLinkResult(
    VideoCallTunnelLinkStatus.available,
    joinLink: joinLink,
    // Absent on an older backend, and the client must not care: it only ever
    // changes the wording of a failure.
    source: parseVideoCallTunnelSource(data['source']),
  );
}

VideoCallTunnelCredentials deriveVideoCallTunnelCredentials(String joinLink) {
  final digest = sha256.convert(utf8.encode('dhqclash-turn:$joinLink'));
  final value = digest.toString();
  return VideoCallTunnelCredentials(
    username: 'dhq${value.substring(0, 12)}',
    password: value.substring(12, 44),
  );
}

bool isValidVideoCallJoinLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  return (host == 'vk.ru' || host == 'vk.com') &&
      uri.path.startsWith('/call/join/') &&
      uri.pathSegments.length >= 3;
}

String sanitizeVideoCallTunnelLog(String value) {
  return value.replaceAll(
    RegExp(r'''https://(?:vk\.ru|vk\.com)/call/join/[^\s"'<>]+'''),
    'https://vk.ru/call/join/[redacted]',
  );
}

Uri? parseVideoCallTunnelCaptchaUri(String status) {
  const prefix = 'CAPTCHA:';
  if (!status.startsWith(prefix)) return null;
  final uri = Uri.tryParse(status.substring(prefix.length).trim());
  if (uri == null || uri.scheme != 'http' || !uri.hasPort) return null;
  const loopbackHosts = {'127.0.0.1', 'localhost', '::1'};
  return loopbackHosts.contains(uri.host.toLowerCase()) ? uri : null;
}

Map<String, dynamic> addVideoCallTunnelToConfig(
  Map<String, dynamic> source, {
  required int port,
  required String username,
  required String password,
  bool pinned = false,
}) {
  final config = Map<String, dynamic>.from(source);
  final proxies = List<dynamic>.from(config['proxies'] as List? ?? const []);
  proxies.removeWhere(
    (proxy) =>
        proxy is Map && proxy['name']?.toString() == videoCallTunnelProxyName,
  );
  final proxy = <String, dynamic>{
    'name': videoCallTunnelProxyName,
    'type': 'socks5',
    'server': '127.0.0.1',
    'port': port,
    'username': username,
    'password': password,
    'udp': true,
  };
  // Unpinned, the tunnel reaches the core only through the inline provider the
  // Fallback group uses. A rule target, though, is looked up in the proxy map
  // built from `proxies:` and the group names — a provider-only proxy is not in
  // it — so pinning has to put the proxy there as well for MATCH to resolve.
  if (pinned) {
    proxies.add(proxy);
  }
  config['proxies'] = proxies;

  final proxyProviders = Map<String, dynamic>.from(
    config['proxy-providers'] as Map? ?? const {},
  );
  proxyProviders[videoCallTunnelProviderName] = {
    'type': 'inline',
    'payload': [proxy],
  };
  config['proxy-providers'] = proxyProviders;

  final groups = List<dynamic>.from(config['proxy-groups'] as List? ?? const [])
      .map((group) {
        if (group is Map) return Map<String, dynamic>.from(group);
        if (group is ProxyGroup) return group.toJson();
        return group;
      })
      .toList();
  for (final group in groups) {
    if (group is! Map ||
        group['type']?.toString() != 'fallback' ||
        group['name']?.toString() != 'Fallback') {
      continue;
    }
    final groupProxies = List<dynamic>.from(
      group['proxies'] as List? ?? const [],
    );
    groupProxies.removeWhere((item) => item == videoCallTunnelProxyName);
    group['proxies'] = groupProxies;
    final groupProviders = List<dynamic>.from(
      group['use'] as List? ?? const [],
    );
    groupProviders.removeWhere((item) => item == videoCallTunnelProviderName);
    groupProviders.add(videoCallTunnelProviderName);
    group['use'] = groupProviders;
    group.putIfAbsent('url', () => videoCallTunnelHealthCheckUrl);
    group.putIfAbsent('interval', () => videoCallTunnelHealthCheckInterval);
  }
  config['proxy-groups'] = groups;

  final rules = List<String>.from(config['rules'] as List? ?? const []);
  rules.removeWhere(videoCallTunnelBypassRules.contains);
  rules.removeWhere(videoCallTunnelPinRules.contains);
  config['rules'] = pinned
      // Everything below the catch-all is unreachable, which is the point: this
      // is what the user asked GLOBAL for. GLOBAL itself cannot be used — the
      // core skips rule matching entirely in that mode, and the bypass rules
      // above are the only thing keeping the sidecar out of its own SOCKS port.
      ? [...videoCallTunnelBypassRules, ...videoCallTunnelPinRules]
      : [...videoCallTunnelBypassRules, ...rules];
  // TUN takes every route on desktop, so the sidecar's own traffic to VK comes back
  // through the core. These PROCESS-NAME rules are the ONLY thing keeping it from
  // being sent into the sidecar's own SOCKS port once DHQ TURN is the active
  // outbound, and they are inert without process matching — so it is not the user's
  // setting to make while the tunnel is running.
  config['find-process-mode'] = FindProcessMode.always.name;
  return config;
}

class VideoCallTunnelController {
  static VideoCallTunnelController? _instance;

  final ValueNotifier<VideoCallTunnelStatus> status = ValueNotifier(
    VideoCallTunnelStatus.disabled,
  );
  final ValueNotifier<Uri?> captchaUri = ValueNotifier(null);
  Future<void> Function()? onTunnelLost;
  Future<void> Function()? onTunnelConnected;
  Future<void> Function()? onTerminalError;
  Future<void> Function()? onJoinTimeout;
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  String? _activeJoinLink;
  IOSink? _stdin;
  Completer<void>? _leaveAckCompleter;
  /// Whose call the current link points at, for wording a failure.
  VideoCallTunnelSource? linkSource;

  /// The last thing the sidecar said, so a timeout can report where it stalled
  /// instead of leaving everyone to compare logs by hand.
  String _lastStage = 'starting';
  String get lastStage => _lastStage;
  Timer? _joinDeadlineTimer;
  Future<void> _lifecycleQueue = Future<void>.value();
  final Stopwatch _lifecycleClock = Stopwatch()..start();
  int? _lastDesktopStartAtMs;
  bool _stopping = false;

  VideoCallTunnelController._internal();

  factory VideoCallTunnelController() {
    _instance ??= VideoCallTunnelController._internal();
    return _instance!;
  }

  Future<bool> start(VideoCallTunnelProps props, {required String joinLink}) {
    return _enqueueLifecycle(() => _start(props, joinLink: joinLink));
  }

  Future<bool> _start(
    VideoCallTunnelProps props, {
    required String joinLink,
  }) async {
    captchaUri.value = null;
    if (!props.enable || joinLink.isEmpty) {
      await _stop();
      status.value = VideoCallTunnelStatus.disabled;
      return false;
    }
    if (!isValidVideoCallJoinLink(joinLink)) {
      await _stop();
      status.value = VideoCallTunnelStatus.error;
      return false;
    }
    if (_activeJoinLink == joinLink &&
        {
          VideoCallTunnelStatus.starting,
          VideoCallTunnelStatus.connecting,
          VideoCallTunnelStatus.captchaRequired,
          VideoCallTunnelStatus.connected,
        }.contains(status.value)) {
      return true;
    }
    if (!await _stop()) {
      status.value = VideoCallTunnelStatus.error;
      return false;
    }
    if (!system.isAndroid) await _waitForDesktopRestartDebounce();
    _activeJoinLink = joinLink;

    status.value = VideoCallTunnelStatus.starting;
    _lastStage = 'starting';
    // From here on something must happen within the deadline. A sidecar that
    // never prints anything at all is the same failure as one that joins a call
    // nobody is hosting.
    _armJoinDeadline();
    final credentials = deriveVideoCallTunnelCredentials(joinLink);
    if (system.isAndroid) {
      app?.onVideoCallTunnelStatus = _handleNativeStatus;
      final started =
          await app?.startVideoCallTunnel(
            joinLink: joinLink,
            displayName: videoCallTunnelDisplayName,
            tunnelMode: videoCallTunnelMode,
            socksPort: videoCallTunnelSocksPort,
            socksUsername: credentials.username,
            socksPassword: credentials.password,
          ) ??
          false;
      if (!started) status.value = VideoCallTunnelStatus.error;
      return started;
    }

    final executable = File(appPath.videoCallTunnelPath);
    if (!executable.existsSync()) {
      commonPrint.log('TURN sidecar is missing: ${executable.path}');
      status.value = VideoCallTunnelStatus.error;
      return false;
    }
    try {
      final process = await Process.start(executable.path, [
        '--mode',
        'vk-headless-joiner',
        '--socks-host',
        '127.0.0.1',
        '--socks-port',
        '$videoCallTunnelSocksPort',
        '--socks-user',
        credentials.username,
        '--socks-pass',
        credentials.password,
      ]);
      _process = process;
      _lastDesktopStartAtMs = _lifecycleClock.elapsedMilliseconds;
      _stdin = process.stdin;
      _stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleDesktopLine);
      _stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) =>
                commonPrint.log('TURN: ${sanitizeVideoCallTunnelLog(line)}'),
          );
      unawaited(
        process.exitCode.then((code) {
          if (!_stopping &&
              _process == process &&
              status.value != VideoCallTunnelStatus.stopped) {
            // The sidecar is single-shot: once it returns there is no way back, so a
            // real exit IS terminal. Log the code — without it a crash and a clean
            // exit are indistinguishable in the log.
            commonPrint.log('TURN sidecar exited unexpectedly (code $code)');
            _process = null;
            status.value = VideoCallTunnelStatus.error;
            final callback = onTerminalError;
            if (callback != null) unawaited(callback());
          }
        }),
      );
      return true;
    } catch (error) {
      commonPrint.log('Failed to start TURN sidecar: $error');
      status.value = VideoCallTunnelStatus.error;
      return false;
    }
  }

  Future<bool> stop() {
    return _enqueueLifecycle(_stop);
  }

  Future<bool> _stop() async {
    _stopping = true;
    _cancelJoinDeadline();
    try {
      app?.onVideoCallTunnelStatus = null;
      var stopped = true;
      if (system.isAndroid) {
        stopped = await app?.stopVideoCallTunnel() ?? false;
      }
      final process = _process;
      if (process != null) {
        final leaveAckCompleter = Completer<void>();
        _leaveAckCompleter = leaveAckCompleter;
        try {
          _stdin?.writeln('LEAVE');
          await _stdin?.flush();
          await leaveAckCompleter.future.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          commonPrint.log('TURN sidecar leave acknowledgement timed out');
        } catch (error) {
          commonPrint.log('Unable to request TURN sidecar leave: $error');
        } finally {
          if (_leaveAckCompleter == leaveAckCompleter) {
            _leaveAckCompleter = null;
          }
        }
      }
      await _stdoutSubscription?.cancel();
      await _stderrSubscription?.cancel();
      _stdoutSubscription = null;
      _stderrSubscription = null;
      await _stdin?.close();
      _stdin = null;
      if (process != null) {
        stopped = await _waitForProcessExit(process);
        if (!stopped) {
          process.kill();
          stopped = await _waitForProcessExit(process);
        }
        if (!stopped) {
          process.kill(ProcessSignal.sigkill);
          stopped = await _waitForProcessExit(process);
        }
        if (!stopped) {
          commonPrint.log('TURN sidecar did not exit after forced shutdown');
        }
      }
      if (stopped) {
        _process = null;
        _activeJoinLink = null;
      }
      captchaUri.value = null;
      status.value = stopped
          ? VideoCallTunnelStatus.stopped
          : VideoCallTunnelStatus.error;
      return stopped;
    } finally {
      _stopping = false;
    }
  }

  Future<bool> _waitForProcessExit(Process process) async {
    try {
      await process.exitCode.timeout(const Duration(seconds: 1));
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _waitForDesktopRestartDebounce() async {
    final lastStartAt = _lastDesktopStartAtMs;
    if (lastStartAt == null) return;
    final elapsed = _lifecycleClock.elapsedMilliseconds - lastStartAt;
    final remaining = videoCallTunnelRestartDebounce.inMilliseconds - elapsed;
    if (remaining > 0) {
      await Future<void>.delayed(Duration(milliseconds: remaining));
    }
  }

  Future<T> _enqueueLifecycle<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _lifecycleQueue = _lifecycleQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _handleDesktopLine(String line) {
    if (line.startsWith('RESOLVE:')) {
      unawaited(_resolveForSidecar(line.substring('RESOLVE:'.length)));
      return;
    }
    if (line.startsWith('STATUS:')) {
      _handleNativeStatus(line.substring('STATUS:'.length));
      return;
    }
    commonPrint.log('TURN: ${sanitizeVideoCallTunnelLog(line)}');
  }

  Future<void> _resolveForSidecar(String hostname) async {
    // The sidecar blocks on this answer while holding its resolve mutex, so it must
    // always get exactly one reply — an empty one is a failure it can recover from,
    // silence is not.
    try {
      final addresses = await InternetAddress.lookup(
        hostname,
      ).timeout(videoCallTunnelResolveTimeout);
      final address = addresses
          .where((item) => item.type == InternetAddressType.IPv4)
          .firstOrNull;
      _stdin?.writeln('RESOLVED:${(address ?? addresses.first).address}');
    } catch (error) {
      commonPrint.log('TURN sidecar resolve failed (${error.runtimeType})');
      _stdin?.writeln('RESOLVED:');
    }
  }

  /// Restart the clock on the way into a call.
  ///
  /// Every sign of forward motion pushes it back, so this is "no progress for
  /// 90 seconds", not a budget for the whole join. The captcha stops it
  /// outright: a person is in a browser and their pace is not the sidecar's.
  void _armJoinDeadline([Duration duration = videoCallTunnelJoinDeadline]) {
    _joinDeadlineTimer?.cancel();
    _joinDeadlineTimer = Timer(duration, () {
      _joinDeadlineTimer = null;
      if (status.value == VideoCallTunnelStatus.connected) return;
      status.value = VideoCallTunnelStatus.joinTimedOut;
      final callback = onJoinTimeout;
      if (callback != null) unawaited(callback());
    });
  }

  void _cancelJoinDeadline() {
    _joinDeadlineTimer?.cancel();
    _joinDeadlineTimer = null;
  }

  void _handleNativeStatus(String value) {
    final nextCaptchaUri = parseVideoCallTunnelCaptchaUri(value);
    if (nextCaptchaUri != null) {
      final wasWaiting = status.value == VideoCallTunnelStatus.captchaRequired;
      captchaUri.value = nextCaptchaUri;
      status.value = VideoCallTunnelStatus.captchaRequired;
      _lastStage = 'captcha';
      // Widened, not cancelled. Cancelling put the wait back in the hands of
      // the sidecar, and the sidecar going quiet after the captcha is exactly
      // the failure this exists to end. A repeat of the same prompt does not
      // push the window out again, or a sidecar that reprints it every minute
      // buys itself forever one minute at a time.
      if (!wasWaiting) {
        _armJoinDeadline(videoCallTunnelCaptchaDeadline);
      }
      return;
    }
    if (value.startsWith('Captcha solved') ||
        value == 'Auth complete' ||
        value == 'LEAVE_ACK' ||
        value == 'TUNNEL_CONNECTED' ||
        value.startsWith('ERROR:')) {
      captchaUri.value = null;
    }
    if (value == 'LEAVE_ACK') {
      final completer = _leaveAckCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
    if (const {'READY', 'CONNECTING', 'RECONNECTING'}.contains(value) ||
        value.startsWith('Captcha solved') ||
        value == 'Auth complete') {
      _lastStage = value.startsWith('Captcha solved')
          ? 'captcha_solved'
          : value.toLowerCase();
      _armJoinDeadline();
    }
    status.value = switch (value) {
      'READY' => VideoCallTunnelStatus.connecting,
      'CONNECTING' => VideoCallTunnelStatus.connecting,
      'RECONNECTING' => VideoCallTunnelStatus.reconnecting,
      'TUNNEL_CONNECTED' => VideoCallTunnelStatus.connected,
      'TUNNEL_LOST' => VideoCallTunnelStatus.reconnecting,
      _ when value.startsWith('ERROR:') => VideoCallTunnelStatus.error,
      _ => status.value,
    };
    if (value == 'TUNNEL_LOST') {
      final callback = onTunnelLost;
      if (callback != null) unawaited(callback());
    }
    if (value == 'TUNNEL_CONNECTED') {
      _cancelJoinDeadline();
      unawaited(_logSocksReachability());
      final callback = onTunnelConnected;
      if (callback != null) unawaited(callback());
    }
    if (value.startsWith('ERROR:')) {
      _cancelJoinDeadline();
      final callback = onTerminalError;
      if (callback != null) unawaited(callback());
    }
    if (value == 'READY' && !system.isAndroid) {
      _stdin?.writeln(
        'AUTH:${jsonEncode({'joinLink': _activeJoinLink, 'displayName': videoCallTunnelDisplayName, 'tunnelMode': videoCallTunnelMode, 'vp8Fps': 0, 'vp8Batch': 0, 'dualTrack': false})}',
      );
    }
  }
}

extension on VideoCallTunnelController {
  /// One line in the log saying whether the sidecar's SOCKS port answers.
  ///
  /// "The proxy is red and no traffic passes" has several very different
  /// causes, and this splits the first one off: a port that does not answer
  /// means the sidecar never opened it, while a port that answers while the
  /// proxy stays red means the failure is past it — in the call, or in the
  /// core's route to it. Guessing between those from a bug report is what cost
  /// the last round.
  Future<void> _logSocksReachability() async {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        videoCallTunnelSocksPort,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      commonPrint.log('TURN SOCKS on $videoCallTunnelSocksPort is accepting');
    } catch (error) {
      commonPrint.log(
        'TURN SOCKS on $videoCallTunnelSocksPort is NOT accepting '
        '(${error.runtimeType}) — the tunnel reported connected, so the sidecar '
        'is up but its proxy port is not usable',
      );
    }
  }
}

final videoCallTunnelController = VideoCallTunnelController();
