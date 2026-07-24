import 'package:fl_clash/common/macos_tun.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.dhqclash/macos_tun');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'isAvailable' => true,
            'prepare' => true,
            'start' => true,
            'stop' => true,
            'status' => 'connected',
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('prepares and controls the macOS network extension', () async {
    final tun = MacosTun();
    var notifications = 0;
    tun.addListener(() => notifications++);

    expect(await tun.isAvailable, isTrue);
    expect(await tun.prepare(), isTrue);
    expect(tun.isPrepared, isTrue);
    expect(notifications, 1);
    expect(await tun.start(7890), isTrue);
    expect(await tun.status, MacosTunStatus.connected);
    expect(await tun.stop(), isTrue);

    expect(calls.map((call) => call.method), [
      'isAvailable',
      'prepare',
      'start',
      'status',
      'stop',
    ]);
    expect(calls[2].arguments, {'port': 7890});
  });
}
