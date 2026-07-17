export type CampaignEntityType = "actor" | "content";

export type CampaignChangeOperation = "upsert" | "delete";

export interface CampaignChangeRecord {
  id: string;
  campaignId: string;
  cursor: string;
  entityType: CampaignEntityType;
  entityId: string;
  operation: CampaignChangeOperation;
  revision: number;
  createdAt: string;
  entity?: Record<string, unknown> | null;
}

export interface CampaignChangePage {
  items: CampaignChangeRecord[];
  nextCursor: string;
  hasMore: boolean;
}

export interface CampaignActorSummary {
  id: string;
  campaignId: string;
  ownerUserId: string | null;
  sourceCharacterId: string | null;
  actorType: string;
  status: string;
  lifecycle: "persistent" | "temporary";
  sheet: Record<string, unknown>;
  revision: number;
  updatedBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface CampaignActorAuditRecord {
  id: string;
  campaignActorId: string;
  campaignId: string;
  actorUserId: string;
  baseRevision: number;
  resultRevision: number;
  changedPaths: string[];
  beforeSheet: Record<string, unknown>;
  afterSheet: Record<string, unknown>;
  createdAt: string;
}

export interface CampaignContentEntrySummary {
  id: string;
  campaignId: string;
  type: string;
  slug: string;
  name: string;
  entry: Record<string, unknown>;
  revision: number;
  createdBy: string;
  updatedBy: string;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface CampaignChangedEvent {
  campaignId: string;
  cursor: string;
  entityType: CampaignEntityType;
}

export type CampaignActorType =
  | "player"
  | "npc"
  | "unclaimed"
  | "companion"
  | "monster";

export type CampaignActorStatus = "active" | "archived";

export type CampaignRuntimeCommandType =
  | "setHp"
  | "adjustHp"
  | "setTemporaryHp"
  | "setCondition"
  | "removeCondition"
  | "setResource";

export interface CampaignRuntimeCommand {
  type: CampaignRuntimeCommandType;
  value?: unknown;
  delta?: number;
  name?: string;
  amount?: number;
}

export interface PublishActorInput {
  sourceCharacterId: string;
  actorType: CampaignActorType;
  baseRevision: number;
  sheet: Record<string, unknown>;
}

export interface CreateActorInput {
  actorType: CampaignActorType;
  ownerUserId?: string | null;
  lifecycle?: "persistent" | "temporary";
  sheet: Record<string, unknown>;
}

export interface UpdateActorInput {
  baseRevision: number;
  sheet: Record<string, unknown>;
  /**
   * Spec §完整管理: 转为常驻 — DM 可将 temporary 角色升级为 persistent。
   * 仅在 lifecycle 实际发生变化时强制 canManageActor 权限；未提供时
   * 保持原有 canEditOwnedActor 行为，避免影响玩家自编辑角色卡。
   */
  lifecycle?: "persistent" | "temporary";
}

export interface AssignActorInput {
  ownerUserId: string | null;
  baseRevision: number;
}

export interface ArchiveActorInput {
  baseRevision: number;
}

export interface RuntimeCommandInput {
  baseRevision: number;
  commands: CampaignRuntimeCommand[];
}

export interface CreateContentEntryInput {
  type: string;
  slug: string;
  name: string;
  entry: Record<string, unknown>;
}

export interface UpdateContentEntryInput {
  baseRevision: number;
  entry: Record<string, unknown>;
}

export interface ContentValidationReport {
  valid: boolean;
  errors: ContentValidationError[];
}

export interface ContentValidationError {
  path: string;
  message: string;
}
