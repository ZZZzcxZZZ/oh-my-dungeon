import 'dart:convert';

import 'package:dnd_table_client/src/core/sync/sync_models.dart';
import 'package:dnd_table_client/src/features/vault/data/vault_api_client.dart';
import 'package:dnd_table_client/src/features/vault/domain/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = VaultSession(
    remoteUserId: 'user-1',
    deviceId: 'device-1',
    baseUrl: 'https://table.example',
    accessToken: 'token',
  );

  test('push sends operations with Bearer token and device id', () async {
    Map<String, String>? capturedHeaders;
    Map<String, dynamic>? capturedBody;
    final client = MockClient((request) async {
      capturedHeaders = request.headers;
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'applied': ['op-1'],
          'skipped': [],
          'conflicts': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = HttpVaultApiClient(client: client);
    const operation = SyncOperation(
      id: 'op-1',
      scope: 'vault',
      entityType: 'character',
      entityId: 'character-1',
      baseRevision: 0,
      payloadJson: '{"name":"Arannis"}',
    );
    final result = await apiClient.push(session, [operation]);
    expect(result.applied, ['op-1']);
    expect(capturedHeaders?['authorization'], 'Bearer token');
    expect(capturedHeaders?['x-device-id'], 'device-1');
    expect(capturedBody?['operations'], isA<List>());
  });

  test('changes decodes cursor and change list', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'cursor': '42',
          'changes': [
            {
              'cursor': '40',
              'operation': 'upsert',
              'entityType': 'note',
              'entityId': 'note-1',
              'revision': 1,
              'payload': {'markdown': 'hello'},
              'createdAt': '2026-07-14T00:00:00.000Z',
            }
          ],
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final apiClient = HttpVaultApiClient(client: client);
    final page = await apiClient.changes(session, '0');
    expect(page.cursor, '42');
    expect(page.hasMore, isFalse);
    expect(page.changes.single.entityId, 'note-1');
    expect(page.changes.single.payloadJson, '{"markdown":"hello"}');
  });

  test('throws on 409 conflict', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'applied': [],
          'skipped': [],
          'conflicts': [{'entityId': 'character-1', 'currentRevision': 5}],
        }),
        409,
        headers: {'content-type': 'application/json'},
      );
    });
    final apiClient = HttpVaultApiClient(client: client);
    const operation = SyncOperation(
      id: 'op-1',
      scope: 'vault',
      entityType: 'character',
      entityId: 'character-1',
      baseRevision: 0,
      payloadJson: '{}',
    );
    expect(
      () => apiClient.push(session, [operation]),
      throwsA(isA<VaultConflictException>()),
    );
  });
}
