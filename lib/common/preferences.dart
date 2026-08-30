import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

class Preferences {
  static Preferences? _instance;
  static const _macOSHelperAutoInstallAttemptKey =
      'macOSHelperAutoInstallAttempt';

  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  Future<bool> get isInit async =>
      await sharedPreferencesCompleter.future != null;

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => _completeOnce(value))
        .onError((_, _) => _completeOnce(null));
  }

  void _completeOnce(SharedPreferences? value) {
    if (!sharedPreferencesCompleter.isCompleted) {
      sharedPreferencesCompleter.complete(value);
    }
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<int> getVersion() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getInt('version') ?? 0;
  }

  Future<void> setVersion(int version) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setInt('version', version);
  }

  /// One automatic helper install attempt per platform per release.
  ///
  /// Both desktop platforms need an elevation prompt to (re)install their
  /// helper, and both only need it once after an update. Asking on every start
  /// teaches people to dismiss the prompt, which is worse than not asking.
  Future<bool> claimHelperInstallAttempt({
    required String platform,
    required String releaseId,
    bool force = false,
  }) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (force) {
      return true;
    }
    // The macOS key predates this and is kept as-is so an update does not hand
    // existing installs a second prompt they already answered.
    final key = platform == 'macos'
        ? _macOSHelperAutoInstallAttemptKey
        : '${_macOSHelperAutoInstallAttemptKey}_$platform';
    if (preferences?.getString(key) == releaseId) {
      return false;
    }
    await preferences?.setString(key, releaseId);
    return true;
  }

  Future<bool> claimMacOSHelperInstallAttempt({
    required String releaseId,
    bool force = false,
  }) => claimHelperInstallAttempt(
    platform: 'macos',
    releaseId: releaseId,
    force: force,
  );

  Future<void> saveShareState(SharedState shareState) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setString('sharedState', json.encode(shareState));
  }

  Future<Map<String, Object?>?> getConfigMap() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      final configString = preferences?.getString(configKey);
      if (configString == null) return null;
      final Map<String, Object?>? configMap = json.decode(configString);
      return configMap;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> getClashConfigMap() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      final clashConfigString = preferences?.getString(clashConfigKey);
      if (clashConfigString == null) return null;
      return json.decode(clashConfigString);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearClashConfig() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      await preferences?.remove(clashConfigKey);
      return;
    } catch (_) {
      return;
    }
  }

  Future<Config?> getConfig() async {
    final configMap = await getConfigMap();
    if (configMap == null) {
      return null;
    }
    return Config.fromJson(configMap);
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.setString(configKey, json.encode(config)) ?? false;
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    await sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
