import 'package:dnd_table_client/src/app/dnd_table_app.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/rooms/data/room_api_client.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room_roll.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
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

  testWidgets('shows the server profile empty state', (tester) async {
    await tester.pumpWidget(
      DndTableApp(
      serverProfileStore: InMemoryServerProfileStore(),
      authTokenStore: InMemoryAuthTokenStore(),
    ),
    );
    await tester.pumpAndSettle();

    expect(find.text('连接你的跑团服务器'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '添加服务器'), findsOneWidget);
  });

  testWidgets('switches client mode from settings', (tester) async {
    await tester.pumpWidget(
      DndTableApp(
      serverProfileStore: InMemoryServerProfileStore(),
      authTokenStore: InMemoryAuthTokenStore(),
    ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('客户端模式'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('DM'), findsOneWidget);

    await tester.tap(find.text('DM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(find.text('当前模式：DM'), findsOneWidget);
  });

  testWidgets('marks a saved server profile as default', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(DndTableApp(
      serverProfileStore: store,
      authTokenStore: InMemoryAuthTokenStore(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为默认'));
    await tester.pumpAndSettle();

    expect(find.text('默认'), findsOneWidget);
  });

  testWidgets('edits a saved server profile name', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(DndTableApp(
      serverProfileStore: store,
      authTokenStore: InMemoryAuthTokenStore(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑名称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Main Campaign');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('Main Campaign'), findsOneWidget);
    expect(find.text('Local Table'), findsNothing);
  });

  testWidgets('deletes a saved server profile', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(DndTableApp(
      serverProfileStore: store,
      authTokenStore: InMemoryAuthTokenStore(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.text('Local Table'), findsNothing);
    expect(find.text('连接你的跑团服务器'), findsOneWidget);
  });

  testWidgets('opens a saved server profile home page', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    final roomClient = _FakeRoomClient(
      initialRooms: const [Room(id: 'room-1', name: 'Friday One Shot')],
    );

    await tester.pumpWidget(
      DndTableApp(
      serverProfileStore: store,
      authTokenStore: InMemoryAuthTokenStore(),
      roomClient: roomClient,
    ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    expect(find.text('Local Table'), findsAtLeastNWidgets(1));
    expect(find.text('http://localhost:3000'), findsOneWidget);
    expect(find.text('当前模式：Player'), findsOneWidget);
    expect(find.text('房间与登录入口'), findsOneWidget);
    expect(find.text('等待房间开放'), findsOneWidget);
    expect(find.text('创建房间'), findsNothing);
    expect(find.text('Friday One Shot'), findsOneWidget);
  });

  testWidgets('shows create room entry in dm mode', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(DndTableApp(
      serverProfileStore: store,
      authTokenStore: InMemoryAuthTokenStore(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    expect(find.text('当前模式：DM'), findsOneWidget);
    expect(find.text('创建房间'), findsOneWidget);
    expect(find.text('等待房间开放'), findsNothing);
  });

  testWidgets('creates a room from the dm home page', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    final roomClient = _FakeRoomClient();

    await tester.pumpWidget(
      DndTableApp(
      serverProfileStore: store,
      authTokenStore: InMemoryAuthTokenStore(),
      roomClient: roomClient,
    ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建房间'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Friday One Shot');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(roomClient.createdRoomNames, ['Friday One Shot']);
    expect(find.text('Friday One Shot'), findsOneWidget);
  });

  testWidgets('opens a room detail page from the room list', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    final roomClient = _FakeRoomClient(
      initialRooms: const [Room(id: 'room-1', name: 'Friday One Shot')],
    );

    await tester.pumpWidget(
      DndTableApp(
      serverProfileStore: store,
      authTokenStore: InMemoryAuthTokenStore(),
      roomClient: roomClient,
    ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Friday One Shot'));
    await tester.pumpAndSettle();

    expect(find.text('Friday One Shot'), findsAtLeastNWidgets(1));
    expect(find.text('Local Table'), findsAtLeastNWidgets(1));
    expect(find.text('当前模式：Player'), findsOneWidget);
    expect(find.text('角色与跑团工具'), findsOneWidget);
    expect(find.text('角色卡'), findsOneWidget);
    expect(find.text('掷骰'), findsOneWidget);
  });
}

class _FakeRoomClient implements RoomClient {
  _FakeRoomClient({List<Room> initialRooms = const []})
    : _rooms = [...initialRooms];

  final List<Room> _rooms;
  final List<RoomRoll> _rolls = [];
  final List<String> createdRoomNames = [];

  @override
  Future<List<Room>> listRooms({required String apiBaseUrl}) async {
    return List.unmodifiable(_rooms);
  }

  @override
  Future<Room> createRoom({
    required String apiBaseUrl,
    required String name,
  }) async {
    createdRoomNames.add(name);
    final room = Room(id: 'room-${createdRoomNames.length}', name: name);
    _rooms.add(room);
    return room;
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
    _rolls.add(roll);
    return roll;
  }
}
