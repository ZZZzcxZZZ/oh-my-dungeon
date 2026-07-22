import 'package:dnd_table_client/src/features/client_mode/data/client_mode_store.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to player mode', () {
    final controller = ClientModeController();

    expect(controller.mode, ClientMode.player);
  });

  test('notifies listeners when mode changes', () async {
    final controller = ClientModeController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setMode(ClientMode.dungeonMaster);

    expect(controller.mode, ClientMode.dungeonMaster);
    expect(notifications, 1);
  });

  test('does not notify when setting the current mode again', () async {
    final controller = ClientModeController(initialMode: ClientMode.player);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setMode(ClientMode.player);

    expect(notifications, 0);
  });

  test('initialMode allows starting in dungeon master mode', () {
    final controller = ClientModeController(
      initialMode: ClientMode.dungeonMaster,
    );

    expect(controller.mode, ClientMode.dungeonMaster);
  });

  test('persists DM mode and reloads it through the store', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesClientModeStore(preferences);

    final first = ClientModeController.withStore(store: store);
    await first.initialize();
    await first.setMode(ClientMode.dungeonMaster);

    final reloaded = ClientModeController.withStore(store: store);
    await reloaded.initialize();

    expect(reloaded.mode, ClientMode.dungeonMaster);
  });

  test('keeps the previous mode and exposes an error when save fails', () async {
    final store = _ThrowingClientModeStore(ClientMode.player);

    final controller = ClientModeController.withStore(store: store);
    await controller.initialize();
    expect(controller.mode, ClientMode.player);

    Object? caught;
    try {
      await controller.setMode(ClientMode.dungeonMaster);
    } catch (error) {
      caught = error;
    }

    expect(caught, isNotNull);
    expect(controller.mode, ClientMode.player);
    expect(controller.lastError, isNotNull);
  });

  test('load falls back to player mode when no value is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesClientModeStore(preferences);

    expect(await store.load(), ClientMode.player);
  });
}

class _ThrowingClientModeStore implements ClientModeStore {
  _ThrowingClientModeStore(this._mode);

  ClientMode _mode;

  @override
  Future<ClientMode> load() async => _mode;

  @override
  Future<void> save(ClientMode mode) async {
    throw StateError('disk full');
  }
}
