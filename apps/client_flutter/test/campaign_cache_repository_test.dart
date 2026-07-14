import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/campaigns/data/local/campaign_cache_repository.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_change.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftCampaignCacheRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftCampaignCacheRepository(database);
  });

  tearDown(() => database.close());

  test('applies a page atomically and advances cursor after writes', () async {
    final page = CampaignChangePage.fromJson({
      'items': [
        {
          'id': 'change-1',
          'campaignId': 'campaign-1',
          'cursor': '1',
          'entityType': 'content',
          'entityId': 'entry-1',
          'operation': 'upsert',
          'revision': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'entity': {
            'id': 'entry-1',
            'campaignId': 'campaign-1',
            'type': 'location',
            'slug': 'moon-harbor',
            'name': '月港',
            'entry': {'body': <Map<String, Object?>>[]},
            'revision': 1,
            'createdBy': 'u1',
            'updatedBy': 'u1',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
            'deletedAt': null,
          },
        },
      ],
      'nextCursor': '1',
      'hasMore': false,
    });
    await repository.applyPage('campaign-1', page);
    expect((await repository.getContentEntry('campaign-1', 'entry-1'))!.name,
        '月港');
    expect(await repository.cursorFor('campaign-1'), '1');
  });

  test('delete operation removes cached entry', () async {
    final upsertPage = CampaignChangePage.fromJson({
      'items': [
        {
          'id': 'change-1',
          'campaignId': 'campaign-1',
          'cursor': '1',
          'entityType': 'content',
          'entityId': 'entry-1',
          'operation': 'upsert',
          'revision': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'entity': {
            'id': 'entry-1',
            'campaignId': 'campaign-1',
            'type': 'location',
            'slug': 'moon-harbor',
            'name': '月港',
            'entry': {'body': <Map<String, Object?>>[]},
            'revision': 1,
            'createdBy': 'u1',
            'updatedBy': 'u1',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
            'deletedAt': null,
          },
        },
      ],
      'nextCursor': '1',
      'hasMore': false,
    });
    await repository.applyPage('campaign-1', upsertPage);
    expect(await repository.getContentEntry('campaign-1', 'entry-1'), isNotNull);

    final deletePage = CampaignChangePage.fromJson({
      'items': [
        {
          'id': 'change-2',
          'campaignId': 'campaign-1',
          'cursor': '2',
          'entityType': 'content',
          'entityId': 'entry-1',
          'operation': 'delete',
          'revision': 2,
          'createdAt': '2026-01-02T00:00:00.000Z',
        },
      ],
      'nextCursor': '2',
      'hasMore': false,
    });
    await repository.applyPage('campaign-1', deletePage);
    expect(await repository.getContentEntry('campaign-1', 'entry-1'), isNull);
  });

  test('idempotent apply — same page twice does not duplicate', () async {
    final page = CampaignChangePage.fromJson({
      'items': [
        {
          'id': 'change-1',
          'campaignId': 'campaign-1',
          'cursor': '1',
          'entityType': 'actor',
          'entityId': 'actor-1',
          'operation': 'upsert',
          'revision': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'entity': {
            'id': 'actor-1',
            'campaignId': 'campaign-1',
            'ownerUserId': 'user-1',
            'sourceCharacterId': null,
            'actorType': 'player',
            'status': 'active',
            'sheet': {'name': 'Hero', 'currentHp': 10, 'maxHp': 20},
            'revision': 1,
            'updatedBy': 'user-1',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        },
      ],
      'nextCursor': '1',
      'hasMore': false,
    });
    await repository.applyPage('campaign-1', page);
    await repository.applyPage('campaign-1', page);

    final actor = await repository.getActor('campaign-1', 'actor-1');
    expect(actor, isNotNull);
    expect(actor!.id, 'actor-1');
    expect(actor.sheet['name'], 'Hero');
  });

  test('cursorFor returns "0" when no cursor exists', () async {
    expect(await repository.cursorFor('campaign-1'), '0');
  });

  test('clearCampaign removes all actors and entries for a campaign',
      () async {
    final page = CampaignChangePage.fromJson({
      'items': [
        {
          'id': 'change-1',
          'campaignId': 'campaign-1',
          'cursor': '1',
          'entityType': 'actor',
          'entityId': 'actor-1',
          'operation': 'upsert',
          'revision': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'entity': {
            'id': 'actor-1',
            'campaignId': 'campaign-1',
            'ownerUserId': 'user-1',
            'sourceCharacterId': null,
            'actorType': 'player',
            'status': 'active',
            'sheet': {'name': 'Hero', 'currentHp': 10, 'maxHp': 20},
            'revision': 1,
            'updatedBy': 'user-1',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        },
        {
          'id': 'change-2',
          'campaignId': 'campaign-1',
          'cursor': '1',
          'entityType': 'content',
          'entityId': 'entry-1',
          'operation': 'upsert',
          'revision': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'entity': {
            'id': 'entry-1',
            'campaignId': 'campaign-1',
            'type': 'location',
            'slug': 'moon-harbor',
            'name': '月港',
            'entry': {'body': <Map<String, Object?>>[]},
            'revision': 1,
            'createdBy': 'u1',
            'updatedBy': 'u1',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
            'deletedAt': null,
          },
        },
      ],
      'nextCursor': '1',
      'hasMore': false,
    });
    await repository.applyPage('campaign-1', page);
    expect(await repository.getActor('campaign-1', 'actor-1'), isNotNull);
    expect(await repository.getContentEntry('campaign-1', 'entry-1'),
        isNotNull);

    await repository.clearCampaign('campaign-1');
    expect(await repository.getActor('campaign-1', 'actor-1'), isNull);
    expect(await repository.getContentEntry('campaign-1', 'entry-1'), isNull);
    expect(await repository.cursorFor('campaign-1'), '0');
  });

  test('watchActors emits updated list after applyPage', () async {
    final emitted = <List<String>>[];
    final subscription = repository
        .watchActors('campaign-1')
        .map((actors) => actors.map((a) => a.id).toList())
        .listen(emitted.add);

    // Allow initial emit to settle.
    await Future<void>.delayed(Duration.zero);

    final page = CampaignChangePage.fromJson({
      'items': [
        {
          'id': 'change-1',
          'campaignId': 'campaign-1',
          'cursor': '1',
          'entityType': 'actor',
          'entityId': 'actor-1',
          'operation': 'upsert',
          'revision': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'entity': {
            'id': 'actor-1',
            'campaignId': 'campaign-1',
            'ownerUserId': 'user-1',
            'sourceCharacterId': null,
            'actorType': 'player',
            'status': 'active',
            'sheet': {'name': 'Hero', 'currentHp': 10, 'maxHp': 20},
            'revision': 1,
            'updatedBy': 'user-1',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        },
      ],
      'nextCursor': '1',
      'hasMore': false,
    });
    await repository.applyPage('campaign-1', page);
    // Allow watch stream to deliver.
    await Future<void>.delayed(Duration.zero);

    expect(emitted, containsOnce(['actor-1']));
    await subscription.cancel();
  });
}
