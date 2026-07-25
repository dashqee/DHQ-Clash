import 'dart:async';

import 'package:fl_clash/common/link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses install-config deep link', () {
    final request = parseInstallConfigUri(
      Uri.parse(
        'dhqclash://install-config?'
        'url=https%3A%2F%2Fexample.com%2Fsubscription&name=Office',
      ),
    );

    expect(request?.url, 'https://example.com/subscription');
    expect(request?.name, 'Office');
  });

  test('rejects unrelated and incomplete deep links', () {
    expect(parseInstallConfigUri(Uri.parse('dhqclash://settings')), isNull);
    expect(
      parseInstallConfigUri(Uri.parse('dhqclash://install-config')),
      isNull,
    );
  });

  test('handles the cold-start link and skips its buffered duplicate', () async {
    final initialLink = Completer<Uri?>();
    final links = StreamController<Uri>();
    final manager = LinkManager.test(
      getInitialLink: () => initialLink.future,
      uriLinkStream: links.stream,
    );
    addTearDown(() async {
      manager.destroy();
      await links.close();
    });
    final received = <InstallConfigRequest>[];
    final uri = Uri.parse(
      'dhqclash://install-config?url=https%3A%2F%2Fexample.com%2Fsubscription',
    );

    final initialization = manager.initAppLinksListen(received.add);
    links.add(uri);
    initialLink.complete(uri);
    await initialization;

    expect(received, hasLength(1));
    expect(received.single.url, 'https://example.com/subscription');
  });

  test('handles links received after initialization', () async {
    final links = StreamController<Uri>();
    final manager = LinkManager.test(
      getInitialLink: () async => null,
      uriLinkStream: links.stream,
    );
    addTearDown(() async {
      manager.destroy();
      await links.close();
    });
    final received = <InstallConfigRequest>[];
    await manager.initAppLinksListen(received.add);

    links.add(
      Uri.parse(
        'dhqclash://install-config?url=https%3A%2F%2Fexample.com%2Flater',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(received.single.url, 'https://example.com/later');
  });
}
