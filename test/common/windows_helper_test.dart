import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windowsHelperPathMatches', () {
    const helper = r'C:\Program Files\DHQClash\dhqclash-helper.exe';

    String qc(String binaryPath) =>
        '[SC] QueryServiceConfig SUCCESS\r\n\r\n'
        'SERVICE_NAME: dhqclash-helper\r\n'
        '        TYPE               : 10  WIN32_OWN_PROCESS\r\n'
        '        START_TYPE         : 2   AUTO_START\r\n'
        '        BINARY_PATH_NAME   : $binaryPath\r\n'
        '        DISPLAY_NAME       : dhqclash-helper\r\n';

    test('the service we just installed is ours', () {
      expect(
        windowsHelperPathMatches(exitCode: 0, output: qc(helper), helperPath: helper),
        isTrue,
      );
    });

    test('a helper left behind by the previous install is not', () {
      // The whole point: it answers the health check exactly like ours does.
      expect(
        windowsHelperPathMatches(
          exitCode: 0,
          output: qc(r'C:\Users\me\AppData\Local\DHQClash\old\dhqclash-helper.exe'),
          helperPath: helper,
        ),
        isFalse,
      );
    });

    test('quoting and slashes are not a difference', () {
      expect(
        windowsHelperPathMatches(
          exitCode: 0,
          output: qc('"$helper"'),
          helperPath: helper,
        ),
        isTrue,
      );
      expect(
        windowsHelperPathMatches(
          exitCode: 0,
          output: qc(helper.toUpperCase()),
          helperPath: helper,
        ),
        isTrue,
      );
    });

    test('output we cannot read means "do not know", not "wrong"', () {
      // Unsure must never cost someone a working service.
      for (final unreadable in <String>['', 'что-то другое', '[SC] OpenService FAILED']) {
        expect(
          windowsHelperPathMatches(exitCode: 0, output: unreadable, helperPath: helper),
          isNull,
          reason: unreadable,
        );
      }
      expect(
        windowsHelperPathMatches(exitCode: 1060, output: qc(helper), helperPath: helper),
        isNull,
      );
    });
  });

  group('windowsHelperRegistrationCommand', () {
    test('a stale service is stopped before its path is repointed', () {
      final command = windowsHelperRegistrationCommand(
        currentStatus: WindowsHelperServiceStatus.stale,
        legacyServiceExists: false,
        helperPath: r'C:\new\helper.exe',
      );
      expect(command, contains('sc stop'));
      expect(command, contains('sc config'));
      expect(
        command.indexOf('sc stop'),
        lessThan(command.indexOf('sc config')),
        reason: 'sc config cannot repoint a running service',
      );
    });

    test('an absent service is created rather than reconfigured', () {
      final command = windowsHelperRegistrationCommand(
        currentStatus: WindowsHelperServiceStatus.none,
        legacyServiceExists: false,
        helperPath: r'C:\new\helper.exe',
      );
      expect(command, contains('sc create'));
      expect(command, isNot(contains('sc config')));
    });
  });
}
