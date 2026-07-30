import 'package:fl_clash/common/video_call_tunnel.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('ProfilesAction', () {
    test('deep link reuses an existing profile with the same URL', () {
      final original =
          Profile.normal(
            label: 'Old name',
            url: 'https://example.com/subscription',
          ).copyWith(
            selectedMap: const {'Proxy': 'Selected server'},
            autoUpdate: false,
          );

      final profile = profileForInstallUrl(
        [original],
        url: original.url,
        name: 'New name',
      );

      expect(profile.id, original.id);
      expect(profile.label, 'New name');
      expect(profile.selectedMap, original.selectedMap);
      expect(profile.autoUpdate, false);
    });

    test('deep link creates a profile when its URL is new', () {
      final profile = profileForInstallUrl(
        const [],
        url: 'https://example.com/new-subscription',
        name: 'New profile',
      );

      expect(profile.url, 'https://example.com/new-subscription');
      expect(profile.label, 'New profile');
    });

    test('keeps edited profile data when remote update fails', () async {
      final original = Profile.normal(label: 'old label', url: 'bad-url');
      final edited = original.copyWith(
        label: 'new label',
        url: 'still-bad-url',
      );
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => null),
          profilesProvider.overrideWith(() => _TestProfiles([original])),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(profilesProvider).getProfile(original.id),
        original,
      );

      await expectLater(
        container.read(profilesActionProvider.notifier).updateProfile(edited),
        throwsA(anything),
      );

      final profile = container.read(profilesProvider).getProfile(original.id);
      expect(profile?.label, edited.label);
      expect(profile?.url, edited.url);
    });
  });

  group('SetupAction', () {
    test('deep link enables TUN without enabling system proxy', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(setupActionProvider.notifier).prepareDeepLinkConnection();

      expect(container.read(patchClashConfigProvider).tun.enable, true);
      expect(container.read(vpnSettingProvider).enable, true);
      expect(container.read(networkSettingProvider).systemProxy, false);
    });

    test('TUN switch also enables the Android VPN service state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(setupActionProvider.notifier).setTunEnabled(true);

      expect(container.read(patchClashConfigProvider).tun.enable, true);
      expect(container.read(vpnSettingProvider).enable, true);

      container.read(setupActionProvider.notifier).setTunEnabled(false);

      expect(container.read(patchClashConfigProvider).tun.enable, false);
      expect(container.read(vpnSettingProvider).enable, false);
    });

    test('active Windows client restarts only when TUN is enabled', () {
      expect(
        shouldRestartCoreForTun(
          isWindows: true,
          isStarted: true,
          previousEnable: false,
          nextEnable: true,
        ),
        true,
      );
      expect(
        shouldRestartCoreForTun(
          isWindows: true,
          isStarted: true,
          previousEnable: true,
          nextEnable: false,
        ),
        false,
      );
      expect(
        shouldRestartCoreForTun(
          isWindows: false,
          isStarted: true,
          previousEnable: false,
          nextEnable: true,
        ),
        false,
      );
      expect(
        shouldRestartCoreForTun(
          isWindows: true,
          isStarted: false,
          previousEnable: false,
          nextEnable: true,
        ),
        false,
      );
    });

    test('stores the backend TURN link for the active subscription', () async {
      final profile = Profile.normal(
        url: 'https://sub.example.com/c_device.yaml',
      );
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          profilesProvider.overrideWith(() => _TestProfiles([profile])),
          videoCallTunnelSettingProvider.overrideWithBuild(
            (_, _) => const VideoCallTunnelProps(enable: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final refreshed = await container
          .read(setupActionProvider.notifier)
          .refreshVideoCallTunnel(
            startTunnel: false,
            fetchLink: (subscriptionUrl) async {
              expect(subscriptionUrl, profile.url);
              return const VideoCallTunnelLinkResult(
                VideoCallTunnelLinkStatus.available,
                joinLink: 'https://vk.ru/call/join/backend-link',
              );
            },
          );

      expect(refreshed, true);
      expect(
        container.read(videoCallTunnelSettingProvider).joinLink,
        'https://vk.ru/call/join/backend-link',
      );
    });

    test('clears a cached TURN link when entitlement is denied', () async {
      final profile = Profile.normal(
        url: 'https://sub.example.com/c_device.yaml',
      );
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          profilesProvider.overrideWith(() => _TestProfiles([profile])),
          videoCallTunnelSettingProvider.overrideWithBuild(
            (_, _) => const VideoCallTunnelProps(
              enable: true,
              joinLink: 'https://vk.ru/call/join/cached-link',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final refreshed = await container
          .read(setupActionProvider.notifier)
          .refreshVideoCallTunnel(
            startTunnel: false,
            fetchLink: (_) async => const VideoCallTunnelLinkResult(
              VideoCallTunnelLinkStatus.notEntitled,
            ),
          );

      expect(refreshed, false);
      expect(container.read(videoCallTunnelSettingProvider).joinLink, isEmpty);
    });
  });

  group('GeoResourceAction', () {
    test('GeoResource has correct updatingKey', () {
      expect(GeoResource.MMDB.updatingKey, 'geo_resource_MMDB');
      expect(GeoResource.ASN.updatingKey, 'geo_resource_ASN');
      expect(GeoResource.GEOIP.updatingKey, 'geo_resource_GEOIP');
      expect(GeoResource.GEOSITE.updatingKey, 'geo_resource_GEOSITE');
    });

    test('IsUpdating provider works with geo resource key', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final key = GeoResource.MMDB.updatingKey;
      expect(container.read(isUpdatingProvider(key)), false);

      container.read(isUpdatingProvider(key).notifier).value = true;
      expect(container.read(isUpdatingProvider(key)), true);

      container.read(isUpdatingProvider(key).notifier).value = false;
      expect(container.read(isUpdatingProvider(key)), false);
    });
  });
}

class _TestProfiles extends Profiles {
  final List<Profile> initial;

  _TestProfiles(this.initial);

  @override
  List<Profile> build() => initial;

  @override
  void put(Profile profile) {
    final next = List<Profile>.from(state);
    final index = next.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      next.add(profile);
    } else {
      next[index] = profile;
    }
    state = next;
  }
}
