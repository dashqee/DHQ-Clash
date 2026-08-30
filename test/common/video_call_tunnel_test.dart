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

    test('leaves routing to the rules while it is only a fallback', () {
      // The pin must not leak into ordinary use: unpinned, the tunnel is
      // reachable only through the provider the Fallback group uses, and the
      // profile's own rules still decide everything.
      final result = addVideoCallTunnelToConfig(
        {
          'rules': ['RULE-SET,ads,REJECT', 'MATCH,Local'],
        },
        port: 11789,
        username: 'user',
        password: 'secret',
      );

      expect(
        (result['proxies'] as List).where(
          (proxy) => (proxy as Map)['name'] == videoCallTunnelProxyName,
        ),
        isEmpty,
      );
      expect((result['rules'] as List).skip(videoCallTunnelBypassRules.length), [
        'RULE-SET,ads,REJECT',
        'MATCH,Local',
      ]);
    });

    test('pinned, every route ends at the tunnel', () {
      final result = addVideoCallTunnelToConfig(
        {
          'rules': ['RULE-SET,ads,REJECT', 'MATCH,Local'],
        },
        port: 11789,
        username: 'user',
        password: 'secret',
        pinned: true,
      );

      // A rule target is resolved against `proxies:` and the group names, so a
      // provider-only proxy would leave MATCH pointing at nothing.
      expect(
        ((result['proxies'] as List).single as Map)['name'],
        videoCallTunnelProxyName,
      );
      expect(result['rules'], [
        ...videoCallTunnelBypassRules,
        ...videoCallTunnelPinRules,
      ]);
      // The sidecar's own way out has to stay above the catch-all, or it ends
      // up dialling its own SOCKS port.
      final rules = result['rules'] as List;
      expect(
        rules.indexOf('PROCESS-NAME,DHQClashTurn,DIRECT'),
        lessThan(rules.indexOf('MATCH,$videoCallTunnelProxyName')),
      );
      // So does the LAN: with the catch-all above it, even the core's own
      // external-controller would be routed into the call.
      expect(
        rules.indexOf('IP-CIDR,192.168.0.0/16,DIRECT,no-resolve'),
        lessThan(rules.indexOf('MATCH,$videoCallTunnelProxyName')),
      );
      expect(rules.last, 'MATCH,$videoCallTunnelProxyName');
    });

    test('pinning twice changes nothing the second time', () {
      // The config is regenerated on every applyProfile, and the pin is applied
      // to whatever the previous pass produced.
      Map<String, dynamic> pin(Map<String, dynamic> source) =>
          addVideoCallTunnelToConfig(
            source,
            port: 11789,
            username: 'user',
            password: 'secret',
            pinned: true,
          );

      final once = pin({
        'rules': ['MATCH,Local'],
      });
      final twice = pin(once);

      expect((twice['proxies'] as List).length, 1);
      expect(twice['rules'], once['rules']);
    });

    test('unpinning brings the original rules back', () {
      final source = {
        'rules': ['RULE-SET,ads,REJECT', 'MATCH,Local'],
      };
      final pinned = addVideoCallTunnelToConfig(
        source,
        port: 11789,
        username: 'user',
        password: 'secret',
        pinned: true,
      );
      // Nothing carries the old rules back on its own — they come from the
      // profile, which is what the next applyProfile regenerates from.
      final unpinned = addVideoCallTunnelToConfig(
        source,
        port: 11789,
        username: 'user',
        password: 'secret',
      );

      expect(pinned['rules'], isNot(unpinned['rules']));
      expect((unpinned['rules'] as List).skip(videoCallTunnelBypassRules.length), [
        'RULE-SET,ads,REJECT',
        'MATCH,Local',
      ]);
      expect(
        (unpinned['proxies'] as List).where(
          (proxy) => (proxy as Map)['name'] == videoCallTunnelProxyName,
        ),
        isEmpty,
      );
    });

    test('VK stays reachable without the tunnel it carries', () {
      // The process rules all rest on the core resolving the owning process,
      // which is the part that fails on Windows; these do not depend on it, and
      // a tunnel that rides on a VK call needs VK reachable either way.
      for (final pinned in [false, true]) {
        final result = addVideoCallTunnelToConfig(
          {
            'rules': ['MATCH,Local'],
          },
          port: 11789,
          username: 'user',
          password: 'secret',
          pinned: pinned,
        );
        final rules = (result['rules'] as List).cast<String>();
        expect(rules, contains('DOMAIN-SUFFIX,vk.ru,DIRECT'));
        expect(rules, contains('DOMAIN-SUFFIX,vk.com,DIRECT'));
        final catchAll = rules.indexOf('MATCH,$videoCallTunnelProxyName');
        if (catchAll >= 0) {
          expect(rules.indexOf('DOMAIN-SUFFIX,vk.ru,DIRECT'), lessThan(catchAll));
        }
      }
    });

    test('the mode may not leave rule matching while pinned', () {
      // In global or direct the core matches no rules at all, so the catch-all
      // that carries everything into the tunnel would simply not run.
      const pinned = VideoCallTunnelProps(enable: true, pinned: true);
      expect(videoCallTunnelAllowsMode(pinned, Mode.rule), isTrue);
      expect(videoCallTunnelAllowsMode(pinned, Mode.global), isFalse);
      expect(videoCallTunnelAllowsMode(pinned, Mode.direct), isFalse);
    });

    test('an unpinned tunnel does not hold the mode', () {
      for (final props in const [
        VideoCallTunnelProps(enable: true),
        VideoCallTunnelProps(pinned: true),
        VideoCallTunnelProps(),
      ]) {
        for (final mode in Mode.values) {
          expect(videoCallTunnelAllowsMode(props, mode), isTrue);
        }
      }
    });

    test('reports the join outcome next to where it asked for the link', () {
      // The backend cannot tell a live VK call from a dead one — it gets the
      // same page for both — so the joiner is the only witness there is.
      expect(
        buildVideoCallTunnelStatusUri(
          'https://sub.example.com/configs/c_device.yaml',
        ).toString(),
        'https://sub.example.com/configs/turn/status/c_device.yaml',
      );
      expect(buildVideoCallTunnelStatusUri('not a url'), isNull);
    });

    test('the pin is given a bounded life, not an unbounded one', () {
      // Pinned to a channel that never comes back, the machine has no internet
      // and nothing on screen to explain it.
      expect(videoCallTunnelPinGrace.inSeconds, greaterThan(
        videoCallTunnelReconnectGrace.inSeconds,
      ));
      expect(videoCallTunnelPinGrace.inMinutes, lessThanOrEqualTo(10));
    });

    test('the join is given a deadline the captcha does not eat', () {
      // Nothing else bounds the way into a call: the sidecar reports TUNNEL_LOST
      // and ERROR, and has nothing at all to say about a call it entered where
      // no one is waiting.
      expect(videoCallTunnelJoinDeadline.inSeconds, greaterThan(30));
      expect(
        videoCallTunnelJoinDeadline.inSeconds,
        lessThan(videoCallTunnelPinGrace.inSeconds),
        reason: 'the join must fail before the routing pin is released, or the '
            'user sees the outage before the reason for it',
      );
    });

    test('the backend says whose call the link is', () {
      // The client cannot tell by looking — both are ordinary VK links — and it
      // changes what a failed join should say.
      expect(
        parseVideoCallTunnelLinkResponse(200, {
          'join_link': 'https://vk.ru/call/join/abc',
          'source': 'custom',
        }).source,
        VideoCallTunnelSource.custom,
      );
      expect(
        parseVideoCallTunnelLinkResponse(200, {
          'join_link': 'https://vk.ru/call/join/abc',
          'source': 'managed',
        }).source,
        VideoCallTunnelSource.managed,
      );
    });

    test('an older backend that says nothing is still usable', () {
      // The field only ever changes the wording of a failure, so its absence
      // must not make the link itself unusable.
      final result = parseVideoCallTunnelLinkResponse(200, {
        'join_link': 'https://vk.ru/call/join/abc',
      });
      expect(result.status, VideoCallTunnelLinkStatus.available);
      expect(result.source, isNull);
      expect(
        parseVideoCallTunnelLinkResponse(200, {
          'join_link': 'https://vk.ru/call/join/abc',
          'source': 'something-new',
        }).source,
        isNull,
      );
    });

    test('the captcha widens the deadline instead of removing it', () {
      // Removing it handed the wait back to the sidecar, and a sidecar that has
      // gone quiet after the captcha is the failure this exists to end. That is
      // what kept the app in "connecting" for ever.
      expect(
        videoCallTunnelCaptchaDeadline,
        greaterThan(videoCallTunnelJoinDeadline),
      );
      // Long enough to walk away and come back, short enough to still be an
      // answer rather than a hang.
      expect(videoCallTunnelCaptchaDeadline.inMinutes, inInclusiveRange(5, 20));
    });

    test('every wait ends before the routing pin outlives it', () {
      // Both deadlines have to fire before the pin is released, or the user
      // meets the outage before the explanation for it.
      for (final deadline in [
        videoCallTunnelJoinDeadline,
        videoCallTunnelCaptchaDeadline,
      ]) {
        expect(
          deadline.inSeconds,
          lessThan(const Duration(days: 1).inSeconds),
          reason: 'a deadline that never fires is the bug being fixed',
        );
      }
      expect(
        videoCallTunnelJoinDeadline.inSeconds,
        lessThan(videoCallTunnelPinGrace.inSeconds),
      );
    });

    test('forces process matching on, whatever the user picked', () {
      // The PROCESS-NAME bypass rules are the only thing keeping the sidecar's own
      // traffic out of its own SOCKS port; without process matching they are inert.
      final result = addVideoCallTunnelToConfig(
        {'find-process-mode': FindProcessMode.off.name},
        port: 11789,
        username: 'user',
        password: 'secret',
      );

      expect(result['find-process-mode'], FindProcessMode.always.name);
      expect(
        (result['rules'] as List).take(videoCallTunnelBypassRules.length),
        containsAll(<String>[
          'PROCESS-NAME,DHQClashTurn,DIRECT',
          'PROCESS-NAME,DHQClashTurn.exe,DIRECT',
        ]),
      );
    });
  });
}
