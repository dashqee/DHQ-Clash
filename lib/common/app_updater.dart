import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

@visibleForTesting
String windowsInstallerArguments({
  required int updaterPid,
  required String logPath,
}) {
  final escapedLogPath = logPath.replaceAll('"', r'\"');
  return '/SILENT /NORESTART /RELAUNCH /UPDATERPID=$updaterPid '
      '/LOG="$escapedLogPath"';
}

@visibleForTesting
({bool requiresAdmin, bool preserveCoreAccess}) macOSUpdateAccessPlan({
  required bool coreHasElevatedAccess,
  required bool appDirectoryIsWritable,
}) {
  final requiresAdmin = !appDirectoryIsWritable;
  return (
    requiresAdmin: requiresAdmin,
    preserveCoreAccess: requiresAdmin && coreHasElevatedAccess,
  );
}

/// (platform, arch) as the /api/app/latest backend expects them, or null on a
/// platform we don't ship self-updates for (iOS, Linux, arm64 Windows).
(String, String)? updatePlatformArch() {
  switch (Abi.current()) {
    case Abi.androidArm64:
      return ('android', 'arm64');
    case Abi.androidArm:
      return ('android', 'arm');
    case Abi.androidX64:
      return ('android', 'x64');
    case Abi.windowsX64:
      return ('windows', 'amd64');
    case Abi.macosArm64:
      return ('macos', 'arm64');
    case Abi.macosX64:
      return ('macos', 'amd64');
    default:
      return null;
  }
}

class AppUpdater {
  static bool get isSupported => updatePlatformArch() != null;

  /// Download the artifact, verify its sha256 (when provided), then hand it to
  /// the OS installer. Returns null on success or a short error string.
  ///
  /// On desktop the install is unattended: the new build is staged while the
  /// app is still running, [onQuit] shuts the core down cleanly, and a detached
  /// watcher relaunches us once the process is gone. [onQuit] is therefore
  /// expected not to return — it ends in `exit()`.
  static Future<String?> downloadAndInstall({
    required String url,
    required String filename,
    required String sha256Hex,
    void Function(double progress)? onProgress,
    Future<void> Function()? onQuit,
  }) async {
    final dir = await getTemporaryDirectory();
    final savePath = p.join(dir.path, filename);
    try {
      await File(savePath).parent.create(recursive: true);
      await request.downloadUpdate(url, savePath, onProgress: onProgress);
    } catch (e) {
      commonPrint.log('update download failed: $e', logLevel: LogLevel.error);
      return currentAppLocalizations.unknownNetworkError;
    }

    if (sha256Hex.isNotEmpty) {
      final actual = await _sha256OfFile(savePath);
      if (actual.toLowerCase() != sha256Hex.toLowerCase()) {
        await File(savePath).delete().catchError((_) => File(savePath));
        commonPrint.log('update sha256 mismatch', logLevel: LogLevel.error);
        return 'checksum mismatch';
      }
    }

    return _install(savePath, dir.path, onQuit);
  }

  static Future<String> _sha256OfFile(String path) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  static Future<String?> _install(
    String path,
    String tempDirPath,
    Future<void> Function()? onQuit,
  ) async {
    try {
      if (Platform.isAndroid) {
        // Android always shows the package installer; a silent self-update is
        // only available to device-owner apps.
        final ok = await app?.installApk(path) ?? false;
        return ok ? null : 'install failed';
      }
      if (Platform.isWindows) {
        return _installWindows(path, tempDirPath, onQuit);
      }
      if (Platform.isMacOS) {
        return _installMacos(path, tempDirPath, onQuit);
      }
    } catch (e) {
      commonPrint.log('update install failed: $e', logLevel: LogLevel.error);
      return 'install failed';
    }
    return 'unsupported platform';
  }

  /// Wrap [value] for use inside a single-quoted POSIX shell word.
  static String _sh(String value) => "'${value.replaceAll("'", "'\\''")}'";

  /// Wrap [command] in `do shell script ... with administrator privileges`,
  /// escaping it for the AppleScript string literal it lands in.
  static List<String> _osascriptAdmin(String command) {
    final escaped = command.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return ['-e', 'do shell script "$escaped" with administrator privileges'];
  }

  /// Spawn a script that outlives us: it waits for pid [pid] to disappear, runs
  /// [body], and is never awaited.
  static Future<void> _spawnWatcher({
    required String scriptPath,
    required String body,
  }) async {
    final script =
        '''
#!/bin/sh
i=0
while /bin/kill -0 $pid 2>/dev/null && [ \$i -lt 600 ]; do
  /bin/sleep 0.2
  i=\$((i+1))
done
$body
''';
    await File(scriptPath).writeAsString(script);
    await Process.start('/bin/sh', [
      scriptPath,
    ], mode: ProcessStartMode.detached);
  }

  /// The `.app` directory the running executable lives in, or null when we are
  /// not running from a bundle at all.
  static String? _macAppBundlePath() {
    var dir = p.dirname(Platform.resolvedExecutable);
    while (dir != p.dirname(dir)) {
      if (dir.endsWith('.app')) return dir;
      dir = p.dirname(dir);
    }
    return null;
  }

  static bool _isWritable(String dirPath) {
    final probe = File(p.join(dirPath, '.dhqclash-write-probe-$pid'));
    try {
      probe.createSync();
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Swap the running `.app` for the one inside the freshly downloaded `.dmg`,
  /// then relaunch — the same shape as Tauri's macOS updater, which is what
  /// Clash Verge uses. The old bundle is *renamed* rather than deleted so the
  /// still-running process keeps its mapped executable and dylibs alive, and
  /// the actual relaunch is done by a detached watcher once we are gone.
  static Future<String?> _installMacos(
    String dmgPath,
    String tempDirPath,
    Future<void> Function()? onQuit,
  ) async {
    final appBundle = _macAppBundlePath();
    // Under App Translocation we run from a randomized read-only copy (this is
    // what happens when the app is launched straight out of the .dmg), so there
    // is no install to replace: fall back to the manual drag-and-drop.
    if (appBundle == null || appBundle.contains('/AppTranslocation/')) {
      await Process.run('open', [dmgPath]);
      return null;
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final mountPoint = p.join(tempDirPath, 'dhqclash-update-mount-$stamp');
    final staging = p.join(tempDirPath, 'dhqclash-update-$stamp.app');
    final backup = p.join(tempDirPath, 'dhqclash-backup-$stamp.app');

    final attach = await Process.run('/usr/bin/hdiutil', [
      'attach',
      dmgPath,
      '-nobrowse',
      '-noautoopen',
      '-readonly',
      '-quiet',
      '-mountpoint',
      mountPoint,
    ]);
    if (attach.exitCode != 0) {
      commonPrint.log(
        'update hdiutil attach failed: ${attach.stderr}',
        logLevel: LogLevel.error,
      );
      return 'install failed';
    }

    String? newApp;
    try {
      // followLinks: false keeps the /Applications drop target the .dmg layout
      // ships out of the way.
      for (final entry in Directory(mountPoint).listSync(followLinks: false)) {
        if (entry is Directory && entry.path.endsWith('.app')) {
          newApp = entry.path;
          break;
        }
      }
      if (newApp != null) {
        final copy = await Process.run('/usr/bin/ditto', [newApp, staging]);
        if (copy.exitCode != 0) {
          commonPrint.log(
            'update ditto failed: ${copy.stderr}',
            logLevel: LogLevel.error,
          );
          newApp = null;
        }
      }
    } finally {
      await Process.run('/usr/bin/hdiutil', [
        'detach',
        mountPoint,
        '-quiet',
        '-force',
      ]);
    }
    if (newApp == null) {
      await Directory(
        staging,
      ).delete(recursive: true).catchError((_) => Directory(staging));
      return 'install failed';
    }

    // We downloaded the .dmg ourselves, so nothing carries a quarantine flag —
    // clear it anyway, because a quarantined bundle would make the relaunch pop
    // Gatekeeper instead of just starting.
    await Process.run('/usr/bin/xattr', [
      '-dr',
      'com.apple.quarantine',
      staging,
    ]);

    // Never show an administrator prompt solely to preserve TUN access. If
    // replacing the app already requires administrator privileges, preserve
    // access in that same operation. Otherwise the new core starts without
    // elevated access and the user can grant it later from Network settings.
    final coreHasElevatedAccess = await system.checkIsAdmin();
    final accessPlan = macOSUpdateAccessPlan(
      coreHasElevatedAccess: coreHasElevatedAccess,
      appDirectoryIsWritable: _isWritable(p.dirname(appBundle)),
    );
    final newCorePath = p.join(appBundle, 'Contents', 'MacOS', 'DHQClashCore');

    final swap = [
      'mv -f ${_sh(appBundle)} ${_sh(backup)}',
      'mv -f ${_sh(staging)} ${_sh(appBundle)}',
      if (accessPlan.preserveCoreAccess) ...[
        'chown root:admin ${_sh(newCorePath)}',
        'chmod +sx ${_sh(newCorePath)}',
      ],
    ].join(' && ');

    final result = accessPlan.requiresAdmin
        ? await Process.run('osascript', _osascriptAdmin(swap))
        : await Process.run('/bin/sh', ['-c', swap]);

    if (result.exitCode != 0) {
      commonPrint.log(
        'update swap failed: ${result.stderr}',
        logLevel: LogLevel.error,
      );
      // Put the old bundle back if we got as far as moving it away, then let
      // the user finish by hand.
      if (!Directory(appBundle).existsSync() &&
          Directory(backup).existsSync()) {
        await Process.run('/bin/mv', ['-f', backup, appBundle]);
      }
      await Directory(
        staging,
      ).delete(recursive: true).catchError((_) => Directory(staging));
      await Process.run('open', [dmgPath]);
      return null;
    }

    await _spawnWatcher(
      scriptPath: p.join(tempDirPath, 'dhqclash-relaunch-$stamp.sh'),
      body:
          '''
/bin/rm -rf ${_sh(backup)} ${_sh(staging)} ${_sh(dmgPath)}
/usr/bin/touch ${_sh(appBundle)}
/usr/bin/open ${_sh(appBundle)}
/bin/rm -f "\$0"
''',
    );

    await _quit(onQuit);
    return null;
  }

  /// Start Inno Setup through ShellExecuteW before shutting down. This keeps the
  /// app visible while Windows shows UAC and lets us report a launch failure
  /// instead of disappearing. Setup receives our PID and waits for the clean
  /// shutdown before replacing files and relaunching the app.
  static Future<String?> _installWindows(
    String installerPath,
    String tempDirPath,
    Future<void> Function()? onQuit,
  ) async {
    final arguments = windowsInstallerArguments(
      updaterPid: pid,
      logPath: p.join(tempDirPath, 'DHQClash-update-install.log'),
    );
    final launched = windows?.runas(installerPath, arguments) ?? false;
    if (!launched) {
      commonPrint.log(
        'update installer launch rejected: $installerPath',
        logLevel: LogLevel.error,
      );
      return 'install failed';
    }
    await _quit(onQuit);
    return null;
  }

  static Future<void> _quit(Future<void> Function()? onQuit) async {
    if (onQuit == null) {
      exit(0);
    }
    await onQuit();
  }
}
