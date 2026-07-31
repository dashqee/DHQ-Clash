import 'package:fl_clash/common/video_call_tunnel.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('video-call tunnel configuration', () {
    test('selects the fallback route for foreign traffic', () {
      final selectedMap = applyVideoCallTunnelRoutingSelections(const {
        'PROXY': 'MAIN',
        'Telegram': 'Local',
        'YouTube': 'BACKUP',
        'Custom proxy': 'Local',
      });

      expect(selectedMap, {
        'PROXY': 'Fallback',
        'Telegram': 'PROXY',
        'YouTube': 'PROXY',
        'Custom proxy': 'Local',
      });
    });

    test('accepts VK join links only', () {
      expect(isValidVideoCallJoinLink('https://vk.ru/call/join/abc'), isTrue);
      expect(isValidVideoCallJoinLink('https://vk.com/call/join/abc'), isTrue);
      expect(
        isValidVideoCallJoinLink('https://example.com/call/join/abc'),
        isFalse,
      );
      expect(isValidVideoCallJoinLink('vless://example.com'), isFalse);
    });

    test('builds the backend link endpoint from a subscription URL', () {
      const validCases = {
        'https://h/configs/c_X.yaml': 'https://h/configs/turn/link/c_X.yaml',
        'https://h/c_X.yaml': 'https://h/turn/link/c_X.yaml',
        'https://h/a/b/c_X.yaml': 'https://h/a/b/turn/link/c_X.yaml',
        'https://h:8443/configs/c_X.yaml':
            'https://h:8443/configs/turn/link/c_X.yaml',
        'https://h/configs/c_X.yaml?t=1':
            'https://h/configs/turn/link/c_X.yaml',
      };

      for (final MapEntry(:key, :value) in validCases.entries) {
        expect(buildVideoCallTunnelLinkUri(key), Uri.parse(value), reason: key);
      }
      for (final value in [
        'https://h/',
        'not-a-url',
        'https:///configs/c_X.yaml',
        '',
      ]) {
        expect(buildVideoCallTunnelLinkUri(value), isNull, reason: value);
      }
    });

    test('parses backend link entitlement and availability responses', () {
      expect(
        parseVideoCallTunnelLinkResponse(403, null).status,
        VideoCallTunnelLinkStatus.notEntitled,
      );
      expect(
        parseVideoCallTunnelLinkResponse(503, null).status,
        VideoCallTunnelLinkStatus.temporarilyUnavailable,
      );
      final available = parseVideoCallTunnelLinkResponse(200, {
        'join_link': 'https://vk.ru/call/join/backend-link',
      });
      expect(available.status, VideoCallTunnelLinkStatus.available);
      expect(available.joinLink, 'https://vk.ru/call/join/backend-link');
      expect(
        parseVideoCallTunnelLinkResponse(200, {
          'join_link': 'https://example.com/not-vk',
        }).status,
        VideoCallTunnelLinkStatus.error,
      );
    });

    test('accepts only local CAPTCHA URLs emitted by the sidecar', () {
      expect(
        parseVideoCallTunnelCaptchaUri('CAPTCHA:http://127.0.0.1:51618/'),
        Uri.parse('http://127.0.0.1:51618/'),
      );
      expect(
        parseVideoCallTunnelCaptchaUri(
          'CAPTCHA:http://localhost:50011/captcha',
        ),
        Uri.parse('http://localhost:50011/captcha'),
      );
      expect(
        parseVideoCallTunnelCaptchaUri('CAPTCHA:https://vk.ru/captcha'),
        isNull,
      );
      expect(
        parseVideoCallTunnelCaptchaUri(
          'CAPTCHA:http://example.com:50011/captcha',
        ),
        isNull,
      );
      expect(
        parseVideoCallTunnelCaptchaUri('CAPTCHA:http://127.0.0.1/'),
        isNull,
      );
    });

    test('derives stable non-empty SOCKS credentials', () {
      final first = deriveVideoCallTunnelCredentials(
        'https://vk.ru/call/join/abc',
      );
      final second = deriveVideoCallTunnelCredentials(
        'https://vk.ru/call/join/abc',
      );

      expect(first.username, second.username);
      expect(first.password, second.password);
      expect(first.username, isNotEmpty);
      expect(first.password.length, greaterThanOrEqualTo(24));
    });

    test('restarts only for a rotated link or unhealthy runtime', () {
      expect(
        shouldStartVideoCallTunnel(
          previousJoinLink: 'https://vk.ru/call/join/sticky',
          joinLink: 'https://vk.ru/call/join/sticky',
          status: VideoCallTunnelStatus.connected,
        ),
        false,
      );
      expect(
        shouldStartVideoCallTunnel(
          previousJoinLink: 'https://vk.ru/call/join/sticky',
          joinLink: 'https://vk.ru/call/join/sticky',
          status: VideoCallTunnelStatus.reconnecting,
        ),
        true,
      );
      expect(
        shouldStartVideoCallTunnel(
          previousJoinLink: 'https://vk.ru/call/join/old',
          joinLink: 'https://vk.ru/call/join/new',
          status: VideoCallTunnelStatus.connected,
        ),
        true,
      );
    });

    test('serializes tunnel shutdown requests', () async {
      final startResult = await videoCallTunnelController
          .start(const VideoCallTunnelProps(enable: false), joinLink: '')
          .timeout(const Duration(seconds: 1));

      expect(startResult, isFalse);
      expect(
        videoCallTunnelController.status.value,
        VideoCallTunnelStatus.disabled,
      );
      await Future.wait([
        videoCallTunnelController.stop(),
        videoCallTunnelController.stop(),
      ]).timeout(const Duration(seconds: 1));
      expect(
        videoCallTunnelController.status.value,
        VideoCallTunnelStatus.stopped,
      );
    });

    test('redacts call-scoped links from sidecar logs', () {
      expect(
        sanitizeVideoCallTunnelLog(
          'obf key-source="https://vk.ru/call/join/private-token"',
        ),
        'obf key-source="https://vk.ru/call/join/[redacted]"',
      );
    });

    test('adds TURN proxy only to the primary Fallback group', () {
      final source = <String, dynamic>{
        'proxies': [
          {'name': 'Direct VLESS', 'type': 'vless'},
        ],
        'proxy-groups': [
          {
            'name': 'Fallback',
            'type': 'fallback',
            'proxies': ['Direct VLESS'],
            'use': ['MAIN', 'BACKUP'],
          },
          {
            'name': 'EXTRA',
            'type': 'fallback',
            'proxies': ['Extra VLESS'],
          },
          {
            'name': 'Manual',
            'type': 'select',
            'proxies': ['Direct VLESS'],
          },
        ],
        'rules': ['MATCH,Fallback'],
      };

      final result = addVideoCallTunnelToConfig(
        source,
        port: 11789,
        username: 'user',
        password: 'secret',
      );

      expect(
        (result['proxies'] as List).where(
          (proxy) =>
              proxy is Map &&
              proxy['name']?.toString() == videoCallTunnelProxyName,
        ),
        isEmpty,
      );
      final turnProvider =
          (result['proxy-providers'] as Map)[videoCallTunnelProviderName]
              as Map;
      expect(turnProvider['type'], 'inline');
      expect(
        ((turnProvider['payload'] as List).single as Map)['name'],
        videoCallTunnelProxyName,
      );
      final groups = result['proxy-groups'] as List;
      expect((groups.first as Map)['proxies'], ['Direct VLESS']);
      expect((groups.first as Map)['use'], [
        'MAIN',
        'BACKUP',
        videoCallTunnelProviderName,
      ]);
      expect((groups[1] as Map)['proxies'], ['Extra VLESS']);
      expect((groups.last as Map)['proxies'], ['Direct VLESS']);
      expect(
        (result['rules'] as List).first,
        'PROCESS-NAME,DHQClashTurn,DIRECT',
      );
      expect(((source['proxy-groups'] as List).first as Map)['proxies'], [
        'Direct VLESS',
      ]);
    });

    test('replaces an existing TURN proxy without duplicating it', () {
      final result = addVideoCallTunnelToConfig(
        {
          'proxies': [
            {'name': videoCallTunnelProxyName, 'type': 'socks5'},
          ],
          'proxy-groups': [
            {
              'name': 'Fallback',
              'type': 'fallback',
              'proxies': [
                videoCallTunnelProxyName,
                'MAIN',
                videoCallTunnelProxyName,
                'BACKUP',
              ],
              'use': [videoCallTunnelProviderName, 'EXTRA'],
            },
          ],
        },
        port: 11790,
        username: 'next',
        password: 'secret',
      );

      final proxies = result['proxies'] as List;
      expect(
        proxies.where(
          (proxy) => (proxy as Map)['name'] == videoCallTunnelProxyName,
        ),
        isEmpty,
      );
      final turnProvider =
          (result['proxy-providers'] as Map)[videoCallTunnelProviderName]
              as Map;
      final turnProxy = (turnProvider['payload'] as List).single as Map;
      expect(turnProxy['port'], 11790);
      expect(((result['proxy-groups'] as List).single as Map)['proxies'], [
        'MAIN',
        'BACKUP',
      ]);
      final fallbackGroup = (result['proxy-groups'] as List).single as Map;
      expect(fallbackGroup['use'], ['EXTRA', videoCallTunnelProviderName]);
      expect(fallbackGroup['url'], videoCallTunnelHealthCheckUrl);
      expect(fallbackGroup['interval'], videoCallTunnelHealthCheckInterval);
    });

    test('appends TURN after providers in an overridden Fallback model', () {
      final result = addVideoCallTunnelToConfig(
        {
          'proxy-groups': [
            const ProxyGroup(
              id: 1,
              name: 'Fallback',
              type: GroupType.Fallback,
              use: ['MAIN', 'BACKUP'],
            ),
          ],
        },
        port: 11789,
        username: 'user',
        password: 'secret',
      );

      final fallbackGroup = (result['proxy-groups'] as List).single as Map;
      expect(fallbackGroup['use'], [
        'MAIN',
        'BACKUP',
        videoCallTunnelProviderName,
      ]);
    });
  });
}
