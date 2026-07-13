import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'sync_models.dart';

/// Outbox 与 cursor 持久化接口。网络失败只能改变同步状态，不能清空本地数据。
abstract interface class SyncRepository {
  Future<void> enqueue(SyncOperation operation);
  Future<List<SyncOperation>> pending({required String scope});
  Future<void> markCompleted(String operationId);
  Future<void> markAttemptFailed(String operationId);
  Future<String?> readCursor(String scope, String remoteId);
  Future<void> saveCursor({
    required String scope,
    required String remoteId,
    required String cursor,
  });
}

/// 基于 Drift 的 Outbox 实现。enqueue 幂等，saveCursor upsert。
class DriftSyncRepository implements SyncRepository {
  DriftSyncRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> enqueue(SyncOperation operation) async {
    await _database.into(_database.syncOutbox).insertOnConflictUpdate(
          SyncOutboxCompanion.insert(
            id: operation.id,
            scope: operation.scope,
            entityType: operation.entityType,
            entityId: operation.entityId,
            baseRevision: Value(operation.baseRevision),
            payloadJson: operation.payloadJson,
            createdAt: DateTime.now(),
            attempts: Value(operation.attempts),
          ),
        );
  }

  @override
  Future<List<SyncOperation>> pending({required String scope}) async {
    final rows = await (_database.select(_database.syncOutbox)
          ..where((t) => t.scope.equals(scope))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows
        .map((row) => SyncOperation(
              id: row.id,
              scope: row.scope,
              entityType: row.entityType,
              entityId: row.entityId,
              baseRevision: row.baseRevision,
              payloadJson: row.payloadJson,
              attempts: row.attempts,
            ))
        .toList();
  }

  @override
  Future<void> markCompleted(String operationId) async {
    await (_database.delete(_database.syncOutbox)
          ..where((t) => t.id.equals(operationId)))
        .go();
  }

  @override
  Future<void> markAttemptFailed(String operationId) async {
    final row = await (_database.select(_database.syncOutbox)
          ..where((t) => t.id.equals(operationId)))
        .getSingleOrNull();
    if (row == null) return;
    await _database.into(_database.syncOutbox).insertOnConflictUpdate(
          SyncOutboxCompanion.insert(
            id: row.id,
            scope: row.scope,
            entityType: row.entityType,
            entityId: row.entityId,
            baseRevision: Value(row.baseRevision),
            payloadJson: row.payloadJson,
            createdAt: row.createdAt,
            attempts: Value(row.attempts + 1),
          ),
        );
  }

  @override
  Future<String?> readCursor(String scope, String remoteId) async {
    final row = await (_database.select(_database.syncCursors)
          ..where((t) => t.scope.equals(scope) & t.remoteId.equals(remoteId)))
        .getSingleOrNull();
    return row?.cursor;
  }

  @override
  Future<void> saveCursor({
    required String scope,
    required String remoteId,
    required String cursor,
  }) async {
    await _database.into(_database.syncCursors).insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            scope: scope,
            remoteId: remoteId,
            cursor: cursor,
            updatedAt: DateTime.now(),
          ),
        );
  }
}
