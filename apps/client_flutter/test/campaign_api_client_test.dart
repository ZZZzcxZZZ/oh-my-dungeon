import 'dart:convert';

import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _apiBaseUrl = 'http://localhost:3000/api';
const _accessToken = 'access-token';

final _campaignJson = {
  'id': 'camp-1',
  'name': 'Curse of Strahd',
  'description': '',
  'system': 'dnd5e',
  'ownerId': 'user-1',
  'status': 'active',
  'createdAt': '2026-07-09T00:00:00.000Z',
  'updatedAt': '2026-07-09T00:00:00.000Z',
};

final _campaign = Campaign(
  id: 'camp-1',
  name: 'Curse of Strahd',
  description: '',
  system: 'dnd5e',
  ownerId: 'user-1',
  status: 'active',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

final _inviteJson = {
  'id': 'invite-1',
  'campaignId': 'camp-1',
  'code': 'ABC123XYZ',
  'roleOnJoin': 'player',
  'expiresAt': null,
  'maxUses': 1,
  'usedCount': 0,
  'requireApproval': false,
  'createdAt': '2026-07-09T00:00:00.000Z',
};

final _invite = CampaignInvite(
  id: 'invite-1',
  campaignId: 'camp-1',
  code: 'ABC123XYZ',
  roleOnJoin: 'player',
  expiresAt: null,
  maxUses: 1,
  usedCount: 0,
  requireApproval: false,
  createdAt: '2026-07-09T00:00:00.000Z',
);

final _membershipJson = {
  'id': 'member-1',
  'campaignId': 'camp-1',
  'userId': 'user-1',
  'role': 'player',
  'displayName': 'ranger',
  'joinedAt': '2026-07-09T00:00:00.000Z',
};

final _membership = CampaignMembership(
  id: 'member-1',
  campaignId: 'camp-1',
  userId: 'user-1',
  role: 'player',
  displayName: 'ranger',
  joinedAt: '2026-07-09T00:00:00.000Z',
);

final _campaignChatMessageJson = {
  'id': 'msg-1',
  'campaignId': 'camp-1',
  'senderId': 'user-1',
  'campaignCharacterId': 'character-1',
  'displayName': 'Arannis',
  'avatarUrl': null,
  'kind': 'action',
  'content': '推开吱呀作响的木门',
  'actionSnapshot': {
    'id': 'action-surge',
    'name': '动作如潮',
    'entryId': 'guide:feature/action-surge',
    'formula': '1/use',
    'characterRevision': 3,
  },
  'eventData': {
    'targetCharacterId': 'character-1',
    'checkType': 'skill',
    'checkKey': '察觉',
  },
  'createdAt': '2026-07-09T00:00:00.000Z',
};

final _campaignChatMessage = CampaignChatMessage(
  id: 'msg-1',
  campaignId: 'camp-1',
  senderId: 'user-1',
  campaignCharacterId: 'character-1',
  displayName: 'Arannis',
  avatarUrl: null,
  kind: 'action',
  content: '推开吱呀作响的木门',
  actionSnapshot: {
    'id': 'action-surge',
    'name': '动作如潮',
    'entryId': 'guide:feature/action-surge',
    'formula': '1/use',
    'characterRevision': 3,
  },
  eventData: {
    'targetCharacterId': 'character-1',
    'checkType': 'skill',
    'checkKey': '察觉',
  },
  createdAt: '2026-07-09T00:00:00.000Z',
);

void main() {
  group('CampaignApiClient.createCampaign', () {
    test('posts name and returns the created campaign', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(_campaignJson),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.createCampaign(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        name: 'Curse of Strahd',
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), '$_apiBaseUrl/campaigns');
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(jsonDecode(captured!.body), {'name': 'Curse of Strahd'});
      expect(result, _campaign);
    });

    test('includes description and system when provided', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode(_campaignJson), 201);
        }),
      );

      await client.createCampaign(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        name: 'Curse of Strahd',
        description: 'A gothic horror campaign',
        system: 'dnd5e',
      );

      expect(jsonDecode(captured!.body), {
        'name': 'Curse of Strahd',
        'description': 'A gothic horror campaign',
        'system': 'dnd5e',
      });
    });

    test('throws CampaignApiException on 400 missing name', () async {
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Campaign name is required'}),
            400,
          );
        }),
      );

      expect(
        () => client.createCampaign(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          name: '',
        ),
        throwsA(
          isA<CampaignApiException>()
              .having((e) => e.message, 'message', 'Campaign name is required')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });

  group('CampaignApiClient.listCampaigns', () {
    test('sends bearer token and returns a list of campaigns', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode([_campaignJson]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.listCampaigns(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
      );

      expect(captured?.method, 'GET');
      expect(captured?.url.toString(), '$_apiBaseUrl/campaigns');
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(result, [_campaign]);
    });

    test('returns an empty list when no campaigns', () async {
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode([]), 200);
        }),
      );

      final result = await client.listCampaigns(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
      );

      expect(result, isEmpty);
    });
  });

  group('CampaignApiClient.getCampaign', () {
    test('sends bearer token and returns the campaign', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(_campaignJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.getCampaign(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
      );

      expect(captured?.method, 'GET');
      expect(captured?.url.toString(), '$_apiBaseUrl/campaigns/camp-1');
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(result, _campaign);
    });

    test('throws CampaignApiException on 404', () async {
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Campaign not found'}),
            404,
          );
        }),
      );

      expect(
        () => client.getCampaign(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          campaignId: 'missing',
        ),
        throwsA(
          isA<CampaignApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });
  });

  group('CampaignApiClient.getWorkspaceContext', () {
    test('loads the viewer-scoped campaign workspace context', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'campaign': _campaignJson,
              'membership': {
                ..._membershipJson,
                'boundCharacterId': 'character-1',
                'activeSpeakerCharacterId': 'character-1',
                'speakerMode': 'boundCharacter',
                'lastReadAt': null,
              },
              'members': const [
                {'userId': 'user-1', 'displayName': 'ranger', 'role': 'player'},
              ],
              'characters': const [
                {
                  'id': 'character-1',
                  'ownerUserId': 'user-1',
                  'characterType': 'player',
                  'status': 'active',
                  'lifecycle': 'persistent',
                  'displayName': 'Arannis',
                  'avatarAssetId': null,
                  'publicHealthState': 'healthy',
                },
              ],
              'capabilities': const {
                'canManageCampaign': false,
                'canManageMembers': false,
                'canInviteMembers': false,
                'canCreateCharacters': false,
                'canManageCharacters': false,
                'canEditAnyCharacter': false,
                'canSpeakAsNarrator': false,
                'canCreateArchive': false,
                'canManageArchive': false,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final context = await client.getWorkspaceContext(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
      );

      expect(captured?.method, 'GET');
      expect(captured?.url.toString(), '$_apiBaseUrl/campaigns/camp-1/context');
      expect(context.membership.boundCharacterId, 'character-1');
      expect(context.characters.single.publicHealthState, 'healthy');
      expect(context.capabilities.canManageCampaign, isFalse);
      expect(context.capabilities.canInviteMembers, isFalse);
      expect(context.capabilities.canEditAnyCharacter, isFalse);
      expect(context.capabilities.canManageArchive, isFalse);
    });
  });

  group('CampaignApiClient.updateSpeaker', () {
    test(
      'persists the selected campaign speaker instead of trusting a message payload',
      () async {
        http.Request? captured;
        final client = CampaignApiClient(
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                ..._membershipJson,
                'activeSpeakerCharacterId': 'npc-1',
                'speakerMode': 'character',
                'lastReadAt': null,
              }),
              200,
            );
          }),
        );

        final membership = await client.updateSpeaker(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          campaignId: 'camp-1',
          speakerMode: 'character',
          characterId: 'npc-1',
        );

        expect(captured?.method, 'PUT');
        expect(
          captured?.url.toString(),
          '$_apiBaseUrl/campaigns/camp-1/speaker',
        );
        expect(jsonDecode(captured!.body), {
          'speakerMode': 'character',
          'characterId': 'npc-1',
        });
        expect(membership.activeSpeakerCharacterId, 'npc-1');
      },
    );
  });

  group('CampaignApiClient.updateMemberBinding', () {
    test('binds the current player to a campaign character', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              ..._membershipJson,
              'boundCharacterId': 'character-1',
              'speakerMode': 'boundCharacter',
              'lastReadAt': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final membership = await client.updateMemberBinding(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
        userId: 'user-1',
        characterId: 'character-1',
      );

      expect(captured?.method, 'PUT');
      expect(
        captured?.url.toString(),
        '$_apiBaseUrl/campaigns/camp-1/members/user-1/binding',
      );
      expect(jsonDecode(captured!.body), {'characterId': 'character-1'});
      expect(membership.boundCharacterId, 'character-1');
    });
  });

  group('CampaignApiClient archives', () {
    test(
      'lists archive entries and creates a clue with JSON payload',
      () async {
        final requests = <http.Request>[];
        final client = CampaignApiClient(
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'archive-1',
                    'campaignId': 'camp-1',
                    'kind': 'clue',
                    'title': 'The silver key',
                    'summary': 'Found below the chapel.',
                    'payload': {'location': 'chapel'},
                    'pinned': false,
                    'updatedAt': '2026-07-16T00:00:00.000Z',
                  },
                ]),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'id': 'archive-2',
                'campaignId': 'camp-1',
                'kind': 'clue',
                'title': 'The silver key',
                'summary': 'Found below the chapel.',
                'payload': {'location': 'chapel'},
                'pinned': false,
                'updatedAt': '2026-07-16T00:00:00.000Z',
              }),
              201,
            );
          }),
        );

        final entries = await client.listArchives(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          campaignId: 'camp-1',
        );
        final created = await client.createArchiveEntry(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          campaignId: 'camp-1',
          kind: 'clue',
          title: 'The silver key',
          summary: 'Found below the chapel.',
          payload: const {'location': 'chapel'},
        );

        expect(entries.single.title, 'The silver key');
        expect(created.id, 'archive-2');
        expect(
          requests[0].url.toString(),
          '$_apiBaseUrl/campaigns/camp-1/archives',
        );
        expect(requests[1].method, 'POST');
        expect(jsonDecode(requests[1].body), {
          'kind': 'clue',
          'title': 'The silver key',
          'summary': 'Found below the chapel.',
          'payload': {'location': 'chapel'},
        });
      },
    );
  });

  group('CampaignApiClient.createInvite', () {
    test('posts to the invites endpoint and returns the invite', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(_inviteJson),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.createInvite(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
        maxUses: 1,
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), '$_apiBaseUrl/campaigns/camp-1/invites');
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(jsonDecode(captured!.body), {'maxUses': 1});
      expect(result, _invite);
    });
  });

  group('CampaignApiClient.listInvites', () {
    test('sends bearer token and returns a list of invites', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode([_inviteJson]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.listInvites(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
      );

      expect(captured?.method, 'GET');
      expect(captured?.url.toString(), '$_apiBaseUrl/campaigns/camp-1/invites');
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(result, [_invite]);
    });
  });

  group('CampaignApiClient.joinCampaign', () {
    test('posts the invite code and returns the membership', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(_membershipJson),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.joinCampaign(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        code: 'ABC123',
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), '$_apiBaseUrl/campaigns/join');
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(jsonDecode(captured!.body), {'code': 'ABC123'});
      expect(result, _membership);
    });

    test('throws CampaignApiException on 404 invite not found', () async {
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Invite not found'}),
            404,
          );
        }),
      );

      expect(
        () => client.joinCampaign(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          code: 'NOPE',
        ),
        throwsA(
          isA<CampaignApiException>()
              .having((e) => e.message, 'message', 'Invite not found')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('throws CampaignApiException on 403 expired invite', () async {
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Invite has expired'}),
            403,
          );
        }),
      );

      expect(
        () => client.joinCampaign(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          code: 'OLD',
        ),
        throwsA(
          isA<CampaignApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });
  });

  group('CampaignApiClient campaign chat messages', () {
    test('lists campaign messages without a session', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode([_campaignChatMessageJson]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.listMessages(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
      );

      expect(captured?.method, 'GET');
      expect(
        captured?.url.toString(),
        '$_apiBaseUrl/campaigns/camp-1/messages',
      );
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(result, [_campaignChatMessage]);
    });

    test('adds a trimmed query when searching campaign messages', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('[]', 200);
        }),
      );

      await client.listMessages(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
        query: ' chapel ',
      );

      expect(captured?.url.queryParameters, {'query': 'chapel'});
    });

    test('sends action messages with campaign character identity', () async {
      http.Request? captured;
      final client = CampaignApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(_campaignChatMessageJson),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.sendMessage(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: 'camp-1',
        kind: 'action',
        content: '推开吱呀作响的木门',
        campaignCharacterId: 'character-1',
        actionId: 'action-surge',
        eventData: const {
          'targetCharacterId': 'character-1',
          'checkType': 'skill',
          'checkKey': '察觉',
        },
      );

      expect(captured?.method, 'POST');
      expect(
        captured?.url.toString(),
        '$_apiBaseUrl/campaigns/camp-1/messages',
      );
      expect(captured?.headers['authorization'], 'Bearer $_accessToken');
      expect(jsonDecode(captured!.body), {
        'kind': 'action',
        'content': '推开吱呀作响的木门',
        'campaignCharacterId': 'character-1',
        'actionId': 'action-surge',
        'eventData': {
          'targetCharacterId': 'character-1',
          'checkType': 'skill',
          'checkKey': '察觉',
        },
      });
      expect(result, _campaignChatMessage);
    });
  });

  test('normalizes trailing slashes in the api base url', () async {
    final client = CampaignApiClient(
      httpClient: MockClient((request) async {
        expect(request.url.toString(), '$_apiBaseUrl/campaigns');
        return http.Response(jsonEncode([_campaignJson]), 200);
      }),
    );

    await client.listCampaigns(
      apiBaseUrl: '$_apiBaseUrl/',
      accessToken: _accessToken,
    );
  });
}
