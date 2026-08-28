import 'package:fl_clash/views/dashboard/widgets/start_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('needsTunToStart', () {
    test('blocks a desktop start while TUN is off', () {
      // The core still runs without TUN, but nothing is routed through it and
      // the button looks identical to a working tunnel.
      expect(
        needsTunToStart(
          isStarting: true,
          isDesktop: true,
          tunEnabled: false,
        ),
        isTrue,
      );
    });

    test('never blocks off desktop', () {
      // On Android the tunnel is the system VpnService and tun.enable is not
      // the switch anybody sees; guarding on it would block start for good.
      expect(
        needsTunToStart(
          isStarting: true,
          isDesktop: false,
          tunEnabled: false,
        ),
        isFalse,
      );
    });

    test('does not block once TUN is on', () {
      expect(
        needsTunToStart(
          isStarting: true,
          isDesktop: true,
          tunEnabled: true,
        ),
        isFalse,
      );
    });

    test('never blocks stopping', () {
      // Turning protection off must always work, whatever TUN is set to.
      expect(
        needsTunToStart(
          isStarting: false,
          isDesktop: true,
          tunEnabled: false,
        ),
        isFalse,
      );
    });
  });
}
