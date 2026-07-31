import 'dart:convert';

import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/campaigns/data/local/campaign_cache_repository.dart';
import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_character_backlink_service.dart';
import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_character.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_change.dart';
import 'package:dnd_table_client/src/features/characters/data/local/drift_character_repository.dart';
import 'package:dnd_table_client/src/features/characters/data/local/character_sync_conflict_repository.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

const _apiBaseUrl = 'http://localhost:3000/api';
const _accessToken = 'access-token';
const _deviceId = 'device-1';
const _campaignId = 'campaign-1';
const _userId = 'user-1';

CampaignChange _contentChange({
  required String changeId,
  required String entryId,
  required String cursor,
  required String name,
  int revision = 1,
}) {
  return CampaignChange(
    id: changeId,
    campaignId: _campaignId,
    cursor: cursor,
    entityType: 'content',
    entityId: entryId,
    operation: 'upsert',
    revision: revision,
    createdAt: '2026-01-01T00:00:00.000Z',
    entity: {
      'id': entryId,
      'campaignId': _campaignId,
      'type': 'location',
      'slug': entryId,
      'name': name,
      'entry': {'body': <Map<String, Object?>>[]},
      'revision': revision,
      'createdBy': _userId,
      'updatedBy': _userId,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
      'deletedAt': null,
    },
  );
}

CampaignChange _characterChange({
  required String changeId,
  required String characterId,
  required String cursor,
  String? ownerUserId,
  String? sourceCharacterId,
  Map<String, Object?>? sheet,
  int revision = 1,
}) {
  return CampaignChange(
    id: changeId,
    campaignId: _campaignId,
    cursor: cursor,
    entityType: 'character',
    entityId: characterId,
    operation: 'upsert',
    revision: revision,
    createdAt: '2026-01-01T00:00:00.000Z',
    entity: {
      'id': characterId,
      'campaignId': _campaignId,
      'ownerUserId': ownerUserId,
      'sourceCharacterId': sourceCharacterId,
      'characterType': 'player',
      'status': 'active',
      'sheet': sheet ?? {'name': 'Hero', 'currentHp': 10, 'maxHp': 20},
      'revision': revision,
      'updatedBy': _userId,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    },
  );
}

void main() {
  group('pullUntilCurrent', () {
    test('fetches all pages and applies them', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final cacheRepository = MemoryCampaignCacheRepository();
      final apiClient = MemoryCampaignSyncApiClient(
        changePages: [
          CampaignChangePage(
            items: [
              _contentChange(
                changeId: 'c1',
                entryId: 'entry-1',
                cursor: '1',
                name: '月港',
              ),
            ],
            nextCursor: '1',
            hasMore: true,
          ),
          CampaignChangePage(
            items: [
              _contentChange(
                changeId: 'c2',
                entryId: 'entry-2',
                cursor: '2',
                name: '黑塔',
              ),
            ],
            nextCursor: '2',
            hasMore: false,
          ),
        ],
      );
      final backlinkService = CampaignCharacterBacklinkService(
        characterRepository: DriftCharacterRepository(database),
        database: database,
      );
      final service = CampaignSyncService(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        backlinkService: backlinkService,
      );

      final result = await service.pullUntilCurrent(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        deviceId: _deviceId,
        campaignId: _campaignId,
        userId: _userId,
      );

      expect(result, CampaignSyncResult.idle);
      expect(
        (await cacheRepository.getContentEntry(_campaignId, 'entry-1'))!.name,
        '月港',
      );
      expect(
        (await cacheRepository.getContentEntry(_campaignId, 'entry-2'))!.name,
        '黑塔',
      );
      expect(await cacheRepository.cursorFor(_campaignId), '2');
    });

    test('processes character backlinks for owned characters', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final characterRepository = DriftCharacterRepository(database);
      // 预存本地角色，sourceCharacterId 指向它。
      await characterRepository.save(
        CharacterSheet.local(id: 'char-1', name: 'Hero', level: 1),
      );
      final cacheRepository = DriftCampaignCacheRepository(database);
      final apiClient = MemoryCampaignSyncApiClient(
        changePages: [
          CampaignChangePage(
            items: [
              _characterChange(
                changeId: 'c1',
                characterId: 'character-1',
                cursor: '1',
                ownerUserId: _userId,
                sourceCharacterId: 'char-1',
                sheet: {
                  'name': 'Hero Renamed',
                  'level': 4,
                  'classSummary': '战士',
                  'notes': 'DM note',
                  'currentHp': 10,
                  'maxHp': 20,
                },
              ),
            ],
            nextCursor: '1',
            hasMore: false,
          ),
        ],
      );
      final backlinkService = CampaignCharacterBacklinkService(
        characterRepository: characterRepository,
        database: database,
      );
      final service = CampaignSyncService(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        backlinkService: backlinkService,
      );

      final result = await service.pullUntilCurrent(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        deviceId: _deviceId,
        campaignId: _campaignId,
        userId: _userId,
      );

      expect(result, CampaignSyncResult.idle);
      final updated = await characterRepository.getById('char-1');
      expect(updated, isNotNull);
      expect(updated!.currentHp, 10);
      expect(updated.maxHp, 20);
      expect(updated.name, 'Hero Renamed');
      expect(updated.level, 4);
      expect(updated.classSummary, '战士');
      expect(updated.notes, 'DM note');
      // Backlink row should record the applied revision.
      final backlinkRow =
          await (database.select(database.campaignCharacterBacklinks)
                ..where((t) => t.campaignCharacterId.equals('character-1')))
              .getSingleOrNull();
      expect(backlinkRow, isNotNull);
      expect(backlinkRow!.lastAppliedCharacterRevision, 1);
    });

    test('records a conflict after the local character changed', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final characterRepository = DriftCharacterRepository(database);
      await characterRepository.save(
        CharacterSheet.local(id: 'char-1', name: 'Hero', level: 1),
      );
      final backlinkService = CampaignCharacterBacklinkService(
        characterRepository: characterRepository,
        database: database,
      );
      await backlinkService.applyPublishedCharacterToCharacter(
        CampaignCharacter.fromJson(
          _characterChange(
            changeId: 'c1',
            characterId: 'character-1',
            cursor: '1',
            ownerUserId: _userId,
            sourceCharacterId: 'char-1',
            revision: 1,
          ).entity!,
        ),
      );
      final local = await characterRepository.getById('char-1');
      await characterRepository.save(
        local!.copyWith(abilities: const {'str': 18}),
      );

      await backlinkService.applyCharacterToCharacter(
        CampaignCharacter.fromJson(
          _characterChange(
            changeId: 'c2',
            characterId: 'character-1',
            cursor: '2',
            ownerUserId: _userId,
            sourceCharacterId: 'char-1',
            revision: 2,
            sheet: {
              ...local.toJson(),
              'abilities': const {'str': 12},
            },
          ).entity!,
        ),
      );

      final conflicts = await database
          .select(database.characterSyncConflicts)
          .get();
      expect(conflicts, hasLength(1));
      expect(conflicts.single.remoteValueJson, contains('"revision":2'));

      await backlinkService.applyCharacterToCharacter(
        CampaignCharacter.fromJson(
          _characterChange(
            changeId: 'c3',
            characterId: 'character-1',
            cursor: '3',
            ownerUserId: _userId,
            sourceCharacterId: 'char-1',
            revision: 3,
            sheet: {
              ...local.toJson(),
              'abilities': const {'str': 10},
            },
          ).entity!,
        ),
      );

      final stillLocal = await characterRepository.getById('char-1');
      expect(stillLocal!.abilities, const {'str': 18});
      expect(
        await database.select(database.characterSyncConflicts).get(),
        hasLength(2),
      );
    });

    test('resolves a conflict by applying the captured remote sheet', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final characterRepository = DriftCharacterRepository(database);
      final local = CharacterSheet.local(
        id: 'char-1',
        name: 'Hero',
        level: 1,
      ).copyWith(abilities: const {'str': 18});
      await characterRepository.save(local);
      final backlinkService = CampaignCharacterBacklinkService(
        characterRepository: characterRepository,
        database: database,
      );
      final conflict = CharacterSyncConflict(
        id: 'conflict-1',
        characterId: 'char-1',
        campaignCharacterId: 'character-1',
        fieldPath: 'build',
        localValueJson: jsonEncode(local.toJson()),
        remoteValueJson: jsonEncode({
          ...local.toJson(),
          'abilities': const {'str': 12},
          'revision': 7,
        }),
        createdAt: DateTime(2026, 7, 22),
      );

      final applied = await backlinkService.resolveConflictWithRemote(conflict);

      expect(applied, isTrue);
      expect(
        (await characterRepository.getById('char-1'))!.abilityMap['str'],
        12,
      );
      final backlink = await database
          .select(database.campaignCharacterBacklinks)
          .getSingle();
      expect(backlink.lastAppliedCharacterRevision, 7);
    });

    test('401 response returns paused result and keeps cursor', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final cacheRepository = MemoryCampaignCacheRepository();
      final apiClient = MemoryCampaignSyncApiClient(
        listChangesException: const CampaignSyncException(
          'Unauthorized',
          statusCode: 401,
        ),
      );
      final backlinkService = CampaignCharacterBacklinkService(
        characterRepository: DriftCharacterRepository(database),
        database: database,
      );
      final service = CampaignSyncService(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        backlinkService: backlinkService,
      );

      final result = await service.pullUntilCurrent(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        deviceId: _deviceId,
        campaignId: _campaignId,
        userId: _userId,
      );

      expect(result, CampaignSyncResult.paused);
      expect(await cacheRepository.cursorFor(_campaignId), '0');
    });

    test('403 response returns revoked result and keeps cursor', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final cacheRepository = MemoryCampaignCacheRepository();
      final apiClient = MemoryCampaignSyncApiClient(
        listChangesException: const CampaignSyncException(
          'Forbidden',
          statusCode: 403,
        ),
      );
      final backlinkService = CampaignCharacterBacklinkService(
        characterRepository: DriftCharacterRepository(database),
        database: database,
      );
      final service = CampaignSyncService(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        backlinkService: backlinkService,
      );

      final result = await service.pullUntilCurrent(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        deviceId: _deviceId,
        campaignId: _campaignId,
        userId: _userId,
      );

      expect(result, CampaignSyncResult.revoked);
      expect(await cacheRepository.cursorFor(_campaignId), '0');
    });

    test('network error returns error result and keeps cursor', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final cacheRepository = MemoryCampaignCacheRepository();
      final apiClient = MemoryCampaignSyncApiClient(
        listChangesException: Exception('Network error'),
      );
      final backlinkService = CampaignCharacterBacklinkService(
        characterRepository: DriftCharacterRepository(database),
        database: database,
      );
      final service = CampaignSyncService(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        backlinkService: backlinkService,
      );

      final result = await service.pullUntilCurrent(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        deviceId: _deviceId,
        campaignId: _campaignId,
        userId: _userId,
      );

      expect(result, CampaignSyncResult.error);
      expect(await cacheRepository.cursorFor(_campaignId), '0');
    });
  });
}
