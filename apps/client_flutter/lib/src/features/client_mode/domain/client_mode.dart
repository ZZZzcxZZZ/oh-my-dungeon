import 'package:flutter/foundation.dart';

enum ClientMode {
  player,
  dungeonMaster;

  String get label {
    return switch (this) {
      ClientMode.player => 'Player',
      ClientMode.dungeonMaster => 'DM',
    };
  }
}

class ClientModeController extends ChangeNotifier {
  ClientModeController({ClientMode initialMode = ClientMode.player})
    : _mode = initialMode;

  ClientMode _mode;

  ClientMode get mode => _mode;

  Future<void> setMode(ClientMode mode) async {
    if (_mode == mode) return;

    _mode = mode;
    notifyListeners();
  }
}
