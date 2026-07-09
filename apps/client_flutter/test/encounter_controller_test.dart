import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/encounters/data/encounter_api_client.dart';
import 'package:dnd_table_client/src/features/encounters/domain/encounter.dart';
import 'package:dnd_table_client/src/features/encounters/presentation/encounter_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  Future<AuthController> buildLoggedInAuthController() async {
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

  test('loads encounters for a campaign', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeEncounterClient(encounters: [_encounter]);
    final controller = EncounterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      encounterClient: client,
    );

    await controller.loadEncounters('camp-1');

    expect(controller.encounters, [_encounter]);
    expect(client.listCalls, ['camp-1']);

    controller.dispose();
    authController.dispose();
  });

  test('adjusts participant hp and updates active encounter', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeEncounterClient(encounters: [_encounter]);
    final controller = EncounterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      encounterClient: client,
    );
    await controller.loadEncounter('enc-1');

    final ok = await controller.adjustParticipantHp(
      encounterId: 'enc-1',
      participantId: 'part-1',
      delta: -4,
    );

    expect(ok, isTrue);
    expect(controller.activeEncounter?.participants.single.hpCurrent, 3);

    controller.dispose();
    authController.dispose();
  });

  test('starts, advances, and ends the active encounter', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeEncounterClient(encounters: [_encounter]);
    final controller = EncounterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      encounterClient: client,
    );
    await controller.loadEncounter('enc-1');

    expect(await controller.startEncounter(), isTrue);
    expect(controller.activeEncounter?.status, 'active');

    expect(await controller.advanceTurn(), isTrue);
    expect(controller.activeEncounter?.round, 1);

    expect(await controller.endEncounter(), isTrue);
    expect(controller.activeEncounter?.status, 'ended');

    controller.dispose();
    authController.dispose();
  });
}

const _participant = EncounterParticipant(
  id: 'part-1',
  encounterId: 'enc-1',
  participantType: 'npc',
  characterId: null,
  npcId: 'npc-1',
  displayName: 'Goblin Scout',
  initiative: 12,
  hpCurrent: 7,
  hpMax: 7,
  armorClass: 15,
  conditions: [],
  isHiddenFromPlayers: false,
  sortOrder: 0,
  snapshot: {},
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
  participants: [_participant],
);

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

class _FakeEncounterClient implements EncounterClient {
  _FakeEncounterClient({this.encounters = const []});

  final List<Encounter> encounters;
  final List<String> listCalls = [];

  @override
  Future<List<Encounter>> listEncounters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    listCalls.add(campaignId);
    return encounters;
  }

  @override
  Future<Encounter> getEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    return encounters.single;
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
    return _participant.copyWith(hpCurrent: hpCurrent);
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
  }) async {
    return _encounter.copyWithStatus(status: 'active');
  }

  @override
  Future<Encounter> advanceTurn({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    return _encounter.copyWithRound(round: 1);
  }

  @override
  Future<Encounter> endEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    return _encounter.copyWithStatus(status: 'ended');
  }
}

extension on Encounter {
  Encounter copyWithStatus({required String status}) {
    return Encounter(
      id: id,
      campaignId: campaignId,
      sessionId: sessionId,
      name: name,
      status: status,
      round: round,
      currentTurnParticipantId: currentTurnParticipantId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      participants: participants,
    );
  }

  Encounter copyWithRound({required int round}) {
    return Encounter(
      id: id,
      campaignId: campaignId,
      sessionId: sessionId,
      name: name,
      status: status,
      round: round,
      currentTurnParticipantId: currentTurnParticipantId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      participants: participants,
    );
  }
}
