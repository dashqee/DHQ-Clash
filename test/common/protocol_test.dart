import 'package:fl_clash/common/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ProtocolRegistrationPlan', () {
    test('builds registry writes for URL protocol registration', () {
      const plan = ProtocolRegistrationPlan(
        scheme: 'dhqclash',
        executable: r'C:\Program Files\DHQClash\DHQClash.exe',
      );

      expect(plan.protocolKey, r'Software\Classes\dhqclash');
      expect(plan.commandKey, r'shell\open\command');
      expect(plan.protocolValueName, 'URL Protocol');
      expect(plan.protocolValue, '');
      expect(plan.command, r'"C:\Program Files\DHQClash\DHQClash.exe" "%1"');
    });
  });
}
