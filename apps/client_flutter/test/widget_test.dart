import 'package:dnd_table_client/src/app/dnd_table_app.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/encounters/data/encounter_api_client.dart';
import 'package:dnd_table_client/src/features/encounters/domain/encounter.dart';
import 'package:dnd_table_client/src/features/rooms/data/room_api_client.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room_roll.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:dnd_table_client/src/features/sessions/data/session_api_client.dart';
import 'package:dnd_table_client/src/features/sessions/domain/session.dart';
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

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
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

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
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

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
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

  testWidgets('opens a saved server profile and shows campaign tab', (
    tester,
  ) async {
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

    // Default tab is 战役 (campaigns). Not logged in -> login prompt.
    expect(find.text('战役'), findsWidgets);
    expect(find.text('登录后管理战役'), findsOneWidget);

    // Settings tab shows server info and mode.
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('Local Table'), findsOneWidget);
    expect(find.text('http://localhost:3000'), findsOneWidget);
    expect(find.text('当前模式：Player'), findsOneWidget);
    expect(find.text('未登录'), findsOneWidget);
  });

  testWidgets('switches to dm mode from settings tab', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DM'));
    await tester.pumpAndSettle();

    expect(find.text('当前模式：DM'), findsOneWidget);
  });

  testWidgets('shows login prompt on table tab when not authenticated', (
    tester,
  ) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('桌面'));
    await tester.pumpAndSettle();

    expect(find.text('登录后进入桌面'), findsOneWidget);
  });

  testWidgets('shows a characters tab in the main shell', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsWidgets);

    await tester.tap(find.text('角色').last);
    await tester.pumpAndSettle();

    expect(find.text('登录后管理角色'), findsOneWidget);
  });

  testWidgets('shows a content library tab in the main shell', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    expect(find.text('资料库'), findsOneWidget);

    await tester.tap(find.text('资料库'));
    await tester.pumpAndSettle();

    expect(find.text('登录后查看资料库'), findsOneWidget);
  });
  testWidgets('shows dm encounter control on table tab', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final modeController = ClientModeController();
    await modeController.setMode(ClientMode.dungeonMaster);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        sessionClient: _FakeSessionClient(),
        encounterClient: _FakeEncounterClient(),
        modeController: modeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Table'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.table_restaurant_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('控场'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('encounter-control-panel')), findsOneWidget);
    expect(find.text('Road Ambush'), findsOneWidget);
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

class _FakeAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {}

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const AuthUser(
      id: 'user-1',
      username: 'dm',
      email: 'dm@example.com',
    );
  }

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }
}

class _FakeCampaignClient implements CampaignClient {
  @override
  Future<Campaign> createCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    String? description,
    String? system,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Campaign> getCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return _campaign;
  }

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const [_campaign];
  }

  @override
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? roleOnJoin,
    int? maxUses,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CampaignMembership> joinCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String code,
  }) {
    throw UnimplementedError();
  }
}

class _FakeSessionClient implements SessionClient {
  @override
  Future<Session> createSession({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Session>> listSessions({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return const [];
  }

  @override
  Future<Session> getSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Session> startSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Session> endSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String content,
    String? kind,
    String? visibility,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<DiceRoll>> listRolls({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<DiceRoll> createRoll({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String notation,
    required String actorName,
    String? visibility,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<JournalEntry>> listJournal({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }
}

class _FakeEncounterClient implements EncounterClient {
  @override
  Future<List<Encounter>> listEncounters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return const [_encounter];
  }

  @override
  Future<Encounter> getEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    return _encounter;
  }

  @override
  Future<Npc> createNpc({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
    Object? stats,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Encounter> createEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Encounter> startEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Encounter> advanceTurn({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Encounter> endEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EncounterParticipant> updateParticipant({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
    required String participantId,
    int? hpCurrent,
    List<String>? conditions,
  }) {
    throw UnimplementedError();
  }
}

const _campaign = Campaign(
  id: 'camp-1',
  name: 'Starter Campaign',
  description: '',
  system: 'dnd5e',
  ownerId: 'user-1',
  status: 'active',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _encounter = Encounter(
  id: 'enc-1',
  campaignId: 'camp-1',
  sessionId: null,
  name: 'Road Ambush',
  status: 'draft',
  round: 0,
  currentTurnParticipantId: null,
  createdBy: 'user-1',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  participants: [
    EncounterParticipant(
      id: 'part-1',
      encounterId: 'enc-1',
      participantType: 'npc',
      characterId: null,
      npcId: 'npc-1',
      displayName: 'Road Bandit',
      initiative: 12,
      hpCurrent: 7,
      hpMax: 7,
      armorClass: 13,
      conditions: [],
      isHiddenFromPlayers: false,
      sortOrder: 0,
      snapshot: {},
      createdAt: '2026-07-09T00:00:00.000Z',
      updatedAt: '2026-07-09T00:00:00.000Z',
    ),
  ],
);
