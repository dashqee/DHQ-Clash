import 'dart:async';

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

  test(
    'migration v2 enables startup defaults once for existing clients',
    () async {
      await configurePreferences(1);

      final migrated = await migration.migrationIfNeeded(
        disabledStartupConfig().toJson(),
        sync: (data) async => Config.realFromJson(data.configMap),
      );

      expect(migrated.appSettingProps.autoLaunch, true);
      expect(migrated.appSettingProps.silentLaunch, true);
      expect(migrated.appSettingProps.autoRun, true);
      expect(await preferences.getVersion(), 2);
    },
  );

  test('migration v2 preserves later user choices', () async {
    await configurePreferences(2);

    final config = await migration.migrationIfNeeded(
      disabledStartupConfig().toJson(),
      sync: (data) async => Config.realFromJson(data.configMap),
    );

    expect(config.appSettingProps.autoLaunch, false);
    expect(config.appSettingProps.silentLaunch, false);
    expect(config.appSettingProps.autoRun, false);
  });
}
