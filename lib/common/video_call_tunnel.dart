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

enum VideoCallTunnelStatus {
  disabled,
  starting,
  connecting,
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

@immutable
class VideoCallTunnelLinkResult {
  final VideoCallTunnelLinkStatus status;
  final String? joinLink;

  const VideoCallTunnelLinkResult(this.status, {this.joinLink});
}

typedef VideoCallTunnelLinkFetcher =
    Future<VideoCallTunnelLinkResult> Function(String subscriptionUrl);

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
  return Uri(
    scheme: subscriptionUri.scheme,
    host: subscriptionUri.host,
    port: subscriptionUri.hasPort ? subscriptionUri.port : null,
    pathSegments: ['turn', 'link', pathSegments.last],
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
  proxies.add({
    'name': videoCallTunnelProxyName,
    'type': 'socks5',
    'server': '127.0.0.1',
    'port': port,
    'username': username,
    'password': password,
    'udp': true,
  });
  config['proxies'] = proxies;

  final groups = List<dynamic>.from(config['proxy-groups'] as List? ?? const [])
      .map((group) {
        return group is Map ? Map<String, dynamic>.from(group) : group;
      })
      .toList();
  for (final group in groups) {
    if (group is! Map || group['type']?.toString() != 'fallback') continue;
    final groupProxies = List<dynamic>.from(
      group['proxies'] as List? ?? const [],
    );
    groupProxies.removeWhere((item) => item == videoCallTunnelProxyName);
    groupProxies.add(videoCallTunnelProxyName);
    group['proxies'] = groupProxies;
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
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  VideoCallTunnelProps? _props;
  IOSink? _stdin;

  VideoCallTunnelController._internal();

  factory VideoCallTunnelController() {
    _instance ??= VideoCallTunnelController._internal();
    return _instance!;
  }

  Future<bool> start(VideoCallTunnelProps props) async {
    await stop();
    captchaUri.value = null;
    _props = props;
    if (!props.enable || props.joinLink.isEmpty) {
      status.value = VideoCallTunnelStatus.disabled;
      return false;
    }
    if (!isValidVideoCallJoinLink(props.joinLink)) {
      status.value = VideoCallTunnelStatus.error;
      return false;
    }

    status.value = VideoCallTunnelStatus.starting;
    final credentials = deriveVideoCallTunnelCredentials(props.joinLink);
    if (system.isAndroid) {
      app?.onVideoCallTunnelStatus = _handleNativeStatus;
      final started =
          await app?.startVideoCallTunnel(
            joinLink: props.joinLink,
            displayName: props.displayName,
            tunnelMode: props.tunnelMode,
            socksPort: props.socksPort,
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
        '${props.socksPort}',
        '--socks-user',
        credentials.username,
        '--socks-pass',
        credentials.password,
      ]);
      _process = process;
      _stdin = process.stdin;
      _stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleDesktopLine);
      _stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => commonPrint.log('TURN: $line'));
      unawaited(
        process.exitCode.then((_) {
          if (_process == process &&
              status.value != VideoCallTunnelStatus.stopped) {
            status.value = VideoCallTunnelStatus.error;
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

  Future<void> stop() async {
    app?.onVideoCallTunnelStatus = null;
    if (system.isAndroid) {
      await app?.stopVideoCallTunnel();
    }
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    await _stdin?.close();
    _stdin = null;
    _process?.kill();
    _process = null;
    _props = null;
    captchaUri.value = null;
    status.value = VideoCallTunnelStatus.stopped;
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
    commonPrint.log('TURN: $line');
  }

  Future<void> _resolveForSidecar(String hostname) async {
    try {
      final addresses = await InternetAddress.lookup(hostname);
      final address = addresses
          .where((item) => item.type == InternetAddressType.IPv4)
          .firstOrNull;
      _stdin?.writeln((address ?? addresses.first).address);
    } catch (_) {
      _stdin?.writeln('');
    }
  }

  void _handleNativeStatus(String value) {
    final nextCaptchaUri = parseVideoCallTunnelCaptchaUri(value);
    if (nextCaptchaUri != null) {
      captchaUri.value = nextCaptchaUri;
      status.value = VideoCallTunnelStatus.connecting;
      return;
    }
    if (value.startsWith('Captcha solved') ||
        value == 'Auth complete' ||
        value == 'TUNNEL_CONNECTED' ||
        value.startsWith('ERROR:')) {
      captchaUri.value = null;
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
    if (value == 'READY' && !system.isAndroid) {
      final props = _props;
      if (props == null) return;
      _stdin?.writeln(
        'AUTH:${jsonEncode({'joinLink': props.joinLink, 'displayName': props.displayName, 'tunnelMode': props.tunnelMode, 'vp8Fps': 0, 'vp8Batch': 0, 'dualTrack': false})}',
      );
    }
  }
}

final videoCallTunnelController = VideoCallTunnelController();
