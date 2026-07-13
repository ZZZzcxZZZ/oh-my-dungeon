import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_repository.dart';
import '../domain/vault_models.dart';
import 'vault_api_client.dart';

/// 单次同步结果。`phase` 用于驱动 UI 状态。
class VaultSyncResult {
  const VaultSyncResult({required this.phase, this.error});
  final SyncPhase phase;
  final String? error;
}

/// 把远端变更合并到本地存储。实现方负责在事务内去重和写库。
abstract interface class VaultChangeApplier {
  Future<void> applyAll(List<VaultChange> changes);
}

/// Personal Vault 同步服务。固定顺序：push → pull → apply → save cursor。
///
/// - 推送最多 100 条 pending 操作，applied 的标记完成。
/// - 409 冲突返回 [SyncPhase.conflict]，不标记完成。
/// - 网络异常增加 attempts 并保留 outbox，返回 [SyncPhase.error]。
class VaultSyncService {
  VaultSyncService({
    required this.syncRepository,
    required this.apiClient,
    required this.changeApplier,
  });

  final SyncRepository syncRepository;
  final VaultApiClient apiClient;
  final VaultChangeApplier changeApplier;

  Future<VaultSyncResult> sync(VaultSession session) async {
    try {
      // 1. Push pending operations (max 100)
      final pending = await syncRepository.pending(scope: 'vault');
      if (pending.isNotEmpty) {
        final batch = pending.take(100).toList();
        final result = await apiClient.push(session, batch);
        for (final id in result.applied) {
          await syncRepository.markCompleted(id);
        }
        if (result.conflicts.isNotEmpty) {
          return const VaultSyncResult(phase: SyncPhase.conflict);
        }
      }

      // 2. Pull changes (paginate until hasMore == false)
      final allChanges = <VaultChange>[];
      var cursor =
          await syncRepository.readCursor('vault', session.remoteUserId) ?? '0';
      while (true) {
        final page = await apiClient.changes(session, cursor);
        allChanges.addAll(page.changes);
        cursor = page.cursor;
        if (!page.hasMore) break;
      }

      // 3. Apply changes
      if (allChanges.isNotEmpty) {
        await changeApplier.applyAll(allChanges);
      }

      // 4. Save cursor
      await syncRepository.saveCursor(
        scope: 'vault',
        remoteId: session.remoteUserId,
        cursor: cursor,
      );

      return const VaultSyncResult(phase: SyncPhase.idle);
    } on VaultConflictException {
      return const VaultSyncResult(phase: SyncPhase.conflict);
    } catch (e) {
      // Network failure — increment attempts on pending ops, keep outbox
      final remaining = await syncRepository.pending(scope: 'vault');
      for (final op in remaining) {
        await syncRepository.markAttemptFailed(op.id);
      }
      return VaultSyncResult(phase: SyncPhase.error, error: e.toString());
    }
  }
}
