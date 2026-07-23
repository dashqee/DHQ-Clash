import 'package:fl_clash/common/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
