import 'dart:convert';

import 'package:dnd_table_client/src/features/check_requests/data/check_request_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _apiBaseUrl = 'http://localhost:3000/api';
const _accessToken = 'access-token';

final _checkRequestJson = {
  'id': 'check-1',
  'sessionId': 'sess-1',
  'requestedBy': 'user-1',
  'label': 'Perception',
  'checkType': 'skill',
  'ability': null,
  'skill': 'perception',
  'dc': 15,
  'dcVisibility': 'public',
  'targetMode': 'all',
  'targetUserIds': [],
  'targetCharacterIds': [],
  'status': 'open',
  'createdAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
  'responses': [],
};

final _checkResponseJson = {
  'id': 'response-1',
  'requestId': 'check-1',
  'responderId': 'user-2',
  'characterId': null,
  'notation': '1d20+2',
  'total': 17,
  'components': [
    {
      'notation': '1d20',
      'results': [15],
    },
  ],
  'result': 'success',
  'createdAt': '2026-07-09T00:00:00.000Z',
};

void main() {
  test('creates a check request', () async {
    http.Request? captured;
    final client = CheckRequestApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_checkRequestJson), 201);
      }),
    );

    final result = await client.createCheckRequest(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      sessionId: 'sess-1',
      label: 'Perception',
      checkType: 'skill',
      skill: 'perception',
      dc: 15,
    );

    expect(captured?.method, 'POST');
    expect(
      captured?.url.toString(),
      '$_apiBaseUrl/sessions/sess-1/check-requests',
    );
    expect(result.label, 'Perception');
  });

  test('lists and responds to check requests', () async {
    var call = 0;
    final client = CheckRequestApiClient(
      httpClient: MockClient((request) async {
        call++;
        if (call == 1) {
          return http.Response(jsonEncode([_checkRequestJson]), 200);
        }
        return http.Response(jsonEncode(_checkResponseJson), 201);
      }),
    );

    final requests = await client.listCheckRequests(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      sessionId: 'sess-1',
    );
    final response = await client.respondToCheckRequest(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      requestId: requests.single.id,
      actorName: 'Ireena',
      modifier: 2,
    );

    expect(requests.single.dc, 15);
    expect(response.total, 17);
    expect(response.result, 'success');
  });

  test('closes a check request', () async {
    final client = CheckRequestApiClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({..._checkRequestJson, 'status': 'closed'}),
          200,
        );
      }),
    );

    final result = await client.closeCheckRequest(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      requestId: 'check-1',
    );

    expect(result.status, 'closed');
  });
}
