import 'package:shared_preferences/shared_preferences.dart';

import '../domain/client_mode.dart';

/// Persistence layer for [ClientMode].
///
/// Implementations MUST persist the active mode so the user's choice survives
/// app restarts, even when no server is connected.
abstract class ClientModeStore {
  Future<ClientMode> load();
  Future<void> save(ClientMode mode);
}

/// In-memory implementation used by tests and widget harnesses that do not
/// need disk-backed persistence.
class InMemoryClientModeStore implements ClientModeStore {
  InMemoryClientModeStore([ClientMode initial = ClientMode.player])
    : _mode = initial;

  ClientMode _mode;

  @override
  Future<ClientMode> load() async => _mode;

  @override
  Future<void> save(ClientMode mode) async {
    _mode = mode;
  }
}

/// SharedPreferences-backed [ClientModeStore].
class SharedPreferencesClientModeStore implements ClientModeStore {
  const SharedPreferencesClientModeStore(this._preferences);

  final SharedPreferences _preferences;

  static const _key = 'client_mode.value';

  @override
  Future<ClientMode> load() async {
    final value = _preferences.getString(_key);
    return switch (value) {
      'dungeonMaster' => ClientMode.dungeonMaster,
      'player' => ClientMode.player,
      _ => ClientMode.player,
    };
  }

  @override
  Future<void> save(ClientMode mode) async {
    await _preferences.setString(_key, mode.name);
  }
}
