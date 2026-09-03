import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';

class Migration {
  static Migration? _instance;
  late int _oldVersion;

  Migration._internal();

  final currentVersion = 6;

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
    if (_oldVersion < 4) {
      data = _useListProxiesStyle(data);
    }
    if (_oldVersion < 5) {
      data = _enableTunnelDefaults(data);
    }
    if (_oldVersion < 6) {
      data = _enableAutoCheckUpdate(data);
    }
    final res = await sync(data);
    await preferences.setVersion(currentVersion);
    return res;
  }

  /// Turn the automatic update check back on for everyone, once.
  ///
  /// The old update dialog's "don't remind again" switched the check off for
  /// good, so a good share of installs stopped hearing about releases after
  /// the first prompt. The dialog no longer has that button; this gives those
  /// installs the check back. Switching it off again in Settings still sticks.
  MigrationData _enableAutoCheckUpdate(MigrationData data) {
    final configMap = data.configMap;
    if (configMap == null) return data;

    final nextConfigMap = Map<String, Object?>.from(configMap);
    final appSettingProps = Map<String, Object?>.from(
      nextConfigMap['appSettingProps'] as Map? ?? const {},
    );
    appSettingProps['autoCheckUpdate'] = true;
    nextConfigMap['appSettingProps'] = appSettingProps;
    return data.copyWith(configMap: nextConfigMap);
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

  /// Switch existing clients to the list view of Proxies.
  ///
  /// The default became `list` for fresh installs, but everyone already using
  /// the app has `tab` written into their config and would never see the
  /// change. Only `type` is touched: sort order, layout, icon style and card
  /// size may have been set deliberately, and changing the view is no reason to
  /// reset them.
  MigrationData _useListProxiesStyle(MigrationData data) {
    final configMap = data.configMap;
    if (configMap == null) return data;

    final nextConfigMap = Map<String, Object?>.from(configMap);
    final proxiesStyleProps = Map<String, Object?>.from(
      nextConfigMap['proxiesStyleProps'] as Map? ?? const {},
    );
    proxiesStyleProps['type'] = 'list';
    nextConfigMap['proxiesStyleProps'] = proxiesStyleProps;
    return data.copyWith(configMap: nextConfigMap);
  }

  /// Turn TUN (desktop) and the VPN service (Android) on once for everyone.
  ///
  /// Both defaults became true, but every existing client has `false` written
  /// into its config and would never see it. This is a one-time switch: the
  /// toggles stay in the UI, and turning them off again is kept.
  MigrationData _enableTunnelDefaults(MigrationData data) {
    final configMap = data.configMap;
    if (configMap == null) return data;

    final nextConfigMap = Map<String, Object?>.from(configMap);
    final patchClashConfig = Map<String, Object?>.from(
      nextConfigMap['patchClashConfig'] as Map? ?? const {},
    );
    final tun = Map<String, Object?>.from(
      patchClashConfig['tun'] as Map? ?? const {},
    );
    tun['enable'] = true;
    patchClashConfig['tun'] = tun;
    nextConfigMap['patchClashConfig'] = patchClashConfig;

    final vpnProps = Map<String, Object?>.from(
      nextConfigMap['vpnProps'] as Map? ?? const {},
    );
    vpnProps['enable'] = true;
    nextConfigMap['vpnProps'] = vpnProps;
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
        intListEquality.equals(
          primaryColors.cast<int>(),
          _legacyPrimaryColors,
        )) {
      themeProps['primaryColors'] = List<int>.from(defaultPrimaryColors);
    }

    nextConfigMap['themeProps'] = themeProps;
    return data.copyWith(configMap: nextConfigMap);
  }
}

final migration = Migration();
