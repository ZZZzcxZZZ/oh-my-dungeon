import 'package:dnd_table_client/src/core/sync/sync_models.dart';
import 'package:dnd_table_client/src/core/sync/sync_repository.dart';
import 'package:dnd_table_client/src/features/vault/data/vault_api_client.dart';
import 'package:dnd_table_client/src/features/vault/data/vault_sync_service.dart';
import 'package:dnd_table_client/src/features/vault/domain/vault_models.dart';

class MemorySyncRepository implements SyncRepository {
  MemorySyncRepository({List<SyncOperation> pendingOperations = const []}) {
    for (final op in pendingOperations) {
      _operations[op.id] = op;
    }
  }
  final Map<String, SyncOperation> _operations = {};
  final Map<String, String> _cursors = {};

  @override
  Future<void> enqueue(SyncOperation operation) async {
    _operations[operation.id] = operation;
  }

  @override
  Future<List<SyncOperation>> pending({required String scope}) async {
    return _operations.values.where((op) => op.scope == scope).toList();
  }

  @override
  Future<void> markCompleted(String operationId) async {
    _operations.remove(operationId);
  }

  @override
  Future<void> markAttemptFailed(String operationId) async {
    final op = _operations[operationId];
    if (op != null) {
      _operations[operationId] = op.withAttempts(op.attempts + 1);
    }
  }

  @override
  Future<String?> readCursor(String scope, String remoteId) async {
    return _cursors['$scope:$remoteId'];
  }

  @override
  Future<void> saveCursor({
    required String scope,
    required String remoteId,
    required String cursor,
  }) async {
    _cursors['$scope:$remoteId'] = cursor;
  }
}

class MemoryVaultApiClient implements VaultApiClient {
  MemoryVaultApiClient({
    VaultChangePage? changes,
    this.changesPages,
    this.throwOnPush = false,
    this.pushResult,
  }) : _changes = changes;

  final VaultChangePage? _changes;
  final List<VaultChangePage>? changesPages;
  final bool throwOnPush;
  final VaultPushResult? pushResult;

  final List<String> pushedOperationIds = [];
  int _changesPageIndex = 0;

  @override
  Future<VaultPushResult> push(
    VaultSession session,
    List<SyncOperation> operations,
  ) async {
    if (throwOnPush) throw Exception('Network error');
    if (pushResult != null) {
      if (pushResult!.conflicts.isNotEmpty) {
        throw VaultConflictException(pushResult!);
      }
      return pushResult!;
    }
    pushedOperationIds.addAll(operations.map((op) => op.id));
    return VaultPushResult(
      applied: operations.map((op) => op.id).toList(),
      skipped: const [],
      conflicts: const [],
    );
  }

  @override
  Future<VaultChangePage> changes(VaultSession session, String cursor) async {
    if (changesPages != null) {
      return changesPages![_changesPageIndex++];
    }
    return _changes ??
        const VaultChangePage(cursor: '0', changes: [], hasMore: false);
  }

  @override
  Future<List<VaultDeviceView>> listDevices(VaultSession session) async => [];

  @override
  Future<void> revokeDevice(VaultSession session, String deviceId) async {}
}

class MemoryVaultChangeApplier implements VaultChangeApplier {
  final List<String> appliedEntityIds = [];

  @override
  Future<void> applyAll(List<VaultChange> changes) async {
    appliedEntityIds.addAll(changes.map((c) => c.entityId));
  }
}
