import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import type { Prisma } from "@prisma/client";
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
    } = await this.prismaService.$transaction(async (tx) => {
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
          } as Prisma.InputJsonValue,
        },
      });
      return { row: result, cursor: change.cursor, messageRow: message };
    });

    this.gateway.broadcastChange({
      campaignId,
      entityType: "character",
      cursor,
    });
    const eventView = toEventView(messageRow);
    this.gateway.broadcastToCampaign(
      campaignId,
      "campaign:message:new",
      eventView,
    );

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
    } = await this.prismaService.$transaction(async (tx) => {
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
          } as Prisma.InputJsonValue,
        },
      });
      return { row: result, cursor: change.cursor, messageRow: message };
    });

    this.gateway.broadcastChange({
      campaignId,
      entityType: "character",
      cursor,
    });
    const eventView = toEventView(messageRow);
    this.gateway.broadcastToCampaign(
      campaignId,
      "campaign:message:new",
      eventView,
    );

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
    } = await this.prismaService.$transaction(async (tx) => {
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
          } as Prisma.InputJsonValue,
        },
      });
      return { row: result, cursor: change.cursor, messageRow: message };
    });

    this.gateway.broadcastChange({
      campaignId,
      entityType: "character",
      cursor,
    });
    const eventView = toEventView(messageRow);
    this.gateway.broadcastToCampaign(
      campaignId,
      "campaign:message:new",
      eventView,
    );

    return {
      character: toCharacterSummary(updatedRow),
      event: eventView,
    };
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
