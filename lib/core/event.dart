import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

abstract mixin class CoreEventListener {
  void onLog(Log log) {}

  void onDelay(Delay delay) {}

  void onRequest(TrackerInfo connection) {}

  void onLoaded(String providerName) {}

  void onCrash(String message) {}

  /// The tunnel went down under a core that is still alive (Android's
  /// VpnService was revoked or refused). Distinct from a crash so the core is
  /// not torn down along with it.
  void onTunnelDown(String message) {}

  void onGeoUpdate(
    String geoType,
    bool updating,
    bool skipped,
    String? error,
  ) {}
}

class CoreEventManager {
  final _controller = StreamController<CoreEvent>();

  CoreEventManager._() {
    _controller.stream.listen((event) {
      for (final CoreEventListener listener in _listeners) {
        switch (event.type) {
          case CoreEventType.log:
            listener.onLog(Log.fromJson(event.data));
            break;
          case CoreEventType.delay:
            listener.onDelay(Delay.fromJson(event.data));
            break;
          case CoreEventType.request:
            listener.onRequest(TrackerInfo.fromJson(event.data));
            break;
          case CoreEventType.loaded:
            listener.onLoaded(event.data);
            break;
          case CoreEventType.crash:
            listener.onCrash(event.data);
            break;
          case CoreEventType.tunnelDown:
            listener.onTunnelDown(event.data?.toString() ?? '');
            break;
          case CoreEventType.geoUpdate:
            final data = event.data as Map<String, dynamic>;
            listener.onGeoUpdate(
              data['type'] as String,
              data['updating'] as bool,
              data['skipped'] as bool? ?? false,
              data['error'] as String?,
            );
            break;
        }
      }
    });
  }

  static final CoreEventManager instance = CoreEventManager._();

  final ObserverList<CoreEventListener> _listeners =
      ObserverList<CoreEventListener>();

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void sendEvent(CoreEvent event) {
    _controller.add(event);
  }

  void addListener(CoreEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CoreEventListener listener) {
    _listeners.remove(listener);
  }
}

final coreEventManager = CoreEventManager.instance;
