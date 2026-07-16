import 'dart:async';

import 'package:app_links/app_links.dart';

import 'print.dart';

/// A parsed <scheme>://install-config deep link.
/// `name` becomes the profile label; `autoConnect` asks the app to select the
/// imported profile and start the VPN without further taps.
class InstallConfigRequest {
  final String url;
  final String name;
  final bool autoConnect;

  const InstallConfigRequest({
    required this.url,
    this.name = '',
    this.autoConnect = false,
  });
}

typedef InstallConfigCallBack = void Function(InstallConfigRequest request);

class LinkManager {
  static LinkManager? _instance;
  late AppLinks _appLinks;
  StreamSubscription? subscription;

  LinkManager._internal() {
    _appLinks = AppLinks();
  }

  Future<void> initAppLinksListen(
    InstallConfigCallBack installConfigCallBack,
  ) async {
    commonPrint.log('initAppLinksListen');
    destroy();
    subscription = _appLinks.uriLinkStream.listen((uri) {
      commonPrint.log('onAppLink: $uri');
      if (uri.host == 'install-config') {
        final parameters = uri.queryParameters;
        final url = parameters['url'];
        if (url != null) {
          final auto = parameters['autoconnect'];
          installConfigCallBack(
            InstallConfigRequest(
              url: url,
              name: parameters['name'] ?? '',
              autoConnect: auto == '1' || auto == 'true',
            ),
          );
        }
      }
    });
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
