import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/encounters/data/encounter_api_client.dart';
import 'package:dnd_table_client/src/features/encounters/domain/encounter.dart';
import 'package:dnd_table_client/src/features/encounters/presentation/encounter_controller.dart';
import 'package:dnd_table_client/src/features/encounters/presentation/encounter_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  Future<AuthController> buildAuth() async {
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      'localhost',
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: _FakeAuthClient(),
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();
    return controller;
  }

  testWidgets(
    'renders active encounter participants with HP controls and turn order',
    (tester) async {
      final auth = await buildAuth();
      final client = _StubEncounterClient();
      final controller = EncounterController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        encounterClient: client,
      );
      controller.setActiveEncounterForTest(_activeEncounter());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(home: EncounterPanelPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('哥布林伏击'), findsOneWidget);
      expect(find.text('Mira'), findsOneWidget);
      expect(find.text('哥布林斥候'), findsOneWidget);
      // HP 显示
      expect(find.textContaining('18/20'), findsOneWidget);
      expect(find.textContaining('7/7'), findsOneWidget);
      // 控制按钮
      expect(find.widgetWithText(FilledButton, '推进回合'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '结束遭遇'), findsOneWidget);
      // HP 调整按钮（每个参与者有伤害和恢复按钮）
      expect(find.byTooltip('受到 1 点伤害'), findsNWidgets(2));
      expect(find.byTooltip('恢复 1 点 HP'), findsNWidgets(2));

      controller.dispose();
      auth.dispose();
    },
  );

  testWidgets('shows empty state when no active encounter', (tester) async {
    final auth = await buildAuth();
    final controller = EncounterController(
      apiBaseUrl: apiBaseUrl,
      authController: auth,
      encounterClient: _StubEncounterClient(),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(home: EncounterPanelPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前没有进行中的遭遇'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新建遭遇'), findsOneWidget);

    controller.dispose();
    auth.dispose();
  });

  testWidgets('tap damage button calls adjustParticipantHp with delta -1',
      (tester) async {
    final auth = await buildAuth();
    final client = _StubEncounterClient();
    final controller = EncounterController(
      apiBaseUrl: apiBaseUrl,
      authController: auth,
      encounterClient: client,
    );
    controller.setActiveEncounterForTest(_activeEncounter());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(home: EncounterPanelPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('受到 1 点伤害').first);
    await tester.pumpAndSettle();

    expect(client.updateParticipantCalls, hasLength(1));
    expect(client.updateParticipantCalls.single['hpCurrent'], 17);

    controller.dispose();
    auth.dispose();
  });

  testWidgets('advance turn button calls controller.advanceTurn',
      (tester) async {
    final auth = await buildAuth();
    final client = _StubEncounterClient();
    final controller = EncounterController(
      apiBaseUrl: apiBaseUrl,
      authController: auth,
      encounterClient: client,
    );
    controller.setActiveEncounterForTest(_activeEncounter());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(home: EncounterPanelPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '推进回合'));
    await tester.pumpAndSettle();

    expect(client.advanceTurnCalls, 1);

    controller.dispose();
    auth.dispose();
  });
}

Encounter _activeEncounter() {
  return Encounter.fromJson(const {
    'id': 'enc-1',
    'campaignId': 'camp-1',
    'sessionId': null,
    'name': '哥布林伏击',
    'status': 'active',
    'round': 1,
    'currentTurnParticipantId': 'p1',
    'createdBy': 'dm-1',
    'createdAt': '2026-07-19T00:00:00.000Z',
    'updatedAt': '2026-07-19T00:00:00.000Z',
    'participants': [
      {
        'id': 'p1',
        'encounterId': 'enc-1',
        'participantType': 'player',
        'characterId': 'char-1',
        'npcId': null,
        'displayName': 'Mira',
        'initiative': 18,
        'hpCurrent': 18,
        'hpMax': 20,
        'armorClass': 16,
        'conditions': null,
        'isHiddenFromPlayers': false,
        'sortOrder': 0,
        'snapshot': null,
        'createdAt': '2026-07-19T00:00:00.000Z',
        'updatedAt': '2026-07-19T00:00:00.000Z',
      },
      {
        'id': 'p2',
        'encounterId': 'enc-1',
        'participantType': 'npc',
        'characterId': null,
        'npcId': 'npc-1',
        'displayName': '哥布林斥候',
        'initiative': 12,
        'hpCurrent': 7,
        'hpMax': 7,
        'armorClass': 13,
        'conditions': null,
        'isHiddenFromPlayers': true,
        'sortOrder': 1,
        'snapshot': null,
        'createdAt': '2026-07-19T00:00:00.000Z',
        'updatedAt': '2026-07-19T00:00:00.000Z',
      },
    ],
  });
}

const _user = AuthUser(
  id: 'user-1',
  username: 'ranger',
  email: 'ranger@example.com',
);

class _FakeAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) async =>
      const AuthSession(
        user: _user,
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async =>
      _user;

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) async =>
      'access-token';

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) async =>
      const RegisterResult(user: _user, isFirstUser: false);

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {}
}

class _StubEncounterClient implements EncounterClient {
  final List<Map<String, Object?>> updateParticipantCalls = [];
  int advanceTurnCalls = 0;
  int startEncounterCalls = 0;
  int endEncounterCalls = 0;

  @override
  Future<Encounter> advanceTurn({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    advanceTurnCalls += 1;
    return _activeEncounter();
  }

  @override
  Future<Encounter> startEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    startEncounterCalls += 1;
    return _activeEncounter();
  }

  @override
  Future<Encounter> endEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    endEncounterCalls += 1;
    return _activeEncounter();
  }

  @override
  Future<EncounterParticipant> updateParticipant({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
    required String participantId,
    int? hpCurrent,
    List<String>? conditions,
  }) async {
    updateParticipantCalls.add({
      'encounterId': encounterId,
      'participantId': participantId,
      'hpCurrent': hpCurrent,
    });
    return EncounterParticipant.fromJson(const {
      'id': 'p1',
      'encounterId': 'enc-1',
      'participantType': 'player',
      'characterId': 'char-1',
      'npcId': null,
      'displayName': 'Mira',
      'initiative': 18,
      'hpCurrent': 17,
      'hpMax': 20,
      'armorClass': 16,
      'conditions': null,
      'isHiddenFromPlayers': false,
      'sortOrder': 0,
      'snapshot': null,
      'createdAt': '2026-07-19T00:00:00.000Z',
      'updatedAt': '2026-07-19T00:00:00.000Z',
    });
  }

  @override
  Future<Encounter> createEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  }) async {
    return _activeEncounter();
  }

  @override
  Future<Encounter> getEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    return _activeEncounter();
  }

  @override
  Future<List<Encounter>> listEncounters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return [_activeEncounter()];
  }

  @override
  Future<Npc> createNpc({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
    Object? stats,
  }) async {
    throw UnimplementedError();
  }
}
