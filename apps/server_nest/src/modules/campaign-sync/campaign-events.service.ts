import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import type { Prisma } from "@prisma/client";
import { PrismaService } from "../../prisma/prisma.service";
import { AccessTokenPayload } from "../auth/auth.types";
import {
  CampaignActorContext,
  CampaignContext,
  CampaignPolicy,
} from "../campaigns/policies/campaign.policy";
import { CampaignsGateway } from "../realtime/campaigns.gateway";
import { CampaignChangeService } from "./campaign-change.service";
import type {
  CampaignActorSummary,
  CampaignEventResult,
  ChangeActorHpInput,
  GrantItemInput,
} from "./campaign-sync.types";

// ---------------------------------------------------------------------------
// Task 3.1 — CampaignEvent 事件层
//
// 把"修改 actor 状态 + 追加事件消息"绑定到单一 Prisma 事务, 保证:
//   1. 状态修改与事件追加原子提交, 失败全部回滚 (无孤儿消息, 无孤儿 HP).
//   2. 事务提交后才广播, 客户端收到的事件一定已落库.
//   3. 客户端可通过 eventData.eventType 字段分发渲染 (BG3 风格系统日志).
// ---------------------------------------------------------------------------

const HP_EVENT_TYPE = "actor.hp_changed";
const ITEM_EVENT_TYPE = "actor.item_granted";

interface InventoryEntry {
  itemId: string;
  name: string;
  quantity: number;
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
   * 原子操作: 调整 actor HP + 追加 actor.hp_changed 事件消息.
   * delta < 0 为伤害 (clamp 到 0), > 0 为治疗 (clamp 到 maxHp, 若 maxHp 有效).
   * 同事务内: actor update + audit + change record + chat message.
   */
  async changeActorHp(
    actor: AccessTokenPayload,
    campaignId: string,
    actorId: string,
    input: ChangeActorHpInput,
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

    const { row, ctx } = await this.loadActor(campaignId, actorId);
    if (input.baseRevision !== undefined && row.revision !== input.baseRevision) {
      throw conflict(row);
    }
    this.policy.canManageActor(actor, ctx);

    const beforeSheet = (row.sheetJson ?? {}) as Record<string, unknown>;
    const currentHp = toInt(beforeSheet.currentHp);
    const maxHp = toInt(beforeSheet.maxHp);
    const actorName =
      typeof beforeSheet.name === "string" && beforeSheet.name.trim()
        ? beforeSheet.name.trim()
        : "Unnamed actor";

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

    const { row: updatedRow, cursor, messageRow } = await this.prismaService.$transaction(
      async (tx) => {
        const result = await tx.campaignActor.update({
          where: { id: actorId },
          data: {
            sheetJson: afterSheet as unknown as Prisma.InputJsonValue,
            revision: nextRevision,
            updatedBy: actor.userId,
          },
        });
        await tx.campaignActorAudit.create({
          data: {
            campaignActorId: actorId,
            campaignId,
            actorUserId: actor.userId,
            baseRevision: row.revision,
            resultRevision: nextRevision,
            changedPaths: changedPaths as unknown as Prisma.InputJsonValue,
            beforeJson: beforeSheet as unknown as Prisma.InputJsonValue,
            afterJson: afterSheet as unknown as Prisma.InputJsonValue,
          },
        });
        const change = await this.changeService.recordInTransaction(
          tx as unknown as Parameters<typeof this.changeService.recordInTransaction>[0],
          campaignId,
          "actor",
          actorId,
          "upsert",
          nextRevision,
        );
        const message = await tx.campaignChatMessage.create({
          data: {
            campaignId,
            senderId: actor.userId,
            campaignActorId: actorId,
            displayName: actor.username,
            speakerMode: "actor",
            ooc: false,
            kind: "system",
            content: formatHpMessage(actorName, actualDelta, currentHp, clampedNext),
            eventData: {
              eventType: HP_EVENT_TYPE,
              actorId,
              actorName,
              delta: actualDelta,
              from: currentHp,
              to: clampedNext,
              reason,
            } as Prisma.InputJsonValue,
          },
        });
        return { row: result, cursor: change.cursor, messageRow: message };
      },
    );

    this.gateway.broadcastChange({ campaignId, entityType: "actor", cursor });
    const eventView = toEventView(messageRow);
    this.gateway.broadcastToCampaign(campaignId, "campaign:message:new", eventView);

    return {
      actor: toActorSummary(updatedRow),
      event: eventView,
    };
  }

  /**
   * 原子操作: 给予 actor 物品 + 追加 actor.item_granted 事件消息.
   * 若 inventory 已含相同 itemId, 累加数量; 否则追加新条目.
   */
  async grantItem(
    actor: AccessTokenPayload,
    campaignId: string,
    actorId: string,
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

    const { row, ctx } = await this.loadActor(campaignId, actorId);
    if (input.baseRevision !== undefined && row.revision !== input.baseRevision) {
      throw conflict(row);
    }
    this.policy.canManageActor(actor, ctx);

    const beforeSheet = (row.sheetJson ?? {}) as Record<string, unknown>;
    const actorName =
      typeof beforeSheet.name === "string" && beforeSheet.name.trim()
        ? beforeSheet.name.trim()
        : "Unnamed actor";
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
        { itemId: input.itemId, name: input.name.trim(), quantity },
      ];
    }
    const afterSheet: Record<string, unknown> = {
      ...beforeSheet,
      inventory: afterInventory,
    };
    const nextRevision = row.revision + 1;
    const changedPaths = ["inventory"];

    const { row: updatedRow, cursor, messageRow } = await this.prismaService.$transaction(
      async (tx) => {
        const result = await tx.campaignActor.update({
          where: { id: actorId },
          data: {
            sheetJson: afterSheet as unknown as Prisma.InputJsonValue,
            revision: nextRevision,
            updatedBy: actor.userId,
          },
        });
        await tx.campaignActorAudit.create({
          data: {
            campaignActorId: actorId,
            campaignId,
            actorUserId: actor.userId,
            baseRevision: row.revision,
            resultRevision: nextRevision,
            changedPaths: changedPaths as unknown as Prisma.InputJsonValue,
            beforeJson: beforeSheet as unknown as Prisma.InputJsonValue,
            afterJson: afterSheet as unknown as Prisma.InputJsonValue,
          },
        });
        const change = await this.changeService.recordInTransaction(
          tx as unknown as Parameters<typeof this.changeService.recordInTransaction>[0],
          campaignId,
          "actor",
          actorId,
          "upsert",
          nextRevision,
        );
        const message = await tx.campaignChatMessage.create({
          data: {
            campaignId,
            senderId: actor.userId,
            campaignActorId: actorId,
            displayName: actor.username,
            speakerMode: "actor",
            ooc: false,
            kind: "system",
            content: formatItemMessage(actorName, input.name.trim(), quantity),
            eventData: {
              eventType: ITEM_EVENT_TYPE,
              actorId,
              actorName,
              itemId: input.itemId,
              itemName: input.name.trim(),
              quantity,
            } as Prisma.InputJsonValue,
          },
        });
        return { row: result, cursor: change.cursor, messageRow: message };
      },
    );

    this.gateway.broadcastChange({ campaignId, entityType: "actor", cursor });
    const eventView = toEventView(messageRow);
    this.gateway.broadcastToCampaign(campaignId, "campaign:message:new", eventView);

    return {
      actor: toActorSummary(updatedRow),
      event: eventView,
    };
  }

  private async loadActor(
    campaignId: string,
    actorId: string,
  ): Promise<{ row: ActorRow; ctx: CampaignActorContext }> {
    const campaign = await this.fetchCampaignContext(campaignId);
    const row = await this.prismaService.campaignActor.findUnique({
      where: { id: actorId },
    });
    if (!row || row.campaignId !== campaignId) {
      throw new NotFoundException("Campaign actor not found");
    }
    return {
      row,
      ctx: {
        campaignId: campaign.campaignId,
        ownerId: campaign.ownerId,
        members: campaign.members,
        actorId: row.id,
        actorOwnerUserId: row.ownerUserId,
        actorSourceCharacterId: row.sourceCharacterId,
        actorRevision: row.revision,
      },
    };
  }

  private async fetchCampaignContext(campaignId: string): Promise<CampaignContext> {
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

interface ActorRow {
  id: string;
  campaignId: string;
  ownerUserId: string | null;
  sourceCharacterId: string | null;
  actorType: string;
  status: string;
  lifecycle?: string;
  sheetJson: unknown;
  revision: number;
  updatedBy: string;
  createdAt: Date;
  updatedAt: Date;
}

function toActorSummary(row: ActorRow): CampaignActorSummary {
  return {
    id: row.id,
    campaignId: row.campaignId,
    ownerUserId: row.ownerUserId,
    sourceCharacterId: row.sourceCharacterId,
    actorType: row.actorType,
    status: row.status,
    lifecycle: row.lifecycle === "temporary" ? "temporary" : "persistent",
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
    campaignActorId: message.campaignActorId ?? null,
    displayName: message.displayName,
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
        typeof record.itemId === "string" ? record.itemId : "";
      const name = typeof record.name === "string" ? record.name : "";
      const quantity = toInt(record.quantity);
      if (!itemId) return null;
      return { itemId, name, quantity } satisfies InventoryEntry;
    })
    .filter((entry): entry is InventoryEntry => entry !== null);
}

function formatHpMessage(
  actorName: string,
  delta: number,
  from: number,
  to: number,
): string {
  const sign = delta >= 0 ? "+" : "";
  return `${actorName} ${sign}${delta} HP (${from} → ${to})`;
}

function formatItemMessage(
  actorName: string,
  itemName: string,
  quantity: number,
): string {
  return `给 ${actorName} ${itemName} ×${quantity}`;
}

function conflict(row: ActorRow): ConflictException {
  return new ConflictException({
    message: "Actor revision conflict",
    current: toActorSummary(row),
  });
}
