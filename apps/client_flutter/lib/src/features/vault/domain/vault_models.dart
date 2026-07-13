/// Personal Vault 跨设备同步的领域模型。
///
/// [VaultSession.accessToken] 仅用于 HTTP 头，不得写入 Drift 或日志。
class VaultSession {
  const VaultSession({
    required this.remoteUserId,
    required this.deviceId,
    required this.baseUrl,
    required this.accessToken,
  });
  final String remoteUserId;
  final String deviceId;
  final String baseUrl;
  final String accessToken;
}

/// 来自远端 Vault 的单条变更。`cursor` 是该变更在用户流水线中的单调位置。
class VaultChange {
  const VaultChange({
    required this.cursor,
    required this.operation,
    required this.entityType,
    required this.entityId,
    required this.revision,
    required this.payloadJson,
  });
  final String cursor;
  final String operation; // "upsert" or "delete"
  final String entityType;
  final String entityId;
  final int revision;
  final String payloadJson;
}

/// `GET /vault/changes` 的一页结果。
class VaultChangePage {
  const VaultChangePage({
    required this.cursor,
    required this.changes,
    required this.hasMore,
  });
  final String cursor;
  final List<VaultChange> changes;
  final bool hasMore;
}

/// `POST /vault/push` 的返回结果。
class VaultPushResult {
  const VaultPushResult({
    required this.applied,
    required this.skipped,
    required this.conflicts,
  });
  final List<String> applied;
  final List<String> skipped;
  final List<VaultConflict> conflicts;
}

/// 冲突详情：远端当前 revision 与本地 baseRevision 不一致。
class VaultConflict {
  const VaultConflict({required this.entityId, required this.currentRevision});
  final String entityId;
  final int currentRevision;
}

/// 推送遇到 409 时抛出，携带服务端返回的完整结果以便上层决定重试或转冲突态。
class VaultConflictException implements Exception {
  const VaultConflictException(this.result);
  final VaultPushResult result;
  @override
  String toString() =>
      'VaultConflictException: ${result.conflicts.length} conflict(s)';
}

/// 设备视图，用于设置页展示当前账户的活跃设备。
class VaultDeviceView {
  const VaultDeviceView({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.lastCursor,
    required this.lastSeenAt,
    this.revokedAt,
    this.isCurrent = false,
  });
  final String deviceId;
  final String name;
  final String platform;
  final String lastCursor;
  final String lastSeenAt;
  final String? revokedAt;
  final bool isCurrent;
}
