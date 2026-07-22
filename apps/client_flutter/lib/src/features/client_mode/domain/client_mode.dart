import 'package:flutter/foundation.dart';

import '../data/client_mode_store.dart';

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
    : _mode = initialMode,
      _store = null;

  /// Persistent variant. When [store] is supplied, [initialize] loads the
  /// saved mode and [setMode] persists each change before publishing it.
  /// If persistence fails, the previous mode is kept and [lastError] is set.
  ClientModeController.withStore({required ClientModeStore store})
    : _mode = ClientMode.player,
      _store = store;

  ClientMode _mode;
  final ClientModeStore? _store;
  Object? _lastError;

  ClientMode get mode => _mode;
  Object? get lastError => _lastError;
  bool get hasStore => _store != null;

  Future<void> initialize() async {
    final store = _store;
    if (store == null) return;
    try {
      _mode = await store.load();
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      notifyListeners();
    }
  }

  Future<void> setMode(ClientMode mode) async {
    if (_mode == mode) return;

    final store = _store;
    if (store == null) {
      _mode = mode;
      notifyListeners();
      return;
    }

    final previous = _mode;
    try {
      await store.save(mode);
      _mode = mode;
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _mode = previous;
      _lastError = error;
      notifyListeners();
      throw error;
    }
  }

  /// Clears [lastError] once the UI has surfaced it to the user.
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }
}
