/// 同步阶段，驱动 UI 状态展示。
enum SyncPhase { offline, idle, syncing, conflict, error }

/// 待推送到远端（Vault 或战役）的本地写操作。
///
/// 幂等键为 [id]：同一操作重复入队只保留一条。Vault 与战役同步都使用 Outbox，
/// 通过 [scope] 区分（`vault` 或 `campaign:<campaignId>`）。
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.scope,
    required this.entityType,
    required this.entityId,
    required this.baseRevision,
    required this.payloadJson,
    this.attempts = 0,
  });

  final String id;
  final String scope;
  final String entityType;
  final String entityId;
  final int baseRevision;
  final String payloadJson;
  final int attempts;

  SyncOperation withAttempts(int attempts) => SyncOperation(
        id: id,
        scope: scope,
        entityType: entityType,
        entityId: entityId,
        baseRevision: baseRevision,
        payloadJson: payloadJson,
        attempts: attempts,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          scope == other.scope &&
          entityType == other.entityType &&
          entityId == other.entityId &&
          baseRevision == other.baseRevision &&
          payloadJson == other.payloadJson &&
          attempts == other.attempts;

  @override
  int get hashCode => Object.hash(
        id,
        scope,
        entityType,
        entityId,
        baseRevision,
        payloadJson,
        attempts,
      );

  @override
  String toString() =>
      'SyncOperation($scope/$entityType/$entityId base=$baseRevision attempts=$attempts)';
}
