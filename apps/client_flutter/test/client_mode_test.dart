import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
