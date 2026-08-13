import 'dart:convert';

import 'package:dnd_table_client/src/features/characters/data/character_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _apiBaseUrl = 'http://localhost:3000/api';
const _accessToken = 'access-token';

void main() {
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
