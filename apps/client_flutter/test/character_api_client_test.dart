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

final _bindingJson = {
  'id': 'bind-1',
  'campaignId': 'camp-1',
  'characterId': 'char-1',
  'userId': 'user-1',
  'visibility': 'party',
  'status': 'active',
  'dmNotes': '',
  'joinedAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
  'character': _characterJson,
};

final _binding = CharacterCampaignBinding(
  id: 'bind-1',
  campaignId: 'camp-1',
  characterId: 'char-1',
  userId: 'user-1',
  visibility: 'party',
  status: 'active',
  dmNotes: '',
  joinedAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  character: _character,
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
      expect(
        jsonDecode(captured!.body),
        {
          'name': 'Arannis',
          'level': 3,
          'classSummary': 'Ranger',
          'raceSummary': 'Elf',
          'currentHp': 24,
          'maxHp': 24,
          'armorClass': 15,
        },
      );
      expect(result, _character);
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
          return http.Response(jsonEncode({..._characterJson, 'level': 4}), 200);
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
      expect(jsonDecode(captured!.body), {
        'campaignId': 'camp-1',
        'level': 4,
      });
      expect(result.level, 4);
    });
  });

  group('CharacterApiClient.bindCharacterToCampaign', () {
    test('posts campaign id and returns the binding', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode(_bindingJson), 201);
        }),
      );

      final result = await client.bindCharacterToCampaign(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        characterId: 'char-1',
        campaignId: 'camp-1',
      );

      expect(captured?.method, 'POST');
      expect(
        captured?.url.toString(),
        '$_apiBaseUrl/characters/char-1/campaign-bindings',
      );
      expect(jsonDecode(captured!.body), {'campaignId': 'camp-1'});
      expect(result, _binding);
    });
  });

  group('CharacterApiClient.listCampaignCharacters', () {
    test('returns character bindings for a campaign', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode([_bindingJson]), 200);
        }),
      );

      final result = await client.listCampaignCharacters(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
      );

      expect(captured?.method, 'GET');
      expect(
        captured?.url.toString(),
        '$_apiBaseUrl/campaigns/camp-1/characters',
      );
      expect(result, [_binding]);
    });
  });

  group('CharacterApiClient.adjustCampaignCharacterHp', () {
    test('posts a hp delta and returns the updated character', () async {
      http.Request? captured;
      final client = CharacterApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({..._characterJson, 'currentHp': 18}),
            201,
          );
        }),
      );

      final result = await client.adjustCampaignCharacterHp(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
        characterId: 'char-1',
        delta: -6,
      );

      expect(captured?.method, 'POST');
      expect(
        captured?.url.toString(),
        '$_apiBaseUrl/campaigns/camp-1/characters/char-1/hp',
      );
      expect(jsonDecode(captured!.body), {'delta': -6});
      expect(result.currentHp, 18);
    });
  });
}
