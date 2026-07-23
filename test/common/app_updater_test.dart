import 'package:fl_clash/common/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows update watcher waits, logs, and relaunches', () {
    final script = windowsUpdateWatcherScript();

    expect(script, contains('PID eq %DHQCLASH_UPDATER_PID%'));
    expect(script, contains('"%DHQCLASH_INSTALLER%" /SILENT'));
    expect(script, contains('/NORESTART /RELAUNCH'));
    expect(script, contains(r'/LOG="%TEMP%\DHQClash-update-install.log"'));
    expect(script, contains('del "%~f0"'));
    expect(script, isNot(contains('powershell')));
  });
}
