import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> configurePreferences(int version) async {
    SharedPreferences.setMockInitialValues({'version': version});
    final sharedPreferences = await SharedPreferences.getInstance();
    preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
      ..complete(sharedPreferences);
  }

  Config disabledStartupConfig() => const Config(
    themeProps: defaultThemeProps,
    appSettingProps: AppSettingProps(
      autoLaunch: false,
      silentLaunch: false,
      autoRun: false,
    ),
  );

  // Mirror how a config is actually persisted and re-read (preferences stores
  // `json.encode(config)` and loads it back via `json.decode`), so nested
  // models arrive as plain maps just like in production.
  Map<String, Object?> storedConfigMap(Config config) =>
      json.decode(json.encode(config)) as Map<String, Object?>;

  test(
    'migration v2 enables startup defaults once for existing clients',
    () async {
      await configurePreferences(1);

      final migrated = await migration.migrationIfNeeded(
        storedConfigMap(disabledStartupConfig()),
        sync: (data) async => Config.realFromJson(data.configMap),
      );

      expect(migrated.appSettingProps.autoLaunch, true);
      expect(migrated.appSettingProps.silentLaunch, true);
      expect(migrated.appSettingProps.autoRun, true);
      expect(await preferences.getVersion(), 6);
    },
  );

  test('migration v2 preserves later user choices', () async {
    await configurePreferences(2);

    final config = await migration.migrationIfNeeded(
      storedConfigMap(disabledStartupConfig()),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(config.appSettingProps.autoLaunch, false);
    expect(config.appSettingProps.silentLaunch, false);
    expect(config.appSettingProps.autoRun, false);
  });

  const legacyPrimaryColor = 0xFFD8C0C3;
  const legacyPrimaryColors = [
    0xFF795548,
    0xFF03A9F4,
    0xFFFFFF00,
    0xFFBBC9CC,
    0xFFABD397,
    legacyPrimaryColor,
    0xFF665390,
  ];

  test(
    'migration v3 applies fruit mix to clients on the legacy default theme',
    () async {
      await configurePreferences(2);

      const legacy = Config(
        themeProps: ThemeProps(
          primaryColor: legacyPrimaryColor,
          primaryColors: legacyPrimaryColors,
        ),
      );

      final migrated = await migration.migrationIfNeeded(
        storedConfigMap(legacy),
        sync: (data) async => Config.realFromJson(data.configMap),
      );

      expect(migrated.themeProps.primaryColor, defaultPrimaryColor);
      expect(migrated.themeProps.primaryColors, defaultPrimaryColors);
      expect(await preferences.getVersion(), 6);
    },
  );

  test('migration v4 switches existing clients to the list view', () async {
    // The default became `list` for fresh installs only; everyone already using
    // the app has `tab` written into their config and would never see it.
    await configurePreferences(3);

    const tabbed = Config(
      themeProps: defaultThemeProps,
      proxiesStyleProps: ProxiesStyleProps(type: ProxiesType.tab),
    );

    final migrated = await migration.migrationIfNeeded(
      storedConfigMap(tabbed),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(migrated.proxiesStyleProps.type, ProxiesType.list);
    expect(await preferences.getVersion(), 6);
  });

  test('migration v4 keeps the rest of the proxies style', () async {
    // Sort order, layout, icon style and card size may have been set
    // deliberately; changing the view is no reason to reset them.
    await configurePreferences(3);

    const styled = Config(
      themeProps: defaultThemeProps,
      proxiesStyleProps: ProxiesStyleProps(
        type: ProxiesType.tab,
        sortType: ProxiesSortType.delay,
        layout: ProxiesLayout.tight,
        iconStyle: ProxiesIconStyle.none,
        cardType: ProxyCardType.min,
      ),
    );

    final migrated = await migration.migrationIfNeeded(
      storedConfigMap(styled),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(migrated.proxiesStyleProps.type, ProxiesType.list);
    expect(migrated.proxiesStyleProps.sortType, ProxiesSortType.delay);
    expect(migrated.proxiesStyleProps.layout, ProxiesLayout.tight);
    expect(migrated.proxiesStyleProps.iconStyle, ProxiesIconStyle.none);
    expect(migrated.proxiesStyleProps.cardType, ProxyCardType.min);
  });

  test('migration v4 leaves a client who went back to tabs alone', () async {
    // Once the switch has happened, choosing tabs again is a decision. Running
    // on every start would undo it after each launch.
    await configurePreferences(4);

    const tabbed = Config(
      themeProps: defaultThemeProps,
      proxiesStyleProps: ProxiesStyleProps(type: ProxiesType.tab),
    );

    final migrated = await migration.migrationIfNeeded(
      storedConfigMap(tabbed),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(migrated.proxiesStyleProps.type, ProxiesType.tab);
  });

  test('migration v3 keeps a user-customized theme', () async {
    await configurePreferences(2);

    const customColor = 0xFF123456;
    const custom = Config(
      themeProps: ThemeProps(
        primaryColor: customColor,
        primaryColors: [customColor, 0xFF00FF00],
      ),
    );

    final migrated = await migration.migrationIfNeeded(
      storedConfigMap(custom),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(migrated.themeProps.primaryColor, customColor);
    expect(migrated.themeProps.primaryColors, [customColor, 0xFF00FF00]);
  });

  test('migration v5 turns TUN and the VPN service on once', () async {
    // Both defaults became true, but existing clients have false written
    // into their config and would keep starting a VPN that routes nothing.
    await configurePreferences(4);

    const off = Config(
      themeProps: defaultThemeProps,
      vpnProps: VpnProps(enable: false),
      patchClashConfig: PatchClashConfig(tun: Tun(enable: false)),
    );

    final migrated = await migration.migrationIfNeeded(
      storedConfigMap(off),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(migrated.patchClashConfig.tun.enable, true);
    expect(migrated.vpnProps.enable, true);
    expect(await preferences.getVersion(), 6);
  });

  test('migration v6 turns the automatic update check back on', () async {
    // The old dialog's "don't remind again" switched the check off for good;
    // the button is gone, and everyone gets the check back once.
    await configurePreferences(5);

    const off = Config(
      themeProps: defaultThemeProps,
      appSettingProps: AppSettingProps(autoCheckUpdate: false),
    );

    final migrated = await migration.migrationIfNeeded(
      storedConfigMap(off),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(migrated.appSettingProps.autoCheckUpdate, true);
    expect(await preferences.getVersion(), 6);
  });

  test('migration v6 keeps a later choice to switch the check off', () async {
    await configurePreferences(6);

    const off = Config(
      themeProps: defaultThemeProps,
      appSettingProps: AppSettingProps(autoCheckUpdate: false),
    );

    final config = await migration.migrationIfNeeded(
      storedConfigMap(off),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(config.appSettingProps.autoCheckUpdate, false);
  });

  test('migration v5 keeps a later choice to turn them off', () async {
    await configurePreferences(5);

    const off = Config(
      themeProps: defaultThemeProps,
      vpnProps: VpnProps(enable: false),
      patchClashConfig: PatchClashConfig(tun: Tun(enable: false)),
    );

    final config = await migration.migrationIfNeeded(
      storedConfigMap(off),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(config.patchClashConfig.tun.enable, false);
    expect(config.vpnProps.enable, false);
  });
}
