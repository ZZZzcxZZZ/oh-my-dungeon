export interface VaultPushOperation {
  operationId: string;
  entityType: string;
  entityId: string;
  baseRevision: number;
  operation: "upsert" | "delete";
  payload: Record<string, unknown>;
}

export interface VaultConflict {
  entityId: string;
  currentRevision: number;
}

export interface VaultPushResult {
  applied: string[];
  skipped: string[];
  conflicts: VaultConflict[];
}

export interface VaultChangeRow {
  cursor: string;
  userId: string;
  entityType: string;
  entityId: string;
  operation: string;
  payload: Record<string, unknown>;
  revision: number;
  createdAt: string;
}

export interface VaultChangePage {
  cursor: string;
  changes: VaultChangeRow[];
  hasMore: boolean;
}

export interface VaultDeviceView {
  deviceId: string;
  name: string;
  platform: string;
  lastCursor: string;
  lastSeenAt: string;
  revokedAt: string | null;
}
