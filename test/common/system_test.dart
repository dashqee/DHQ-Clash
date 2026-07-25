import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windowsHelperRegistrationCommand', () {
    test('removes the pre-1.1.5 service before registering the helper', () {
      const helperPath = r'C:\Program Files\DHQClash\helper.exe';
      final command = windowsHelperRegistrationCommand(
        currentStatus: WindowsHelperServiceStatus.none,
        legacyServiceExists: true,
        helperPath: helperPath,
      );

      expect(command, startsWith('/c '));
      expect(command, contains('taskkill /F /IM'));
      expect(command, contains('sc delete'));
      expect(command, contains(helperPath));
      expect(command, contains('sc create "$appHelperService"'));
      expect(command, endsWith('sc start "$appHelperService"'));
    });

    test('replaces a broken current helper service', () {
      final command = windowsHelperRegistrationCommand(
        currentStatus: WindowsHelperServiceStatus.presence,
        legacyServiceExists: false,
        helperPath: r'C:\DHQClash\helper.exe',
      );

      expect(command, contains('sc stop "$appHelperService"'));
      expect(command, isNot(contains('sc delete "$appHelperService"')));
      expect(command, contains('sc config "$appHelperService"'));
      expect(command, endsWith('&& sc start "$appHelperService"'));
    });

    test('creates the helper when the current service does not exist', () {
      final command = windowsHelperRegistrationCommand(
        currentStatus: WindowsHelperServiceStatus.none,
        legacyServiceExists: false,
        helperPath: r'C:\DHQClash\helper.exe',
      );

      expect(command, contains('sc create "$appHelperService"'));
      expect(command, isNot(contains('sc config "$appHelperService"')));
    });
  });
}
