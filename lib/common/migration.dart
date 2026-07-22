import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';

class Migration {
  static Migration? _instance;
  late int _oldVersion;

  Migration._internal();

  final currentVersion = 3;

  // Theme defaults shipped before v3 (pre "fruit mix"). Existing clients still
  // on these untouched defaults are moved to the new palette; anyone who picked
  // their own color/palette is left alone.
  static const _legacyPrimaryColor = 0xFFD8C0C3;
  static const _legacyPrimaryColors = [
    0xFF795548,
    0xFF03A9F4,
    0xFFFFFF00,
    0xFFBBC9CC,
    0xFFABD397,
    _legacyPrimaryColor,
    0xFF665390,
  ];

  factory Migration() {
    _instance ??= Migration._internal();
    return _instance!;
  }

  Future<Config> migrationIfNeeded(
    Map<String, Object?>? configMap, {
    required Future<Config> Function(MigrationData data) sync,
  }) async {
    _oldVersion = await preferences.getVersion();
    if (_oldVersion == currentVersion) {
      try {
        return Config.realFromJson(configMap);
      } catch (_) {
        final isV0 = configMap?['proxiesStyle'] != null;
        if (isV0) {
          _oldVersion = 0;
        } else {
          throw 'Local data is damaged. A reset is required to fix this issue.';
        }
      }
    }
    MigrationData data = MigrationData(configMap: configMap);
    if (_oldVersion == 0 && configMap != null) {
      final clashConfigMap = await preferences.getClashConfigMap();
      if (clashConfigMap != null) {
        configMap['patchClashConfig'] = clashConfigMap;
        await preferences.clearClashConfig();
      }
      data = await _oldToNow(configMap);
    }
    if (_oldVersion < 2) {
      data = _enableStartupDefaults(data);
    }
    if (_oldVersion < 3) {
      data = _applyFruitMixTheme(data);
    }
    final res = await sync(data);
    await preferences.setVersion(currentVersion);
    return res;
  }

  Future<MigrationData> _oldToNow(Map<String, Object?> configMap) async {
    return oldToNowTask(configMap);
  }

  MigrationData _enableStartupDefaults(MigrationData data) {
    final configMap = data.configMap;
    if (configMap == null) return data;

    final nextConfigMap = Map<String, Object?>.from(configMap);
    final appSettingProps = Map<String, Object?>.from(
      nextConfigMap['appSettingProps'] as Map? ?? const {},
    );
    appSettingProps.addAll({
      'autoLaunch': true,
      'silentLaunch': true,
      'autoRun': true,
    });
    nextConfigMap['appSettingProps'] = appSettingProps;
    return data.copyWith(configMap: nextConfigMap);
  }

  MigrationData _applyFruitMixTheme(MigrationData data) {
    final configMap = data.configMap;
    if (configMap == null) return data;

    final nextConfigMap = Map<String, Object?>.from(configMap);
    final themeProps = Map<String, Object?>.from(
      nextConfigMap['themeProps'] as Map? ?? const {},
    );

    if (themeProps['primaryColor'] == _legacyPrimaryColor) {
      themeProps['primaryColor'] = defaultPrimaryColor;
    }
    final primaryColors = themeProps['primaryColors'];
    if (primaryColors is List &&
        intListEquality.equals(primaryColors.cast<int>(), _legacyPrimaryColors)) {
      themeProps['primaryColors'] = List<int>.from(defaultPrimaryColors);
    }

    nextConfigMap['themeProps'] = themeProps;
    return data.copyWith(configMap: nextConfigMap);
  }
}

final migration = Migration();
