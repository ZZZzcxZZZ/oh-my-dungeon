import 'dart:convert';

import 'package:dnd_table_client/src/features/content/data/content_api_client.dart';
import 'package:dnd_table_client/src/features/content/domain/content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _apiBaseUrl = 'http://localhost:3000/api';
const _accessToken = 'access-token';

final _itemJson = {
  'id': 'item-1',
  'packageId': 'pkg-1',
  'type': 'spell',
  'slug': 'fire-bolt',
  'name': 'Fire Bolt',
  'description': 'A mote of fire.',
  'structured': {'level': 0},
  'tags': ['cantrip'],
  'sourceLabel': 'SRD',
  'schemaVersion': 1,
  'createdAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
};

final _packageJson = {
  'id': 'pkg-1',
  'scope': 'user',
  'ownerUserId': 'user-1',
  'campaignId': null,
  'name': 'Basic Spells',
  'version': '1.0.0',
  'schemaVersion': 1,
  'locale': 'zh-CN',
  'status': 'active',
  'createdBy': 'user-1',
  'createdAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
  'items': [_itemJson],
};

void main() {
  test('dry-runs a content package import', () async {
    http.Request? captured;
    final client = ContentApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'valid': true, 'errors': [], 'package': null}),
          201,
        );
      }),
    );

    final result = await client.importPackage(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      dryRun: true,
      package: {
        'name': 'Basic Spells',
        'version': '1.0.0',
        'items': [_itemJson],
      },
    );

    expect(captured?.method, 'POST');
    expect(captured?.url.toString(), '$_apiBaseUrl/content/packages/import');
    expect(captured?.headers['authorization'], 'Bearer $_accessToken');
    expect(jsonDecode(captured!.body)['dryRun'], isTrue);
    expect(result.valid, isTrue);
    expect(result.package, isNull);
  });

  test('imports a package and parses items', () async {
    final client = ContentApiClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'valid': true, 'errors': [], 'package': _packageJson}),
          201,
        );
      }),
    );

    final result = await client.importPackage(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      package: {
        'name': 'Basic Spells',
        'version': '1.0.0',
        'items': [_itemJson],
      },
    );

    expect(result.package?.name, 'Basic Spells');
    expect(result.package?.items?.single.name, 'Fire Bolt');
  });

  test('exports a package as json', () async {
    http.Request? captured;
    final exported = {
      'name': 'Basic Spells',
      'version': '1.0.0',
      'schemaVersion': 1,
      'locale': 'zh-CN',
      'items': [_itemJson],
    };
    final client = ContentApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(exported), 200);
      }),
    );

    final result = await client.exportPackage(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      packageId: 'pkg-1',
    );

    expect(
      captured?.url.toString(),
      '$_apiBaseUrl/content/packages/pkg-1/export',
    );
    expect(result, exported);
  });

  test('lists available campaign content with filters', () async {
    http.Request? captured;
    final client = ContentApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode([_itemJson]), 200);
      }),
    );

    final result = await client.listAvailableCampaignItems(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      campaignId: 'camp-1',
      type: 'spell',
      query: 'fire',
    );

    expect(
      captured?.url.toString(),
      '$_apiBaseUrl/campaigns/camp-1/content/available?type=spell&q=fire',
    );
    expect(result, [ContentItem.fromJson(_itemJson)]);
  });

  test('enables a package for a campaign', () async {
    http.Request? captured;
    final client = ContentApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'campaignId': 'camp-1',
            'packageId': 'pkg-1',
            'enabled': true,
          }),
          201,
        );
      }),
    );

    await client.setCampaignPackage(
      apiBaseUrl: _apiBaseUrl,
      accessToken: _accessToken,
      campaignId: 'camp-1',
      packageId: 'pkg-1',
      enabled: true,
    );

    expect(captured?.method, 'POST');
    expect(
      captured?.url.toString(),
      '$_apiBaseUrl/campaigns/camp-1/content/packages',
    );
    expect(jsonDecode(captured!.body), {'packageId': 'pkg-1', 'enabled': true});
  });
}
