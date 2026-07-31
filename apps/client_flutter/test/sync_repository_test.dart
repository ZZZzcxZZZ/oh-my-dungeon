import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/sync/sync_models.dart';
import 'package:dnd_table_client/src/core/sync/sync_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queues an operation once and advances a cursor', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftSyncRepository(database);
    const operation = SyncOperation(
      id: 'op-1',
      scope: 'vault',
      entityType: 'character',
      entityId: 'character-1',
      baseRevision: 3,
      payloadJson: '{"name":"Arannis"}',
    );

    await repository.enqueue(operation);
    await repository.enqueue(operation);
    expect(await repository.pending(scope: 'vault'), [operation]);

    await repository.saveCursor(
      scope: 'vault',
      remoteId: 'user-1',
      cursor: '42',
    );
    expect(await repository.readCursor('vault', 'user-1'), '42');
    await database.close();
  });

  test('marks operations completed and tracks failed attempts', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftSyncRepository(database);
    const operation = SyncOperation(
      id: 'op-2',
      scope: 'campaign',
      entityType: 'character',
      entityId: 'character-1',
      baseRevision: 0,
      payloadJson: '{}',
    );

    await repository.enqueue(operation);
    await repository.markAttemptFailed('op-2');
    final pending = await repository.pending(scope: 'campaign');
    expect(pending.single.attempts, 1);

    await repository.markCompleted('op-2');
    expect(await repository.pending(scope: 'campaign'), isEmpty);
    await database.close();
  });
}
