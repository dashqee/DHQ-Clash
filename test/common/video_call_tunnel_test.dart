import 'package:fl_clash/common/video_call_tunnel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('video-call tunnel configuration', () {
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
      expect(
        buildVideoCallTunnelLinkUri(
          'https://sub.example.com/c_device.yaml?token=ignored',
        ),
        Uri.parse('https://sub.example.com/turn/link/c_device.yaml'),
      );
      expect(
        buildVideoCallTunnelLinkUri(
          'https://sub.example.com/nested/c_device.yaml',
        ),
        Uri.parse('https://sub.example.com/turn/link/c_device.yaml'),
      );
      expect(buildVideoCallTunnelLinkUri('not-a-url'), isNull);
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
        (result['proxies'] as List).last,
        containsPair('name', videoCallTunnelProxyName),
      );
      final groups = result['proxy-groups'] as List;
      expect((groups.first as Map)['proxies'], [
        'Direct VLESS',
        videoCallTunnelProxyName,
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
              'proxies': [videoCallTunnelProxyName, videoCallTunnelProxyName],
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
        hasLength(1),
      );
      expect((proxies.single as Map)['port'], 11790);
      expect(((result['proxy-groups'] as List).single as Map)['proxies'], [
        videoCallTunnelProxyName,
      ]);
      final fallbackGroup = (result['proxy-groups'] as List).single as Map;
      expect(fallbackGroup['url'], videoCallTunnelHealthCheckUrl);
      expect(fallbackGroup['interval'], videoCallTunnelHealthCheckInterval);
    });
  });
}
