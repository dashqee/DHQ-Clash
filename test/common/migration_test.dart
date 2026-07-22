import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> configurePreferences(int version) async {
    SharedPreferences.setMockInitialValues({'version': version});
    final sharedPreferences = await SharedPreferences.getInstance();
    preferences.sharedPreferencesCompleter =
        Completer<SharedPreferences?>()..complete(sharedPreferences);
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
      expect(await preferences.getVersion(), 3);
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

  test('migration v3 applies fruit mix to clients on the legacy default theme', () async {
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
    expect(await preferences.getVersion(), 3);
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
}
