import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/rooms/data/room_api_client.dart';
import 'package:dnd_table_client/src/features/rooms/domain/dice_roller.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room_roll.dart';
import 'package:dnd_table_client/src/features/rooms/presentation/room_home_page.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = ServerProfile(
    id: 'localhost',
    name: 'Local Table',
    baseUrl: 'http://localhost:3000',
    apiBaseUrl: 'http://localhost:3000/api',
    websocketUrl: 'ws://localhost:3000/ws',
    lastKnownVersion: '0.1.0',
  );
  const room = Room(id: 'room-1', name: 'Friday One Shot');

  testWidgets('loads room rolls from the server', (tester) async {
    final roomClient = _FakeRoomClient(
      initialRolls: const [
        RoomRoll(
          id: 'roll-1',
          roomId: 'room-1',
          notation: 'd20',
          total: 8,
          actorName: 'Ada',
          actorMode: 'player',
          createdAt: '2026-07-09T00:00:00.000Z',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoomHomePage(
          profile: profile,
          room: room,
          modeController: ClientModeController(),
          roomClient: roomClient,
          diceRoller: DiceRoller(nextInt: (_) => 19),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada: d20 = 8'), findsOneWidget);
  });

  testWidgets('rolls a d20 from the room detail page', (tester) async {
    final roomClient = _FakeRoomClient();

    await tester.pumpWidget(
      MaterialApp(
        home: RoomHomePage(
          profile: profile,
          room: room,
          modeController: ClientModeController(),
          roomClient: roomClient,
          diceRoller: DiceRoller(nextInt: (_) => 19),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无掷骰记录'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '掷 D20'));
    await tester.pumpAndSettle();

    expect(roomClient.createdRolls, [
      (
        roomId: 'room-1',
        notation: 'd20',
        total: 20,
        actorName: 'Player',
        actorMode: ClientMode.player,
      ),
    ]);
    expect(find.text('Player: d20 = 20'), findsOneWidget);
  });
}

class _FakeRoomClient implements RoomClient {
  _FakeRoomClient({List<RoomRoll> initialRolls = const []})
    : _rolls = [...initialRolls];

  final List<RoomRoll> _rolls;
  final List<
    ({
      String roomId,
      String notation,
      int total,
      String actorName,
      ClientMode actorMode,
    })
  >
  createdRolls = [];

  @override
  Future<List<Room>> listRooms({required String apiBaseUrl}) async {
    return const [];
  }

  @override
  Future<Room> createRoom({
    required String apiBaseUrl,
    required String name,
  }) async {
    return Room(id: 'room-${name.hashCode}', name: name);
  }

  @override
  Future<List<RoomRoll>> listRolls({
    required String apiBaseUrl,
    required String roomId,
  }) async {
    return _rolls
        .where((roll) => roll.roomId == roomId)
        .toList(growable: false);
  }

  @override
  Future<RoomRoll> createRoll({
    required String apiBaseUrl,
    required String roomId,
    required String notation,
    required int total,
    required String actorName,
    required ClientMode actorMode,
  }) async {
    createdRolls.add((
      roomId: roomId,
      notation: notation,
      total: total,
      actorName: actorName,
      actorMode: actorMode,
    ));
    final roll = RoomRoll(
      id: 'roll-${_rolls.length + 1}',
      roomId: roomId,
      notation: notation,
      total: total,
      actorName: actorName,
      actorMode: switch (actorMode) {
        ClientMode.player => 'player',
        ClientMode.dungeonMaster => 'dm',
      },
      createdAt: '2026-07-09T00:00:00.000Z',
    );
    _rolls.insert(0, roll);
    return roll;
  }
}
