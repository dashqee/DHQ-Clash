import 'package:fl_clash/common/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a checksummed Windows installer from the update API', () {
    final sha256Hex = List.filled(64, 'a').join();
    expect(
      isTrustedUpdateArtifact(
        url:
            'https://api.dhqclash.app/api/app/download/'
            'DHQClash-1.1.10-beta.1-windows-amd64-setup.exe',
        filename: 'DHQClash-1.1.10-beta.1-windows-amd64-setup.exe',
        sha256Hex: sha256Hex,
        platform: 'windows',
        arch: 'amd64',
      ),
      isTrue,
    );
  });

  test('rejects an unrelated executable and missing checksum', () {
    expect(
      isTrustedUpdateArtifact(
        url: 'https://api.dhqclash.app/api/app/download/HardwareTester.exe',
        filename: 'HardwareTester.exe',
        sha256Hex: '',
        platform: 'windows',
        arch: 'amd64',
      ),
      isFalse,
    );
  });

  test('rejects update artifacts from another host or a nested filename', () {
    const filename = 'DHQClash-1.1.10-windows-amd64-setup.exe';
    final sha256Hex = List.filled(64, 'b').join();
    expect(
      isTrustedUpdateArtifact(
        url: 'https://example.com/api/app/download/$filename',
        filename: filename,
        sha256Hex: sha256Hex,
        platform: 'windows',
        arch: 'amd64',
      ),
      isFalse,
    );
    expect(
      isTrustedUpdateArtifact(
        url: 'https://api.dhqclash.app/api/app/download/$filename',
        filename: '../$filename',
        sha256Hex: sha256Hex,
        platform: 'windows',
        arch: 'amd64',
      ),
      isFalse,
    );
    expect(
      isTrustedUpdateArtifact(
        url: 'https://api.dhqclash.app/api/app/download/$filename',
        filename: filename,
        sha256Hex: sha256Hex,
        platform: 'windows',
        arch: 'arm64',
      ),
      isFalse,
    );
  });

  test('Windows installer waits for the updater, logs, and relaunches', () {
    final arguments = windowsInstallerArguments(
      updaterPid: 4242,
      logPath: r'C:\Users\Test User\AppData\Local\Temp\install.log',
    );

    expect(arguments, startsWith('/SILENT'));
    expect(arguments, contains('/NORESTART /RELAUNCH'));
    expect(arguments, contains('/UPDATERPID=4242'));
    expect(
      arguments,
      contains(r'/LOG="C:\Users\Test User\AppData\Local\Temp\install.log"'),
    );
  });

  test(
    'macOS writable update does not request admin for existing TUN access',
    () {
      final plan = macOSUpdateAccessPlan(
        coreHasElevatedAccess: true,
        appDirectoryIsWritable: true,
      );

      expect(plan.requiresAdmin, isFalse);
      expect(plan.preserveCoreAccess, isFalse);
    },
  );

  test('macOS privileged update preserves existing TUN access', () {
    final plan = macOSUpdateAccessPlan(
      coreHasElevatedAccess: true,
      appDirectoryIsWritable: false,
    );

    expect(plan.requiresAdmin, isTrue);
    expect(plan.preserveCoreAccess, isTrue);
  });

  test('macOS update does not install TUN access when it was absent', () {
    final plan = macOSUpdateAccessPlan(
      coreHasElevatedAccess: false,
      appDirectoryIsWritable: false,
    );

    expect(plan.requiresAdmin, isTrue);
    expect(plan.preserveCoreAccess, isFalse);
  });
}
