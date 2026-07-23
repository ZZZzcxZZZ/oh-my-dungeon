import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_event.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_event_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncClient implements CampaignSyncApiClient {
  _FakeSyncClient({this.hpResult, this.itemResult, this.throwException});

  CampaignEventResult? hpResult;
  CampaignEventResult? itemResult;
  Object? throwException;
  int hpCallCount = 0;
  int itemCallCount = 0;
  Map<String, dynamic>? lastHpArgs;
  Map<String, dynamic>? lastItemArgs;

  @override
  Future<CampaignEventResult> changeActorHp({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
    required int delta,
    String? reason,
    int? baseRevision,
  }) async {
    hpCallCount++;
    lastHpArgs = {
      'campaignId': campaignId,
      'actorId': actorId,
      'delta': delta,
      'reason': reason,
      'baseRevision': baseRevision,
    };
    if (throwException != null) throw throwException!;
    return hpResult!;
  }

  @override
  Future<CampaignEventResult> grantItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
    required String itemId,
    required String name,
    int quantity = 1,
    int? baseRevision,
  }) async {
    itemCallCount++;
    lastItemArgs = {
      'campaignId': campaignId,
      'actorId': actorId,
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'baseRevision': baseRevision,
    };
    if (throwException != null) throw throwException!;
    return itemResult!;
  }

  // 以下方法仅为满足接口, 测试不使用.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CampaignEventResult _hpResult(int newRevision) => CampaignEventResult(
      actor: {
        'id': 'actor-1',
        'revision': newRevision,
        'sheet': {'name': 'Arannis', 'currentHp': 12, 'maxHp': 30},
      },
      event: CampaignEvent(
        id: 'msg-1',
        campaignId: 'camp-1',
        senderId: 'dm-1',
        campaignActorId: 'actor-1',
        displayName: 'dm',
        kind: 'system',
        content: 'Arannis -8 HP (20 → 12)',
        eventData: {
          'eventType': 'actor.hp_changed',
          'delta': -8,
          'from': 20,
          'to': 12,
        },
        createdAt: '2026-07-23T00:00:00.000Z',
      ),
    );

CampaignEventResult _itemResult(int newRevision) => CampaignEventResult(
      actor: {
        'id': 'actor-1',
        'revision': newRevision,
        'sheet': {
          'name': 'Arannis',
          'inventory': [
            {'itemId': 'item-longsword', 'name': '长剑', 'quantity': 1},
          ],
        },
      },
      event: CampaignEvent(
        id: 'msg-2',
        campaignId: 'camp-1',
        senderId: 'dm-1',
        campaignActorId: 'actor-1',
        displayName: 'dm',
        kind: 'system',
        content: '给 Arannis 长剑 ×1',
        eventData: {
          'eventType': 'actor.item_granted',
          'itemId': 'item-longsword',
          'quantity': 1,
        },
        createdAt: '2026-07-23T00:00:00.000Z',
      ),
    );

void main() {
  group('CampaignEventDispatcher (Task 3.1)', () {
    test('changeActorHp calls API and invokes callbacks', () async {
      final client = _FakeSyncClient(hpResult: _hpResult(2));
      CampaignEvent? dispatchedEvent;
      Map<String, Object?>? changedActor;

      final dispatcher = CampaignEventDispatcher(
        apiClient: client,
        apiBaseUrlProvider: () => 'https://example.com',
        accessTokenProvider: () => 'token',
        onEventDispatched: (event) async {
          dispatchedEvent = event;
        },
        onActorChanged: (actor) async {
          changedActor = actor;
        },
      );

      final revision = await dispatcher.changeActorHp(
        campaignId: 'camp-1',
        actorId: 'actor-1',
        delta: -8,
      );

      expect(revision, 2);
      expect(client.hpCallCount, 1);
      expect(client.lastHpArgs?['delta'], -8);
      expect(changedActor?['revision'], 2);
      expect(dispatchedEvent?.eventType, 'actor.hp_changed');
      expect(dispatchedEvent?.eventData['delta'], -8);
    });

    test('grantItem calls API with correct quantity', () async {
      final client = _FakeSyncClient(itemResult: _itemResult(3));
      CampaignEvent? dispatchedEvent;

      final dispatcher = CampaignEventDispatcher(
        apiClient: client,
        apiBaseUrlProvider: () => 'https://example.com',
        accessTokenProvider: () => 'token',
        onEventDispatched: (event) async {
          dispatchedEvent = event;
        },
      );

      final revision = await dispatcher.grantItem(
        campaignId: 'camp-1',
        actorId: 'actor-1',
        itemId: 'item-longsword',
        name: '长剑',
        quantity: 1,
      );

      expect(revision, 3);
      expect(client.itemCallCount, 1);
      expect(client.lastItemArgs?['itemId'], 'item-longsword');
      expect(client.lastItemArgs?['quantity'], 1);
      expect(dispatchedEvent?.eventType, 'actor.item_granted');
    });

    test('sets lastError and rethrows on failure', () async {
      final client = _FakeSyncClient(
        throwException: CampaignSyncException('network down', statusCode: 500),
      );
      final dispatcher = CampaignEventDispatcher(
        apiClient: client,
        apiBaseUrlProvider: () => 'https://example.com',
        accessTokenProvider: () => 'token',
      );

      await expectLater(
        dispatcher.changeActorHp(
          campaignId: 'camp-1',
          actorId: 'actor-1',
          delta: -5,
        ),
        throwsA(isA<CampaignSyncException>()),
      );

      expect(dispatcher.lastError, contains('network down'));
      expect(dispatcher.isDispatching, isFalse);
    });

    test('sets isDispatching during call', () async {
      final client = _FakeSyncClient(hpResult: _hpResult(2));
      bool? dispatchingDuringCall;
      late CampaignEventDispatcher dispatcher;
      dispatcher = CampaignEventDispatcher(
        apiClient: client,
        apiBaseUrlProvider: () => 'https://example.com',
        accessTokenProvider: () => 'token',
        onActorChanged: (actor) async {
          dispatchingDuringCall = dispatcher.isDispatching;
        },
      );

      await dispatcher.changeActorHp(
        campaignId: 'camp-1',
        actorId: 'actor-1',
        delta: -8,
      );

      expect(dispatchingDuringCall, isTrue);
      expect(dispatcher.isDispatching, isFalse);
    });
  });
}
