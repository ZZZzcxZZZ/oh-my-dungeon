import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../../prisma/prisma.service";
import { AccessTokenPayload } from "../auth/auth.types";
import {
  CampaignCharacterContext,
  CampaignContext,
  CampaignPolicy,
} from "../campaigns/policies/campaign.policy";
import { CampaignsGateway } from "../realtime/campaigns.gateway";
import { CampaignChangeService } from "./campaign-change.service";
import type {
  CampaignCharacterSummary,
  CampaignEventResult,
  AddConditionInput,
  ChangeCharacterHpInput,
  GrantItemInput,
} from "./campaign-sync.types";

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

/**
 * requestId 由客户端生成且全局唯一 (见 AI Agent 契约 §3.1).
 * 校验非空并限制长度, 避免恶意/异常客户端写入超大键.
 */
function assertRequestId(requestId: unknown): asserts requestId is string {
  if (!isNonEmptyString(requestId)) {
    throw new BadRequestException("requestId is required");
  }
  if (requestId.length > 128) {
    throw new BadRequestException(
      "requestId must be at most 128 characters",
    );
  }
}

/** Prisma 唯一约束冲突 (如并发同 requestId 撞 GameEvent.requestId). */
function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}

// ---------------------------------------------------------------------------
// Task 3.1 — CampaignEvent 事件层
//
// 把"修改 character 状态 + 追加事件消息"绑定到单一 Prisma 事务, 保证:
//   1. 状态修改与事件追加原子提交, 失败全部回滚 (无孤儿消息, 无孤儿 HP).
//   2. 事务提交后才广播, 客户端收到的事件一定已落库.
//   3. 客户端可通过 eventData.eventType 字段分发渲染 (BG3 风格系统日志).
// ---------------------------------------------------------------------------

const HP_EVENT_TYPE = "character.hp_changed";
const ITEM_EVENT_TYPE = "character.item_granted";
const CONDITION_EVENT_TYPE = "character.condition_added";

// GameEvent 操作类型 (与 AI Agent 契约的事件类型一致, findReplay 按此限定).
const HP_OPERATION_TYPE = "character.hp.adjusted";
const ITEM_OPERATION_TYPE = "character.item.granted";
const CONDITION_OPERATION_TYPE = "character.condition.added";

interface InventoryEntry {
  id: string;
  itemId: string;
  templateRef: string;
  name: string;
  quantity: number;
  equipped: boolean;
  attuned: boolean;
  instanceData: Record<string, unknown>;
}

@Injectable()
export class CampaignEventsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly policy: CampaignPolicy,
    private readonly changeService: CampaignChangeService,
    private readonly gateway: CampaignsGateway,
  ) {}

  /**
   * 原子操作: 调整 character HP + 追加 character.hp_changed 事件消息.
   * delta < 0 为伤害 (clamp 到 0), > 0 为治疗 (clamp 到 maxHp, 若 maxHp 有效).
   * 同事务内: character update + audit + change record + chat message.
   */
  async changeCharacterHp(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: ChangeCharacterHpInput,
  ): Promise<CampaignEventResult> {
    assertRequestId(input.requestId);
    if (
      typeof input.delta !== "number" ||
      !Number.isFinite(input.delta) ||
      input.delta === 0
    ) {
      throw new BadRequestException("delta must be a non-zero finite number");
    }
    const reason =
      typeof input.reason === "string" && input.reason.trim().length > 0
        ? input.reason.trim()
        : null;

    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    if (
      input.baseRevision !== undefined &&
      row.revision !== input.baseRevision
    ) {
      throw conflict(row);
    }
    this.policy.canManageCharacter(user, ctx);

    const beforeSheet = (row.sheetJson ?? {}) as Record<string, unknown>;
    const currentHp = toInt(beforeSheet.currentHp);
    const maxHp = toInt(beforeSheet.maxHp);
    const characterName =
      typeof beforeSheet.name === "string" && beforeSheet.name.trim()
        ? beforeSheet.name.trim()
        : "Unnamed character";

    const rawNext = currentHp + input.delta;
    const clampedNext =
      input.delta < 0
        ? Math.max(0, rawNext)
        : maxHp > 0
          ? Math.min(maxHp, rawNext)
          : rawNext;
    const actualDelta = clampedNext - currentHp;

    if (actualDelta === 0) {
      // clamp 后无变化 (例如已满血治疗, 或已倒下继续伤害), 仍要拒绝避免空消息.
      throw new BadRequestException(
        "HP change has no effect after clamping (already at floor or ceiling)",
      );
    }

    const afterSheet: Record<string, unknown> = {
      ...beforeSheet,
      currentHp: clampedNext,
    };
    const nextRevision = row.revision + 1;
    const changedPaths = ["currentHp"];

    const {
      row: updatedRow,
      cursor,
      messageRow,
    } = await this.runIdempotentMutation(
      input.requestId,
      campaignId,
      HP_OPERATION_TYPE,
      async (tx) => {
      // 幂等锚: 相同 requestId 已执行过则直接重放首次结果, 不重复扣血.
      const replay = await this.findReplay(
        tx,
        input.requestId,
        campaignId,
        HP_OPERATION_TYPE,
      );
      if (replay) return replay;
      const result = await tx.campaignCharacter.update({
        where: { id: characterId },
        data: {
          sheetJson: afterSheet as unknown as Prisma.InputJsonValue,
          revision: nextRevision,
          updatedBy: user.userId,
        },
      });
      await tx.campaignCharacterAudit.create({
        data: {
          campaignCharacterId: characterId,
          campaignId,
          characterUserId: user.userId,
          baseRevision: row.revision,
          resultRevision: nextRevision,
          changedPaths: changedPaths as unknown as Prisma.InputJsonValue,
          beforeJson: beforeSheet as unknown as Prisma.InputJsonValue,
          afterJson: afterSheet as unknown as Prisma.InputJsonValue,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx as unknown as Parameters<
          typeof this.changeService.recordInTransaction
        >[0],
        campaignId,
        "character",
        characterId,
        "upsert",
        nextRevision,
      );
      const message = await tx.campaignChatMessage.create({
        data: {
          campaignId,
          senderId: user.userId,
          campaignCharacterId: null,
          displayName: "旁白",
          speakerMode: "narrator",
          ooc: false,
          kind: "system",
          content: formatHpMessage(
            characterName,
            actualDelta,
            currentHp,
            clampedNext,
          ),
          eventData: {
            eventType: HP_EVENT_TYPE,
            characterId,
            characterName,
            delta: actualDelta,
            from: currentHp,
            to: clampedNext,
            reason,
            requestId: input.requestId,
          } as Prisma.InputJsonValue,
        },
      });
      await this.recordOperationEvent(tx, {
        requestId: input.requestId,
        type: HP_OPERATION_TYPE,
        campaignId,
        characterId,
        userId: user.userId,
        before: { currentHp, maxHp },
        after: { currentHp: clampedNext, maxHp },
        payload: { delta: actualDelta },
      });
      return { row: result, cursor: change.cursor, messageRow: message };
    });

    // 幂等重放 (cursor 为 null) 时不重复广播: 首次执行已广播过消息与变更游标.
    if (cursor !== null) {
      this.gateway.broadcastChange({
        campaignId,
        entityType: "character",
        cursor,
      });
      this.gateway.broadcastToCampaign(
        campaignId,
        "campaign:message:new",
        toEventView(messageRow),
      );
    }
    const eventView = toEventView(messageRow);
    return {
      character: toCharacterSummary(updatedRow),
      event: eventView,
    };
  }

  /**
   * 原子操作: 给予 character 物品 + 追加 character.item_granted 事件消息.
   * 若 inventory 已含相同 itemId, 累加数量; 否则追加新条目.
   */
  async grantItem(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: GrantItemInput,
  ): Promise<CampaignEventResult> {
    assertRequestId(input.requestId);
    if (typeof input.itemId !== "string" || input.itemId.trim().length === 0) {
      throw new BadRequestException("itemId is required");
    }
    if (typeof input.name !== "string" || input.name.trim().length === 0) {
      throw new BadRequestException("name is required");
    }
    const quantity =
      input.quantity === undefined
        ? 1
        : typeof input.quantity === "number" &&
            Number.isInteger(input.quantity) &&
            input.quantity > 0
          ? input.quantity
          : NaN;
    if (!Number.isFinite(quantity)) {
      throw new BadRequestException(
        "quantity must be a positive integer (default 1)",
      );
    }

    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    if (
      input.baseRevision !== undefined &&
      row.revision !== input.baseRevision
    ) {
      throw conflict(row);
    }
    this.policy.canManageCharacter(user, ctx);

    const beforeSheet = (row.sheetJson ?? {}) as Record<string, unknown>;
    const characterName =
      typeof beforeSheet.name === "string" && beforeSheet.name.trim()
        ? beforeSheet.name.trim()
        : "Unnamed character";
    const beforeInventory = readInventory(beforeSheet.inventory);
    const existingIdx = beforeInventory.findIndex(
      (entry) => entry.itemId === input.itemId,
    );
    let afterInventory: InventoryEntry[];
    if (existingIdx >= 0) {
      afterInventory = beforeInventory.map((entry, idx) =>
        idx === existingIdx
          ? { ...entry, quantity: entry.quantity + quantity }
          : entry,
      );
    } else {
      afterInventory = [
        ...beforeInventory,
        {
          id: input.itemId,
          itemId: input.itemId,
          templateRef: input.itemId,
          name: input.name.trim(),
          quantity,
          equipped: false,
          attuned: false,
          instanceData: {},
        },
      ];
    }
    const afterSheet: Record<string, unknown> = {
      ...beforeSheet,
      inventory: afterInventory,
    };
    const nextRevision = row.revision + 1;
    const changedPaths = ["inventory"];

    const {
      row: updatedRow,
      cursor,
      messageRow,
    } = await this.runIdempotentMutation(
      input.requestId,
      campaignId,
      ITEM_OPERATION_TYPE,
      async (tx) => {
      // 幂等锚: 相同 requestId 已执行过则直接重放首次结果, 不重复发物品.
      const replay = await this.findReplay(
        tx,
        input.requestId,
        campaignId,
        ITEM_OPERATION_TYPE,
      );
      if (replay) return replay;
      const result = await tx.campaignCharacter.update({
        where: { id: characterId },
        data: {
          sheetJson: afterSheet as unknown as Prisma.InputJsonValue,
          revision: nextRevision,
          updatedBy: user.userId,
        },
      });
      await tx.campaignCharacterAudit.create({
        data: {
          campaignCharacterId: characterId,
          campaignId,
          characterUserId: user.userId,
          baseRevision: row.revision,
          resultRevision: nextRevision,
          changedPaths: changedPaths as unknown as Prisma.InputJsonValue,
          beforeJson: beforeSheet as unknown as Prisma.InputJsonValue,
          afterJson: afterSheet as unknown as Prisma.InputJsonValue,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx as unknown as Parameters<
          typeof this.changeService.recordInTransaction
        >[0],
        campaignId,
        "character",
        characterId,
        "upsert",
        nextRevision,
      );
      const message = await tx.campaignChatMessage.create({
        data: {
          campaignId,
          senderId: user.userId,
          campaignCharacterId: null,
          displayName: "旁白",
          speakerMode: "narrator",
          ooc: false,
          kind: "system",
          content: formatItemMessage(
            characterName,
            input.name.trim(),
            quantity,
          ),
          eventData: {
            eventType: ITEM_EVENT_TYPE,
            characterId,
            characterName,
            itemId: input.itemId,
            itemName: input.name.trim(),
            quantity,
            requestId: input.requestId,
          } as Prisma.InputJsonValue,
        },
      });
      await this.recordOperationEvent(tx, {
        requestId: input.requestId,
        type: ITEM_OPERATION_TYPE,
        campaignId,
        characterId,
        userId: user.userId,
        before: { inventory: beforeInventory },
        after: { inventory: afterInventory },
        payload: { itemId: input.itemId, quantity },
      });
      return { row: result, cursor: change.cursor, messageRow: message };
    });

    // 幂等重放 (cursor 为 null) 时不重复广播: 首次执行已广播过消息与变更游标.
    if (cursor !== null) {
      this.gateway.broadcastChange({
        campaignId,
        entityType: "character",
        cursor,
      });
      this.gateway.broadcastToCampaign(
        campaignId,
        "campaign:message:new",
        toEventView(messageRow),
      );
    }
    const eventView = toEventView(messageRow);
    return {
      character: toCharacterSummary(updatedRow),
      event: eventView,
    };
  }

  /**
   * 原子操作: 给予结构化状态 + 追加 character.condition_added 事件消息.
   */
  async addCondition(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: AddConditionInput,
  ): Promise<CampaignEventResult> {
    assertRequestId(input.requestId);
    const type = input.type.trim();
    const name = input.name.trim();
    if (!type) throw new BadRequestException("type is required");
    if (!name) throw new BadRequestException("name is required");
    const durationRounds =
      input.durationRounds === undefined
        ? undefined
        : Number.isInteger(input.durationRounds) && input.durationRounds > 0
          ? input.durationRounds
          : NaN;
    if (Number.isNaN(durationRounds)) {
      throw new BadRequestException(
        "durationRounds must be a positive integer",
      );
    }

    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    if (
      input.baseRevision !== undefined &&
      row.revision !== input.baseRevision
    ) {
      throw conflict(row);
    }
    this.policy.canManageCharacter(user, ctx);

    const beforeSheet = (row.sheetJson ?? {}) as Record<string, unknown>;
    const characterName =
      typeof beforeSheet.name === "string" && beforeSheet.name.trim()
        ? beforeSheet.name.trim()
        : "Unnamed character";
    const beforeConditions = Array.isArray(beforeSheet.conditions)
      ? beforeSheet.conditions
      : [];
    const condition = {
      id: randomUUID(),
      type,
      name,
      source: { type: "user", id: user.userId },
      duration:
        durationRounds === undefined
          ? null
          : {
              unit: "round",
              total: durationRounds,
              remaining: durationRounds,
            },
      removable: true,
    };
    const afterSheet: Record<string, unknown> = {
      ...beforeSheet,
      conditions: [...beforeConditions, condition],
    };
    const nextRevision = row.revision + 1;
    const changedPaths = ["conditions"];

    const {
      row: updatedRow,
      cursor,
      messageRow,
    } = await this.runIdempotentMutation(
      input.requestId,
      campaignId,
      CONDITION_OPERATION_TYPE,
      async (tx) => {
      // 幂等锚: 相同 requestId 已执行过则直接重放首次结果, 不重复加状态.
      const replay = await this.findReplay(
        tx,
        input.requestId,
        campaignId,
        CONDITION_OPERATION_TYPE,
      );
      if (replay) return replay;
      const result = await tx.campaignCharacter.update({
        where: { id: characterId },
        data: {
          sheetJson: afterSheet as unknown as Prisma.InputJsonValue,
          revision: nextRevision,
          updatedBy: user.userId,
        },
      });
      await tx.campaignCharacterAudit.create({
        data: {
          campaignCharacterId: characterId,
          campaignId,
          characterUserId: user.userId,
          baseRevision: row.revision,
          resultRevision: nextRevision,
          changedPaths: changedPaths as unknown as Prisma.InputJsonValue,
          beforeJson: beforeSheet as unknown as Prisma.InputJsonValue,
          afterJson: afterSheet as unknown as Prisma.InputJsonValue,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx as unknown as Parameters<
          typeof this.changeService.recordInTransaction
        >[0],
        campaignId,
        "character",
        characterId,
        "upsert",
        nextRevision,
      );
      const message = await tx.campaignChatMessage.create({
        data: {
          campaignId,
          senderId: user.userId,
          campaignCharacterId: null,
          displayName: "旁白",
          speakerMode: "narrator",
          ooc: false,
          kind: "system",
          content: formatConditionMessage(characterName, name, durationRounds),
          eventData: {
            eventType: CONDITION_EVENT_TYPE,
            characterId,
            characterName,
            conditionId: condition.id,
            conditionType: type,
            conditionName: name,
            durationRounds: durationRounds ?? null,
            requestId: input.requestId,
          } as Prisma.InputJsonValue,
        },
      });
      await this.recordOperationEvent(tx, {
        requestId: input.requestId,
        type: CONDITION_OPERATION_TYPE,
        campaignId,
        characterId,
        userId: user.userId,
        before: { conditions: beforeConditions },
        after: { conditions: [...beforeConditions, condition] },
        payload: { conditionId: condition.id },
      });
      return { row: result, cursor: change.cursor, messageRow: message };
    });

    // 幂等重放 (cursor 为 null) 时不重复广播: 首次执行已广播过消息与变更游标.
    if (cursor !== null) {
      this.gateway.broadcastChange({
        campaignId,
        entityType: "character",
        cursor,
      });
      this.gateway.broadcastToCampaign(
        campaignId,
        "campaign:message:new",
        toEventView(messageRow),
      );
    }
    const eventView = toEventView(messageRow);
    return {
      character: toCharacterSummary(updatedRow),
      event: eventView,
    };
  }

  /**
   * 在单一事务内执行角色状态变更, 并保证 requestId 幂等:
   * - 事务内先查重放, 存在则直接返回首次结果, 不重复写状态;
   * - 并发同 requestId 时, 后提交者撞 GameEvent.requestId 唯一约束 (P2002),
   *   事务整体回滚; 这里在事务外重查一次并返回先提交者的首次结果,
   *   客户端得到正常重放响应而不是 500.
   */
  private async runIdempotentMutation(
    requestId: string,
    campaignId: string,
    expectedType: string,
    execute: (tx: Prisma.TransactionClient) => Promise<MutationResult>,
  ): Promise<MutationResult> {
    try {
      return await this.prismaService.$transaction((tx) => execute(tx));
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      const replay = await this.findReplay(
        this.prismaService,
        requestId,
        campaignId,
        expectedType,
      );
      if (replay) return replay;
      throw error;
    }
  }

  /**
   * 幂等重放: 相同 requestId 已在 GameEvent 表中执行过时, 返回首次执行的
   * 结果快照 (当前 character + 首次事件消息), 调用方不再重复写状态.
   * 只匹配与本次操作相同的 GameEvent 类型; requestId 被其他操作复用时报 400
   * (requestId 全局唯一, 见 AI Agent 契约 §3.1).
   */
  private async findReplay(
    client: Prisma.TransactionClient | PrismaService,
    requestId: string,
    campaignId: string,
    expectedType: string,
  ): Promise<MutationResult | null> {
    const existing = await client.gameEvent.findUnique({
      where: { requestId },
    });
    if (!existing) return null;
    if (existing.type !== expectedType) {
      throw new BadRequestException(
        `requestId ${requestId} was already used by a different operation`,
      );
    }
    const messageRow = await client.campaignChatMessage.findFirst({
      where: {
        campaignId,
        eventData: { path: ["requestId"], equals: requestId },
      },
      orderBy: { createdAt: "desc" },
    });
    if (!messageRow) return null;
    const row = await client.campaignCharacter.findUnique({
      where: { id: existing.characterId ?? "" },
    });
    if (!row || row.campaignId !== campaignId) return null;
    return { row, cursor: null, messageRow };
  }

  /**
   * 结构化操作事件 (GameEvent, requestId 唯一)。与 AI 契约的操作事件
   * 对齐: 重试不重复扣血/发物品/加状态, 并可供事件查询接口审计。
   */
  private async recordOperationEvent(
    tx: Prisma.TransactionClient,
    input: {
      requestId: string;
      type: string;
      campaignId: string;
      characterId: string;
      userId: string;
      before: Record<string, unknown>;
      after: Record<string, unknown>;
      payload: Record<string, unknown>;
    },
  ): Promise<void> {
    await tx.gameEvent.create({
      data: {
        schemaVersion: 1,
        type: input.type,
        campaignId: input.campaignId,
        characterId: input.characterId,
        initiatorType: "user",
        initiatorId: input.userId,
        requestId: input.requestId,
        targets: [{ type: "character", id: input.characterId }] as unknown as Prisma.InputJsonValue,
        before: input.before as Prisma.InputJsonValue,
        after: input.after as Prisma.InputJsonValue,
        payload: input.payload as Prisma.InputJsonValue,
      },
    });
  }

  private async loadCharacter(
    campaignId: string,
    characterId: string,
  ): Promise<{ row: CharacterRow; ctx: CampaignCharacterContext }> {
    const campaign = await this.fetchCampaignContext(campaignId);
    const row = await this.prismaService.campaignCharacter.findUnique({
      where: { id: characterId },
    });
    if (!row || row.campaignId !== campaignId) {
      throw new NotFoundException("Campaign character not found");
    }
    return {
      row,
      ctx: {
        campaignId: campaign.campaignId,
        ownerId: campaign.ownerId,
        members: campaign.members,
        characterId: row.id,
        characterOwnerUserId: row.ownerUserId,
        characterSourceCharacterId: row.sourceCharacterId,
        characterRevision: row.revision,
      },
    };
  }

  private async fetchCampaignContext(
    campaignId: string,
  ): Promise<CampaignContext> {
    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true },
    });
    if (!campaign) {
      throw new NotFoundException("Campaign not found");
    }
    return {
      campaignId: campaign.id,
      ownerId: campaign.ownerId,
      members: campaign.members.map((member: any) => ({
        userId: member.userId,
        role: member.role,
      })),
    };
  }
}

interface CharacterRow {
  id: string;
  campaignId: string;
  ownerUserId: string | null;
  sourceCharacterId: string | null;
  characterType: string;
  status: string;
  lifecycle?: string;
  visibleToPlayers?: boolean;
  sheetJson: unknown;
  revision: number;
  updatedBy: string;
  createdAt: Date;
  updatedAt: Date;
}

/** 单次角色状态变更的结果: row 为最新角色行, cursor 为空表示幂等重放. */
interface MutationResult {
  row: CharacterRow;
  cursor: string | null;
  messageRow: unknown;
}

function toCharacterSummary(row: CharacterRow): CampaignCharacterSummary {
  return {
    id: row.id,
    campaignId: row.campaignId,
    ownerUserId: row.ownerUserId,
    sourceCharacterId: row.sourceCharacterId,
    characterType: row.characterType,
    status: row.status,
    lifecycle: row.lifecycle === "temporary" ? "temporary" : "persistent",
    visibleToPlayers:
      row.characterType === "player" || row.visibleToPlayers === true,
    sheet: (row.sheetJson ?? {}) as Record<string, unknown>,
    revision: row.revision,
    updatedBy: row.updatedBy,
    createdAt: toIso(row.createdAt),
    updatedAt: toIso(row.updatedAt),
  };
}

function toEventView(message: any) {
  return {
    id: message.id,
    campaignId: message.campaignId,
    senderId: message.senderId,
    campaignCharacterId: message.campaignCharacterId ?? null,
    displayName: message.displayName,
    speakerMode: message.speakerMode,
    ooc: message.ooc === true,
    kind: message.kind,
    content: message.content,
    eventData:
      message.eventData && typeof message.eventData === "object"
        ? (message.eventData as Record<string, unknown>)
        : {},
    createdAt: toIso(message.createdAt),
  };
}

function toIso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : value;
}

function toInt(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    if (!Number.isNaN(parsed)) return parsed;
  }
  return 0;
}

function readInventory(value: unknown): InventoryEntry[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => {
      if (!entry || typeof entry !== "object") return null;
      const record = entry as Record<string, unknown>;
      const itemId =
        typeof record.templateRef === "string"
          ? record.templateRef
          : typeof record.itemId === "string"
            ? record.itemId
            : "";
      const id =
        typeof record.id === "string" && record.id.trim() ? record.id : itemId;
      const name = typeof record.name === "string" ? record.name : "";
      const quantity = toInt(record.quantity);
      if (!itemId) return null;
      const instanceData =
        record.instanceData &&
        typeof record.instanceData === "object" &&
        !Array.isArray(record.instanceData)
          ? (record.instanceData as Record<string, unknown>)
          : {};
      return {
        id,
        itemId,
        templateRef: itemId,
        name,
        quantity,
        equipped: record.equipped === true,
        attuned: record.attuned === true,
        instanceData,
      } satisfies InventoryEntry;
    })
    .filter((entry): entry is InventoryEntry => entry !== null);
}

function formatHpMessage(
  characterName: string,
  delta: number,
  from: number,
  to: number,
): string {
  const sign = delta >= 0 ? "+" : "";
  return `${characterName} ${sign}${delta} HP (${from} → ${to})`;
}

function formatItemMessage(
  characterName: string,
  itemName: string,
  quantity: number,
): string {
  return `给 ${characterName} ${itemName} ×${quantity}`;
}

function formatConditionMessage(
  characterName: string,
  conditionName: string,
  durationRounds?: number,
): string {
  const duration =
    durationRounds === undefined ? "" : `（${durationRounds} 轮）`;
  return `${characterName} 获得状态：${conditionName}${duration}`;
}

function conflict(row: CharacterRow): ConflictException {
  return new ConflictException({
    message: "Character revision conflict",
    current: toCharacterSummary(row),
  });
}
