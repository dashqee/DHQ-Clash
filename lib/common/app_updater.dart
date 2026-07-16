import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:path_provider/path_provider.dart';

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
  static Future<String?> downloadAndInstall({
    required String url,
    required String filename,
    required String sha256Hex,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/$filename';
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

    return _install(savePath);
  }

  static Future<String> _sha256OfFile(String path) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  static Future<String?> _install(String path) async {
    try {
      if (Platform.isAndroid) {
        final ok = await app?.installApk(path) ?? false;
        return ok ? null : 'install failed';
      }
      if (Platform.isWindows) {
        // Inno Setup silent install; the running app must exit so the installer
        // can replace its files, and the installer relaunches it.
        await Process.start(
          path,
          ['/SILENT', '/NORESTART', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
          mode: ProcessStartMode.detached,
        );
        exit(0);
      }
      if (Platform.isMacOS) {
        // No Developer ID signing yet — just open the .dmg and let the user
        // drag the app over; a silent in-place swap would trip Gatekeeper.
        await Process.run('open', [path]);
        return null;
      }
    } catch (e) {
      commonPrint.log('update install failed: $e', logLevel: LogLevel.error);
      return 'install failed';
    }
    return 'unsupported platform';
  }
}
