export type CampaignEntityType = "character" | "content";

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

export interface CampaignCharacterSummary {
  id: string;
  campaignId: string;
  ownerUserId: string | null;
  sourceCharacterId: string | null;
  characterType: string;
  status: string;
  lifecycle: "persistent" | "temporary";
  visibleToPlayers: boolean;
  sheet: Record<string, unknown>;
  revision: number;
  updatedBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface CampaignCharacterAuditRecord {
  id: string;
  campaignCharacterId: string;
  campaignId: string;
  characterUserId: string;
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

export type CampaignCharacterType =
  "player" | "npc" | "unclaimed" | "companion" | "monster";

export type CampaignCharacterStatus = "active" | "archived";

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

export interface PublishCharacterInput {
  sourceCharacterId: string;
  characterType: CampaignCharacterType;
  baseRevision: number;
  sheet: Record<string, unknown>;
}

export interface CreateCharacterInput {
  characterType: CampaignCharacterType;
  ownerUserId?: string | null;
  lifecycle?: "persistent" | "temporary";
  visibleToPlayers?: boolean;
  sheet: Record<string, unknown>;
}

export interface UpdateCharacterInput {
  baseRevision: number;
  sheet: Record<string, unknown>;
  visibleToPlayers?: boolean;
  /**
   * Spec §完整管理: 转为常驻 — DM 可将 temporary 角色升级为 persistent。
   * 仅在 lifecycle 实际发生变化时强制 canManageCharacter 权限；未提供时
   * 保持原有 canEditOwnedCharacter 行为，避免影响玩家自编辑角色卡。
   */
  lifecycle?: "persistent" | "temporary";
}

export interface AssignCharacterInput {
  ownerUserId: string | null;
  baseRevision: number;
}

export interface ArchiveCharacterInput {
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

// ---------------------------------------------------------------------------
// Task 3.1 — CampaignEvent 事件层类型
//
// 这些类型形式化战役事件的命名空间, 用于在 kind='system' 消息的 eventData
// 字段中区分事件类型. 服务端持久化仍使用现有 CampaignChatMessage 表, 不需要
// schema 迁移; 客户端可通过 eventData.eventType 字段分发渲染.
// ---------------------------------------------------------------------------

/**
 * 战役事件类型枚举 (最小集合). 沿用路线图第三节定义的命名空间:
 *   message.* / roll.* / character.* / archive.* / system.*
 * 当前已实现: character.hp_changed, character.item_granted.
 * 已有但未形式化的 kind (say/action/roll/checkRequest/archivePublished)
 * 保留原 kind 字段, 不强制改名为 message.say 等, 避免破坏存量数据.
 */
export type CampaignEventKind =
  | "message.say"
  | "message.act"
  | "message.narration"
  | "roll.dice"
  | "roll.check"
  | "roll.save"
  | "roll.initiative"
  | "character.hp_changed"
  | "character.item_granted"
  | "character.condition_added"
  | "archive.published"
  | "system.notice";

/** HP 变化事件 payload. 存储在 CampaignChatMessage.eventData 中. */
export interface CharacterHpChangedEvent {
  eventType: "character.hp_changed";
  characterId: string;
  characterName: string;
  /** 客户端请求的原始 delta (可被 clamp 修正). */
  delta: number;
  /** clamp 前的 currentHp. */
  from: number;
  /** clamp 后的 currentHp. */
  to: number;
  /** 可选的 DM 备注 (例如伤害来源). */
  reason: string | null;
}

/** 给予物品事件 payload. */
export interface CharacterItemGrantedEvent {
  eventType: "character.item_granted";
  characterId: string;
  characterName: string;
  itemId: string;
  itemName: string;
  quantity: number;
}

/** HP 变化请求. delta < 0 为伤害, > 0 为治疗, 0 拒绝. */
export interface ChangeCharacterHpInput {
  /** 客户端生成的唯一请求 id；相同 requestId 重试只执行一次（幂等）。 */
  requestId: string;
  delta: number;
  /** 可选 DM 备注. */
  reason?: string;
  /** 可选乐观锁; 提供时必须与当前 character revision 一致. */
  baseRevision?: number;
}

/** 给予物品请求. */
export interface GrantItemInput {
  /** 客户端生成的唯一请求 id；相同 requestId 重试只执行一次（幂等）。 */
  requestId: string;
  itemId: string;
  name: string;
  /** 默认 1. 必须是正整数. */
  quantity?: number;
  /** 可选乐观锁. */
  baseRevision?: number;
}

export interface AddConditionInput {
  /** 客户端生成的唯一请求 id；相同 requestId 重试只执行一次（幂等）。 */
  requestId: string;
  type: string;
  name: string;
  /** 可选持续轮数. 必须为正整数. */
  durationRounds?: number;
  /** 可选乐观锁. */
  baseRevision?: number;
}

/** 原子事件操作的返回: 同时返回更新后的 character 和追加的事件消息. */
export interface CampaignEventResult {
  character: CampaignCharacterSummary;
  /** kind='system' 的 CampaignChatMessage view. */
  event: {
    id: string;
    campaignId: string;
    senderId: string;
    campaignCharacterId: string | null;
    displayName: string;
    speakerMode: string;
    ooc: boolean;
    kind: string;
    content: string;
    eventData: Record<string, unknown>;
    createdAt: string;
  };
}
