import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum MacosTunStatus {
  unavailable,
  disconnected,
  connecting,
  connected,
  disconnecting,
  invalid,
}

class MacosTun extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('app.dhqclash/macos_tun');

  bool _isPrepared = false;

  bool get isPrepared => _isPrepared;

  Future<bool> get isAvailable async {
    return await _channel.invokeMethod<bool>('isAvailable') ?? false;
  }

  Future<bool> prepare() async {
    if (_isPrepared) return true;
    _isPrepared = await _channel.invokeMethod<bool>('prepare') ?? false;
    if (_isPrepared) {
      notifyListeners();
    }
    return _isPrepared;
  }

  Future<bool> start(int port) async {
    return await _channel.invokeMethod<bool>('start', {'port': port}) ?? false;
  }

  Future<bool> stop() async {
    return await _channel.invokeMethod<bool>('stop') ?? false;
  }

  Future<MacosTunStatus> get status async {
    final value = await _channel.invokeMethod<String>('status');
    return MacosTunStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => MacosTunStatus.unavailable,
    );
  }
}

final macosTun = MacosTun();
