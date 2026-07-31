import 'dart:convert';

import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listCharacterAudits loads typed character edit history', () async {
    http.Request? captured;
    final client = HttpCampaignSyncApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            {
              'id': 'audit-1',
              'campaignCharacterId': 'character-1',
              'campaignId': 'campaign-1',
              'characterUserId': 'dm-user',
              'baseRevision': 1,
              'resultRevision': 2,
              'changedPaths': ['currentHp'],
              'beforeSheet': {'currentHp': 12},
              'afterSheet': {'currentHp': 8},
              'createdAt': '2026-07-15T01:00:00.000Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final audits = await client.listCharacterAudits(
      apiBaseUrl: 'https://example.test/api',
      accessToken: 'access-token',
      campaignId: 'campaign-1',
      characterId: 'character-1',
    );

    expect(captured?.method, 'GET');
    expect(
      captured?.url.toString(),
      'https://example.test/api/campaigns/campaign-1/characters/character-1/audits',
    );
    expect(captured?.headers['authorization'], 'Bearer access-token');
    expect(audits, hasLength(1));
    expect(audits.single.changedPaths, ['currentHp']);
    expect(audits.single.beforeSheet['currentHp'], 12);
    expect(audits.single.afterSheet['currentHp'], 8);
  });
}
