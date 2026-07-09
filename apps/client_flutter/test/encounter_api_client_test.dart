import 'dart:convert';

import 'package:dnd_table_client/src/features/encounters/data/encounter_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _apiBaseUrl = 'http://localhost:3000/api';
const _accessToken = 'access-token';

final _participantJson = {
  'id': 'part-1',
  'encounterId': 'enc-1',
  'participantType': 'npc',
  'characterId': null,
  'npcId': 'npc-1',
  'displayName': 'Goblin Scout',
  'initiative': 12,
  'hpCurrent': 7,
  'hpMax': 7,
  'armorClass': 15,
  'conditions': [],
  'isHiddenFromPlayers': false,
  'sortOrder': 0,
  'snapshot': {},
  'createdAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
};

final _encounterJson = {
  'id': 'enc-1',
  'campaignId': 'camp-1',
  'sessionId': null,
  'name': 'Road Ambush',
  'status': 'draft',
  'round': 0,
  'currentTurnParticipantId': null,
  'createdBy': 'user-1',
  'createdAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
  'participants': [_participantJson],
};

final _npcJson = {
  'id': 'npc-1',
  'campaignId': 'camp-1',
  'contentItemId': null,
  'name': 'Goblin Scout',
  'publicDescription': 'Small hostile scout.',
  'dmNotes': 'Flees at low HP.',
  'stats': {'hpMax': 7, 'armorClass': 15},
  'tags': ['goblin'],
  'createdBy': 'user-1',
  'createdAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
};

void main() {
  test('creates an npc', () async {
    http.Request? captured;
    final client = EncounterApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_npcJson), 201);
      }),
    );

    final result = await client.createNpc(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      campaignId: 'camp-1',
      name: 'Goblin Scout',
      stats: {'hpMax': 7, 'armorClass': 15},
    );

    expect(captured?.method, 'POST');
    expect(captured?.url.toString(), '$_apiBaseUrl/campaigns/camp-1/npcs');
    expect(result.name, 'Goblin Scout');
  });

  test('creates an encounter and starts it', () async {
    var call = 0;
    final client = EncounterApiClient(
      httpClient: MockClient((request) async {
        call++;
        if (call == 1) {
          return http.Response(jsonEncode(_encounterJson), 201);
        }
        return http.Response(
          jsonEncode({
            ..._encounterJson,
            'status': 'active',
            'round': 1,
            'currentTurnParticipantId': 'part-1',
          }),
          201,
        );
      }),
    );

    final encounter = await client.createEncounter(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      campaignId: 'camp-1',
      name: 'Road Ambush',
    );
    final started = await client.startEncounter(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      encounterId: encounter.id,
    );

    expect(encounter.name, 'Road Ambush');
    expect(started.status, 'active');
    expect(started.currentTurnParticipantId, 'part-1');
  });

  test('updates a participant hp', () async {
    http.Request? captured;
    final client = EncounterApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({..._participantJson, 'hpCurrent': 3}),
          200,
        );
      }),
    );

    final result = await client.updateParticipant(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      encounterId: 'enc-1',
      participantId: 'part-1',
      hpCurrent: 3,
    );

    expect(
      captured?.url.toString(),
      '$_apiBaseUrl/encounters/enc-1/participants/part-1',
    );
    expect(jsonDecode(captured!.body), {'hpCurrent': 3});
    expect(result.hpCurrent, 3);
  });
}
