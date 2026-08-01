import 'dart:async';

import 'package:fl_clash/common/video_call_tunnel.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
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

    test(
      'active profile refresh waits for a forced config application',
      () async {
        final profile = Profile.normal(
          label: 'old label',
          url: 'https://example.com/subscription',
        );
        final refreshedProfile = profile.copyWith(
          label: 'new label',
          lastUpdateDate: DateTime(2026),
        );
        final applyCompleter = Completer<void>();
        final setupAction = _TestSetupAction(applyCompleter);
        var clashConfigReadCount = 0;
        final container = ProviderContainer(
          overrides: [
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            profilesProvider.overrideWith(() => _TestProfiles([profile])),
            setupActionProvider.overrideWith(() => setupAction),
            clashConfigProvider.overrideWith((_, _) async {
              clashConfigReadCount++;
              return const ClashConfig();
            }),
          ],
        );
        addTearDown(container.dispose);

        final clashConfigSubscription = container.listen(
          clashConfigProvider(profile.id),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(clashConfigSubscription.close);
        await container.read(clashConfigProvider(profile.id).future);
        var updateCompleted = false;
        final updateFuture = container
            .read(profilesActionProvider.notifier)
            .updateProfile(
              profile,
              refreshProfile: (_) async => refreshedProfile,
            )
            .whenComplete(() => updateCompleted = true);

        await setupAction.applyStarted.future;
        expect(updateCompleted, false);
        expect(setupAction.force, true);
        expect(setupAction.silence, true);
        expect(
          container.read(profilesProvider).getProfile(profile.id),
          refreshedProfile,
        );
        expect(clashConfigReadCount, 1);

        applyCompleter.complete();
        await updateFuture;
        await container.read(clashConfigProvider(profile.id).future);

        expect(clashConfigReadCount, 2);
      },
    );
  });

  group('SetupAction', () {
    tearDown(videoCallTunnelController.stop);

    test('global mode defaults to PROXY for a new profile selection', () async {
      final profile = Profile.normal(url: 'https://example.com/subscription');
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          profilesProvider.overrideWith(() => _TestProfiles([profile])),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(setupActionProvider.notifier)
          .changeMode(Mode.global);

      expect(container.read(patchClashConfigProvider).mode, Mode.global);
      expect(
        container.read(currentProfileProvider)?.selectedMap['GLOBAL'],
        'PROXY',
      );
    });

    test('global mode preserves an explicit proxy selection', () async {
      final profile = Profile.normal(
        url: 'https://example.com/subscription',
      ).copyWith(selectedMap: const {'GLOBAL': 'Custom proxy'});
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          profilesProvider.overrideWith(() => _TestProfiles([profile])),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(setupActionProvider.notifier)
          .changeMode(Mode.global);

      expect(
        container.read(currentProfileProvider)?.selectedMap['GLOBAL'],
        'Custom proxy',
      );
    });

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

    test(
      'enabling TURN refreshes the profile and selects its routes',
      () async {
        final profile =
            Profile.normal(
              label: 'Cached profile',
              url: 'https://sub.example.com/configs/c_device.yaml',
            ).copyWith(
              selectedMap: const {
                'PROXY': 'MAIN',
                'Telegram': 'Local',
                'YouTube': 'BACKUP',
                'Custom proxy': 'Local',
              },
            );
        var refreshCount = 0;
        final container = ProviderContainer(
          overrides: [
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            profilesProvider.overrideWith(() => _TestProfiles([profile])),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(setupActionProvider.notifier)
            .setVideoCallTunnelEnabled(
              true,
              refreshProfile: (currentProfile) async {
                refreshCount++;
                expect(currentProfile, profile);
                return currentProfile.copyWith(label: 'Refreshed profile');
              },
              fetchLink: (subscriptionUrl) async {
                expect(subscriptionUrl, profile.url);
                return const VideoCallTunnelLinkResult(
                  VideoCallTunnelLinkStatus.available,
                  joinLink: 'https://vk.ru/call/join/backend-link',
                );
              },
            );

        final updatedProfile = container.read(currentProfileProvider)!;
        expect(refreshCount, 1);
        expect(updatedProfile.label, 'Refreshed profile');
        expect(updatedProfile.selectedMap, {
          'PROXY': 'Fallback',
          'Telegram': 'PROXY',
          'YouTube': 'PROXY',
          'Custom proxy': 'Local',
        });
        expect(container.read(videoCallTunnelSettingProvider).enable, true);
      },
    );

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

    test('keeps the pooled TURN assignment in runtime state', () async {
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
        container.read(videoCallTunnelSettingProvider).toJson(),
        isNot(contains('joinLink')),
      );
      final retainedDuringPoolExhaustion = await container
          .read(setupActionProvider.notifier)
          .refreshVideoCallTunnel(
            startTunnel: false,
            fetchLink: (_) async => const VideoCallTunnelLinkResult(
              VideoCallTunnelLinkStatus.temporarilyUnavailable,
            ),
          );
      expect(retainedDuringPoolExhaustion, false);
      final reusedRuntimeLink = await container
          .read(setupActionProvider.notifier)
          .refreshVideoCallTunnel(
            startTunnel: false,
            fetchLink: (_) async => const VideoCallTunnelLinkResult(
              VideoCallTunnelLinkStatus.invalidSubscription,
            ),
          );
      expect(reusedRuntimeLink, true);
    });

    test('clears the runtime TURN link when entitlement is denied', () async {
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

      final action = container.read(setupActionProvider.notifier);
      await action.refreshVideoCallTunnel(
        startTunnel: false,
        fetchLink: (_) async => const VideoCallTunnelLinkResult(
          VideoCallTunnelLinkStatus.available,
          joinLink: 'https://vk.ru/call/join/cached-link',
        ),
      );
      final refreshed = await action.refreshVideoCallTunnel(
        startTunnel: false,
        fetchLink: (_) async => const VideoCallTunnelLinkResult(
          VideoCallTunnelLinkStatus.notEntitled,
        ),
      );

      expect(refreshed, false);
      expect(
        videoCallTunnelController.status.value,
        VideoCallTunnelStatus.notEntitled,
      );
      final reusedRuntimeLink = await action.refreshVideoCallTunnel(
        startTunnel: false,
        fetchLink: (_) async => const VideoCallTunnelLinkResult(
          VideoCallTunnelLinkStatus.invalidSubscription,
        ),
      );
      expect(reusedRuntimeLink, false);
    });

    test('denied entitlement keeps re-asking until a slot is assigned', () async {
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

      final action = container.read(setupActionProvider.notifier);
      // The slot is bought in the mini app, so a 403 must not stop the client from
      // asking again — otherwise the purchase needs an app restart to take effect.
      await action.refreshVideoCallTunnel(
        startTunnel: false,
        fetchLink: (_) async => const VideoCallTunnelLinkResult(
          VideoCallTunnelLinkStatus.notEntitled,
        ),
      );
      expect(action.hasPendingTurnEntitlementRecheck, true);

      await action.refreshVideoCallTunnel(
        startTunnel: false,
        fetchLink: (_) async => const VideoCallTunnelLinkResult(
          VideoCallTunnelLinkStatus.available,
          joinLink: 'https://vk.ru/call/join/granted-link',
        ),
      );
      expect(action.hasPendingTurnEntitlementRecheck, false);
    });

    test('turning the tunnel off drops the entitlement re-check', () async {
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

      final action = container.read(setupActionProvider.notifier);
      await action.refreshVideoCallTunnel(
        startTunnel: false,
        fetchLink: (_) async => const VideoCallTunnelLinkResult(
          VideoCallTunnelLinkStatus.notEntitled,
        ),
      );
      expect(action.hasPendingTurnEntitlementRecheck, true);

      await action.setVideoCallTunnelEnabled(false);

      expect(action.hasPendingTurnEntitlementRecheck, false);
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

class _TestSetupAction extends SetupAction {
  final Completer<void> applyCompleter;
  final Completer<void> applyStarted = Completer<void>();
  bool? force;
  bool? silence;

  _TestSetupAction(this.applyCompleter);

  @override
  void build() {}

  @override
  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    void Function()? preloadInvoke,
  }) async {
    this.force = force;
    this.silence = silence;
    applyStarted.complete();
    await applyCompleter.future;
  }
}
