import 'dart:convert';

import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/sync/sync_models.dart';
import 'package:dnd_table_client/src/core/sync/sync_repository.dart';
import 'package:dnd_table_client/src/features/characters/data/local/drift_character_repository.dart';
import 'package:dnd_table_client/src/features/vault/data/drift_vault_change_applier.dart';
import 'package:dnd_table_client/src/features/vault/data/vault_sync_service.dart';
import 'package:dnd_table_client/src/features/vault/domain/vault_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';
import 'support/vault_test_support.dart';

void main() {
  test('pushes outbox before applying remote changes and cursor', () async {
    const characterOperation = SyncOperation(
      id: 'op-1',
      scope: 'vault',
      entityType: 'character',
      entityId: 'character-1',
      baseRevision: 0,
      payloadJson: '{"name":"Arannis"}',
    );
    const remoteNoteChange = VaultChange(
      cursor: '8',
      operation: 'upsert',
      entityType: 'note',
      entityId: 'note-1',
      revision: 1,
      payloadJson: '{"markdown":"Remember the harbor"}',
    );
    const session = VaultSession(
      remoteUserId: 'user-1',
      deviceId: 'device-1',
      baseUrl: 'https://table.example',
      accessToken: 'token',
    );
    final outbox = MemorySyncRepository(pendingOperations: [characterOperation]);
    final api = MemoryVaultApiClient(
      changes: VaultChangePage(
        cursor: '8',
        changes: [remoteNoteChange],
        hasMore: false,
      ),
    );
    final applier = MemoryVaultChangeApplier();
    final service = VaultSyncService(
      syncRepository: outbox,
      apiClient: api,
      changeApplier: applier,
    );

    await service.sync(session);
    expect(api.pushedOperationIds, ['op-1']);
    expect(applier.appliedEntityIds, ['note-1']);
    expect(await outbox.readCursor('vault', 'user-1'), '8');
  });

  test('keeps outbox entries on network failure', () async {
    const session = VaultSession(
      remoteUserId: 'user-1',
      deviceId: 'device-1',
      baseUrl: 'https://table.example',
      accessToken: 'token',
    );
    const operation = SyncOperation(
      id: 'op-1',
      scope: 'vault',
      entityType: 'character',
      entityId: 'character-1',
      baseRevision: 0,
      payloadJson: '{"name":"Arannis"}',
    );
    final outbox = MemorySyncRepository(pendingOperations: [operation]);
    final api = MemoryVaultApiClient(throwOnPush: true);
    final applier = MemoryVaultChangeApplier();
    final service = VaultSyncService(
      syncRepository: outbox,
      apiClient: api,
      changeApplier: applier,
    );

    await service.sync(session);
    expect(await outbox.pending(scope: 'vault'), isNotEmpty);
    expect(await outbox.readCursor('vault', 'user-1'), isNull);
  });

  test('paginates changes until hasMore is false', () async {
    const session = VaultSession(
      remoteUserId: 'user-1',
      deviceId: 'device-1',
      baseUrl: 'https://table.example',
      accessToken: 'token',
    );
    final api = MemoryVaultApiClient(
      changesPages: [
        VaultChangePage(
          cursor: '5',
          changes: [
            const VaultChange(cursor: '1', operation: 'upsert', entityType: 'note', entityId: 'note-1', revision: 1, payloadJson: '{}'),
            const VaultChange(cursor: '2', operation: 'upsert', entityType: 'note', entityId: 'note-2', revision: 1, payloadJson: '{}'),
          ],
          hasMore: true,
        ),
        VaultChangePage(
          cursor: '5',
          changes: [
            const VaultChange(cursor: '3', operation: 'upsert', entityType: 'note', entityId: 'note-3', revision: 1, payloadJson: '{}'),
          ],
          hasMore: false,
        ),
      ],
    );
    final outbox = MemorySyncRepository();
    final applier = MemoryVaultChangeApplier();
    final service = VaultSyncService(
      syncRepository: outbox,
      apiClient: api,
      changeApplier: applier,
    );

    await service.sync(session);
    expect(applier.appliedEntityIds, ['note-1', 'note-2', 'note-3']);
    expect(await outbox.readCursor('vault', 'user-1'), '5');
  });

  test('marks conflict phase on 409 response', () async {
    const session = VaultSession(
      remoteUserId: 'user-1',
      deviceId: 'device-1',
      baseUrl: 'https://table.example',
      accessToken: 'token',
    );
    const operation = SyncOperation(
      id: 'op-1',
      scope: 'vault',
      entityType: 'character',
      entityId: 'character-1',
      baseRevision: 0,
      payloadJson: '{"name":"Arannis"}',
    );
    final outbox = MemorySyncRepository(pendingOperations: [operation]);
    final api = MemoryVaultApiClient(pushResult: const VaultPushResult(
      applied: [],
      skipped: [],
      conflicts: [VaultConflict(entityId: 'character-1', currentRevision: 5)],
    ));
    final applier = MemoryVaultChangeApplier();
    final service = VaultSyncService(
      syncRepository: outbox,
      apiClient: api,
      changeApplier: applier,
    );

    final result = await service.sync(session);
    expect(result.phase, SyncPhase.conflict);
  });

  test('DriftVaultChangeApplier applies remote character without re-enqueuing', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final applier = DriftVaultChangeApplier(database);
    final character = testCharacter(id: 'char-1', name: 'Arannis');
    final change = VaultChange(
      cursor: '1',
      operation: 'upsert',
      entityType: 'character',
      entityId: character.id,
      revision: 5,
      payloadJson: jsonEncode(character.toJson()),
    );

    await applier.applyAll([change]);

    final saved = await DriftCharacterRepository(database).getById(character.id);
    expect(saved, isNotNull);
    expect(saved!.name, 'Arannis');

    final pending = await DriftSyncRepository(database).pending(scope: 'vault');
    expect(pending, isEmpty);
    await database.close();
  });

  test('DriftVaultChangeApplier applies remote favorite and note without re-enqueuing', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final applier = DriftVaultChangeApplier(database);

    final favoriteChange = VaultChange(
      cursor: '1',
      operation: 'upsert',
      entityType: 'favorite',
      entityId: 'example:class/fighter',
      revision: 1,
      payloadJson: jsonEncode({'entryKey': 'example:class/fighter', 'favorite': true}),
    );
    final noteChange = VaultChange(
      cursor: '2',
      operation: 'upsert',
      entityType: 'note',
      entityId: 'example:class/fighter',
      revision: 1,
      payloadJson: jsonEncode({'entryKey': 'example:class/fighter', 'markdown': 'Synced note'}),
    );

    await applier.applyAll([favoriteChange, noteChange]);

    final pending = await DriftSyncRepository(database).pending(scope: 'vault');
    expect(pending, isEmpty);
    await database.close();
  });
}
