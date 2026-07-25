import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../enum/enum.dart';
import 'print.dart';

/// A parsed `scheme://install-config` deep link.
/// `name` becomes the profile label.
class InstallConfigRequest {
  final String url;
  final String name;

  const InstallConfigRequest({required this.url, this.name = ''});
}

typedef InstallConfigCallBack =
    FutureOr<void> Function(InstallConfigRequest request);
typedef InitialLinkGetter = Future<Uri?> Function();

InstallConfigRequest? parseInstallConfigUri(Uri uri) {
  if (uri.host != 'install-config') return null;
  final url = uri.queryParameters['url'];
  if (url == null || url.isEmpty) return null;
  return InstallConfigRequest(
    url: url,
    name: uri.queryParameters['name'] ?? '',
  );
}

class LinkManager {
  static LinkManager? _instance;
  final InitialLinkGetter _getInitialLink;
  final Stream<Uri> _uriLinkStream;
  StreamSubscription<Uri>? subscription;

  LinkManager._internal()
    : _getInitialLink = AppLinks().getInitialLink,
      _uriLinkStream = AppLinks().uriLinkStream;

  @visibleForTesting
  LinkManager.test({
    required InitialLinkGetter getInitialLink,
    required Stream<Uri> uriLinkStream,
  }) : _getInitialLink = getInitialLink,
       _uriLinkStream = uriLinkStream;

  Future<void> initAppLinksListen(
    InstallConfigCallBack installConfigCallBack,
  ) async {
    commonPrint.log('initAppLinksListen');
    destroy();
    final pendingLinks = <Uri>[];
    var initialLinkLoaded = false;
    subscription = _uriLinkStream.listen(
      (uri) {
        if (!initialLinkLoaded) {
          pendingLinks.add(uri);
          return;
        }
        unawaited(_handleUri(uri, installConfigCallBack));
      },
      onError: (Object error, StackTrace stackTrace) {
        commonPrint.log(
          'app link stream error: $error',
          logLevel: LogLevel.warning,
        );
      },
    );

    Uri? initialLink;
    try {
      initialLink = await _getInitialLink();
      if (initialLink != null) {
        await _handleUri(initialLink, installConfigCallBack);
      }
    } catch (error) {
      commonPrint.log(
        'initial app link error: $error',
        logLevel: LogLevel.warning,
      );
    }

    initialLinkLoaded = true;
    var skippedInitialDuplicate = false;
    for (final uri in pendingLinks) {
      if (!skippedInitialDuplicate && uri == initialLink) {
        skippedInitialDuplicate = true;
        continue;
      }
      await _handleUri(uri, installConfigCallBack);
    }
  }

  Future<void> _handleUri(
    Uri uri,
    InstallConfigCallBack installConfigCallBack,
  ) async {
    commonPrint.log('onAppLink: $uri');
    final request = parseInstallConfigUri(uri);
    if (request == null) return;
    await installConfigCallBack(request);
  }

  void destroy() {
    if (subscription != null) {
      subscription?.cancel();
      subscription = null;
    }
  }

  factory LinkManager() {
    _instance ??= LinkManager._internal();
    return _instance!;
  }
}

final linkManager = LinkManager();
