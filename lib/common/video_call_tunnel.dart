import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

@immutable
class VideoCallTunnelLinkResult {
  final VideoCallTunnelLinkStatus status;
  final String? joinLink;

  const VideoCallTunnelLinkResult(this.status, {this.joinLink});
}

typedef VideoCallTunnelLinkFetcher =
    Future<VideoCallTunnelLinkResult> Function(String subscriptionUrl);

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
  const bypassRules = [
    'PROCESS-NAME,DHQClashTurn,DIRECT',
    'PROCESS-NAME,DHQClashTurn.exe,DIRECT',
    'PROCESS-NAME,libDHQClashTurn.so,DIRECT',
    'PROCESS-NAME,app.dhqclash,DIRECT',
  ];
  rules.removeWhere(bypassRules.contains);
  config['rules'] = [...bypassRules, ...rules];
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
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  String? _activeJoinLink;
  IOSink? _stdin;
  Completer<void>? _leaveAckCompleter;
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
        process.exitCode.then((_) {
          if (!_stopping &&
              _process == process &&
              status.value != VideoCallTunnelStatus.stopped) {
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
    try {
      final addresses = await InternetAddress.lookup(hostname);
      final address = addresses
          .where((item) => item.type == InternetAddressType.IPv4)
          .firstOrNull;
      _stdin?.writeln('RESOLVED:${(address ?? addresses.first).address}');
    } catch (_) {
      _stdin?.writeln('RESOLVED:');
    }
  }

  void _handleNativeStatus(String value) {
    final nextCaptchaUri = parseVideoCallTunnelCaptchaUri(value);
    if (nextCaptchaUri != null) {
      captchaUri.value = nextCaptchaUri;
      status.value = VideoCallTunnelStatus.captchaRequired;
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
      final callback = onTunnelConnected;
      if (callback != null) unawaited(callback());
    }
    if (value.startsWith('ERROR:')) {
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

final videoCallTunnelController = VideoCallTunnelController();
