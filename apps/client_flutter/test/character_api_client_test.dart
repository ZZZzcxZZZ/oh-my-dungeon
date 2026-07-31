import 'dart:convert';

import 'package:dnd_table_client/src/features/characters/data/character_api_client.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _apiBaseUrl = 'http://localhost:3000/api';
const _accessToken = 'access-token';

final _characterJson = {
  'id': 'char-1',
  'ownerUserId': 'user-1',
  'name': 'Arannis',
  'avatarUrl': null,
  'system': 'dnd5e',
  'level': 3,
  'classSummary': 'Ranger',
  'raceSummary': 'Elf',
  'currentHp': 24,
  'maxHp': 24,
  'armorClass': 15,
  'speed': 30,
  'initiativeBonus': 2,
  'abilities': {
    'str': 10,
    'dex': 14,
    'con': 12,
    'int': 10,
    'wis': 14,
    'cha': 8,
  },
  'saves': {},
  'skills': {},
  'inventory': [],
  'currency': {},
  'notes': '',
  'data': {},
  'createdAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
};

final _character = CharacterSheet(
  id: 'char-1',
  ownerUserId: 'user-1',
  name: 'Arannis',
  avatarUrl: null,
  system: 'dnd5e',
  level: 3,
  classSummary: 'Ranger',
  raceSummary: 'Elf',
  currentHp: 24,
  maxHp: 24,
  armorClass: 15,
  speed: 30,
  initiativeBonus: 2,
  abilities: const {
    'str': 10,
    'dex': 14,
    'con': 12,
    'int': 10,
    'wis': 14,
    'cha': 8,
  },
  saves: const {},
  skills: const {},
  inventory: const [],
  currency: const {},
  notes: '',
  data: const {},
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

void main() {
  group('CharacterApiClient.createCharacter', () {
    test('posts basic fields and returns the created character', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode(_characterJson), 201);
        }),
      );

      final result = await client.createCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        name: 'Arannis',
        level: 3,
        classSummary: 'Ranger',
        raceSummary: 'Elf',
        currentHp: 24,
        maxHp: 24,
        armorClass: 15,
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), '$_apiBaseUrl/characters');
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(jsonDecode(captured!.body), {
        'name': 'Arannis',
        'level': 3,
        'classSummary': 'Ranger',
        'raceSummary': 'Elf',
        'currentHp': 24,
        'maxHp': 24,
        'armorClass': 15,
      });
      expect(result, _character);
    });

    test('posts full sheet fields when creating a character', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode(_characterJson), 201);
        }),
      );

      await client.createCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        name: 'Arannis',
        abilities: const {'str': 10, 'dex': 14},
        saves: const {'dex': true},
        skills: const {'察觉': true},
        inventory: const [
          {'name': '长弓', 'quantity': 1},
        ],
        currency: const {'gp': 10, 'sp': 5},
        notes: '来自旧林地的游侠。',
      );

      expect(jsonDecode(captured!.body), {
        'name': 'Arannis',
        'abilities': {'str': 10, 'dex': 14},
        'saves': {'dex': true},
        'skills': {'察觉': true},
        'inventory': [
          {'name': '长弓', 'quantity': 1},
        ],
        'currency': {'gp': 10, 'sp': 5},
        'notes': '来自旧林地的游侠。',
      });
    });
  });

  group('CharacterApiClient.listCharacters', () {
    test('sends bearer token and returns owned characters', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode([_characterJson]), 200);
        }),
      );

      final result = await client.listCharacters(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
      );

      expect(captured?.method, 'GET');
      expect(captured?.url.toString(), '$_apiBaseUrl/characters');
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(result, [_character]);
    });
  });

  group('CharacterApiClient.updateCharacter', () {
    test('patches changed fields and returns the updated character', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({..._characterJson, 'level': 4}),
            200,
          );
        }),
      );

      final result = await client.updateCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        characterId: 'char-1',
        campaignId: 'camp-1',
        level: 4,
      );

      expect(captured?.method, 'PATCH');
      expect(captured?.url.toString(), '$_apiBaseUrl/characters/char-1');
      expect(jsonDecode(captured!.body), {'campaignId': 'camp-1', 'level': 4});
      expect(result.level, 4);
    });

    test('sends content refs in character data', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode(_characterJson), 200);
        }),
      );

      await client.updateCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        characterId: 'char-1',
        data: {
          'contentRefs': {
            'spells': ['item-spell-1'],
            'items': ['item-gear-1'],
            'features': ['item-feature-1'],
          },
        },
      );

      expect(jsonDecode(captured!.body), {
        'data': {
          'contentRefs': {
            'spells': ['item-spell-1'],
            'items': ['item-gear-1'],
            'features': ['item-feature-1'],
          },
        },
      });
    });

    test('patches full sheet fields when editing a character', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode(_characterJson), 200);
        }),
      );

      await client.updateCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        characterId: 'char-1',
        abilities: const {'wis': 16},
        saves: const {'wis': true},
        skills: const {'察觉': true, '隐匿': true},
        inventory: const [
          {'name': '治疗药水', 'quantity': 2},
        ],
        currency: const {'gp': 35},
        notes: '偏好远程侦察。',
      );

      expect(jsonDecode(captured!.body), {
        'abilities': {'wis': 16},
        'saves': {'wis': true},
        'skills': {'察觉': true, '隐匿': true},
        'inventory': [
          {'name': '治疗药水', 'quantity': 2},
        ],
        'currency': {'gp': 35},
        'notes': '偏好远程侦察。',
      });
    });
  });

  group('CharacterApiClient structured operations', () {
    test('posts HP changes to the auditable action endpoint', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'state': {
                'schemaVersion': 2,
                'hitPoints': {'current': 18, 'maximum': 24, 'temporary': 0},
                'deathSaves': {'successes': 0, 'failures': 0},
                'resources': <Object?>[],
                'conditions': <Object?>[],
                'items': <Object?>[],
                'extensions': <String, Object?>{},
              },
              'revision': 3,
              'event': {'type': 'character.hp.adjusted'},
            }),
            201,
          );
        }),
      );

      final result = await client.adjustHitPoints(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        characterId: 'char-1',
        requestId: 'request-hp-1',
        campaignId: 'camp-1',
        expectedRevision: 2,
        delta: -6,
      );

      expect(
        captured?.url.toString(),
        '$_apiBaseUrl/characters/char-1/actions/adjust-hp',
      );
      expect(jsonDecode(captured!.body), {
        'requestId': 'request-hp-1',
        'campaignId': 'camp-1',
        'expectedRevision': 2,
        'delta': -6,
      });
      expect(result.revision, 3);
      expect(result.state.hitPoints.current, 18);
    });

    test('posts condition, resource, and item actions consistently', () async {
      final requests = <http.Request>[];
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'state': {
                'schemaVersion': 2,
                'hitPoints': {'current': 24, 'maximum': 24, 'temporary': 0},
                'deathSaves': {'successes': 0, 'failures': 0},
                'resources': <Object?>[],
                'conditions': <Object?>[],
                'items': <Object?>[],
                'extensions': <String, Object?>{},
              },
              'revision': 1,
              'event': {'type': 'test'},
            }),
            201,
          );
        }),
      );

      await client.addCondition(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        characterId: 'char-1',
        requestId: 'request-condition-1',
        condition: const {'id': 'poisoned', 'type': 'poisoned'},
      );
      await client.consumeResource(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        characterId: 'char-1',
        requestId: 'request-resource-1',
        resourceId: 'second-wind',
        amount: 1,
      );
      await client.grantItem(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        characterId: 'char-1',
        requestId: 'request-item-1',
        item: const {'id': 'potion-1', 'name': '治疗药水', 'quantity': 1},
      );

      expect(requests.map((request) => request.url.path).toList(), [
        '/api/characters/char-1/actions/add-condition',
        '/api/characters/char-1/actions/consume-resource',
        '/api/characters/char-1/items',
      ]);
      expect(jsonDecode(requests[0].body), {
        'requestId': 'request-condition-1',
        'condition': {'id': 'poisoned', 'type': 'poisoned'},
      });
      expect(jsonDecode(requests[1].body), {
        'requestId': 'request-resource-1',
        'resourceId': 'second-wind',
        'amount': 1,
      });
      expect(jsonDecode(requests[2].body), {
        'requestId': 'request-item-1',
        'item': {'id': 'potion-1', 'name': '治疗药水', 'quantity': 1},
      });
    });
  });
}
