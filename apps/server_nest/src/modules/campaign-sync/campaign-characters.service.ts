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
  CampaignCharacterContext,
  CampaignContext,
  CampaignPolicy,
} from "../campaigns/policies/campaign.policy";
import { CampaignsGateway } from "../realtime/campaigns.gateway";
import { CampaignChangeService } from "./campaign-change.service";
import type {
  ArchiveCharacterInput,
  AssignCharacterInput,
  CampaignCharacterAuditRecord,
  CampaignCharacterSummary,
  CampaignCharacterStatus,
  CampaignCharacterType,
  CampaignRuntimeCommand,
  CreateCharacterInput,
  PublishCharacterInput,
  RuntimeCommandInput,
  UpdateCharacterInput,
} from "./campaign-sync.types";

const ALLOWED_CHARACTER_TYPES: ReadonlySet<CampaignCharacterType> = new Set([
  "player",
  "npc",
  "unclaimed",
  "companion",
  "monster",
]);

const RUNTIME_COMMAND_TYPES: ReadonlySet<string> = new Set([
  "setHp",
  "adjustHp",
  "setTemporaryHp",
  "setCondition",
  "removeCondition",
  "setResource",
]);

@Injectable()
export class CampaignCharactersService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly policy: CampaignPolicy,
    private readonly changeService: CampaignChangeService,
    private readonly gateway: CampaignsGateway,
  ) {}

  async publish(
    user: AccessTokenPayload,
    campaignId: string,
    input: PublishCharacterInput,
  ): Promise<CampaignCharacterSummary> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canPublishCharacter(user, campaign);

    if (!isNonEmptyString(input.sourceCharacterId)) {
      throw new BadRequestException("sourceCharacterId is required");
    }
    if (!ALLOWED_CHARACTER_TYPES.has(input.characterType)) {
      throw new BadRequestException(`Unknown characterType: ${input.characterType}`);
    }
    if (input.characterType !== "player") {
      throw new BadRequestException(
        "Only player characters can be self-published; use the DM create endpoint for NPCs",
      );
    }
    if (!isObject(input.sheet)) {
      throw new BadRequestException("sheet must be an object");
    }

    // Local character ids are only stable inside one user's local vault. Two
    // campaign members may legitimately publish the same local id (for example
    // after importing the same Markdown template), so ownership is part of the
    // identity boundary.
    const existing = await this.prismaService.campaignCharacter.findFirst({
      where: {
        campaignId,
        ownerUserId: user.userId,
        sourceCharacterId: input.sourceCharacterId,
      },
    });

    const revision = 1;
    const sheetJson = input.sheet as Record<string, unknown>;

    if (existing) {
      // Re-publishing is idempotent: update the sheet in place and bump
      // revision. An archived campaign copy is restored because selecting the
      // local character again is the player's explicit "rejoin" action.
      return this.applyUpdate(user, campaignId, existing, {
        baseRevision: input.baseRevision,
        sheet: sheetJson,
      }, {
        reactivatePublishedCharacter: true,
      });
    }

    const { row: created, cursor } = await this.prismaService.$transaction(async (tx) => {
      const row = await tx.campaignCharacter.create({
        data: {
          campaignId,
          ownerUserId: user.userId,
          sourceCharacterId: input.sourceCharacterId,
          characterType: input.characterType,
          status: "active",
          visibleToPlayers: true,
          sheetJson: sheetJson as unknown as Prisma.InputJsonValue,
          revision,
          updatedBy: user.userId,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "character",
        row.id,
        "upsert",
        revision,
      );
      return { row, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "character", cursor);
    return toCharacterSummary(created);
  }

  async create(
    user: AccessTokenPayload,
    campaignId: string,
    input: CreateCharacterInput,
  ): Promise<CampaignCharacterSummary> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canManageCampaign(user, campaign);

    if (!ALLOWED_CHARACTER_TYPES.has(input.characterType)) {
      throw new BadRequestException(`Unknown characterType: ${input.characterType}`);
    }
    if (input.characterType === "player") {
      throw new BadRequestException(
        "Player characters must be self-published via /characters/publish",
      );
    }
    if (!isObject(input.sheet)) {
      throw new BadRequestException("sheet must be an object");
    }

    let ownerUserId: string | null = null;
    if (typeof input.ownerUserId === "string" && input.ownerUserId.length > 0) {
      const membership =
        await this.prismaService.campaignMember.findFirst({
          where: {
            campaignId,
            userId: input.ownerUserId,
          },
        });
      if (!membership) {
        throw new BadRequestException(
          "ownerUserId must reference a campaign member",
        );
      }
      ownerUserId = input.ownerUserId;
    }

    const revision = 1;
    const { row: created, cursor } = await this.prismaService.$transaction(async (tx) => {
      const row = await tx.campaignCharacter.create({
        data: {
          campaignId,
          ownerUserId,
          sourceCharacterId: null,
          characterType: input.characterType,
          status: "active",
          lifecycle: input.lifecycle ?? "persistent",
          visibleToPlayers: false,
          sheetJson: input.sheet as unknown as Prisma.InputJsonValue,
          revision,
          updatedBy: user.userId,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "character",
        row.id,
        "upsert",
        revision,
      );
      return { row, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "character", cursor);
    return toCharacterSummary(created);
  }

  async list(
    user: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignCharacterSummary[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign);

    const rows = await this.prismaService.campaignCharacter.findMany({
      where: { campaignId },
      orderBy: { createdAt: "asc" },
    });
    const canManage = this.policy.capabilitiesFor(
      user,
      campaign,
    ).canManageCampaign;
    return rows
      .filter(
        (row) =>
          canManage ||
          row.characterType === "player" ||
          row.visibleToPlayers === true,
      )
      .map(toCharacterSummary);
  }

  async get(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
  ): Promise<CampaignCharacterSummary> {
    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    this.policy.canViewCharacter(user, ctx);
    return toCharacterSummary(row);
  }

  async update(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: UpdateCharacterInput,
  ): Promise<CampaignCharacterSummary> {
    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    // Spec §完整管理: 转为常驻 — lifecycle 变更需要 DM 权限；普通 sheet
    // 编辑沿用 canEditOwnedCharacter，保持玩家自编辑角色卡的能力。
    const currentLifecycle = row.lifecycle === "temporary" ? "temporary" : "persistent";
    const lifecycleChanged =
      input.lifecycle !== undefined && input.lifecycle !== currentLifecycle;
    const currentVisibility =
      row.characterType === "player" || row.visibleToPlayers === true;
    const visibilityChanged =
      input.visibleToPlayers !== undefined &&
      input.visibleToPlayers !== currentVisibility;
    if (row.characterType === "player" && input.visibleToPlayers === false) {
      throw new BadRequestException("Player characters are always visible");
    }
    if (lifecycleChanged || visibilityChanged) {
      this.policy.canManageCharacter(user, ctx);
    } else {
      this.policy.canEditOwnedCharacter(user, ctx);
    }
    return this.applyUpdate(user, campaignId, row, input);
  }

  async archive(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: ArchiveCharacterInput,
  ): Promise<CampaignCharacterSummary> {
    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    this.policy.canManageCharacter(user, ctx);
    if (row.revision !== input.baseRevision) {
      throw conflict(row);
    }

    const nextRevision = row.revision + 1;
    const { row: updated, cursor } = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.campaignCharacter.update({
        where: { id: characterId },
        data: {
          status: "archived" satisfies CampaignCharacterStatus,
          revision: nextRevision,
          updatedBy: user.userId,
        },
      });
      // 归档角色时解绑所有绑定它的成员: 归档角色不可发言/绑定, 成员栏
      // 应回到"未绑定"状态, 避免已绑定但不可用的脏状态.
      await tx.campaignMember.updateMany({
        where: { campaignId, boundCharacterId: characterId },
        data: {
          boundCharacterId: null,
          activeSpeakerCharacterId: null,
          speakerMode: "ooc",
        },
      });
      await tx.campaignCharacterAudit.create({
        data: {
          campaignCharacterId: characterId,
          campaignId,
          characterUserId: user.userId,
          baseRevision: row.revision,
          resultRevision: nextRevision,
          changedPaths: ["status"] as unknown as Prisma.InputJsonValue,
          beforeJson: { status: row.status } as unknown as Prisma.InputJsonValue,
          afterJson: { status: "archived" } as unknown as Prisma.InputJsonValue,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "character",
        characterId,
        "upsert",
        nextRevision,
      );
      return { row: result, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "character", cursor);
    return toCharacterSummary(updated);
  }

  async restore(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: ArchiveCharacterInput,
  ): Promise<CampaignCharacterSummary> {
    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    this.policy.canManageCharacter(user, ctx);
    if (row.revision !== input.baseRevision) {
      throw conflict(row);
    }

    const nextRevision = row.revision + 1;
    const { row: updated, cursor } = await this.prismaService.$transaction(
      async (tx) => {
        const result = await tx.campaignCharacter.update({
          where: { id: characterId },
          data: {
            status: "active" satisfies CampaignCharacterStatus,
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
            changedPaths: ["status"] as unknown as Prisma.InputJsonValue,
            beforeJson: {
              status: row.status,
            } as unknown as Prisma.InputJsonValue,
            afterJson: {
              status: "active",
            } as unknown as Prisma.InputJsonValue,
          },
        });
        const change = await this.changeService.recordInTransaction(
          tx,
          campaignId,
          "character",
          characterId,
          "upsert",
          nextRevision,
        );
        return { row: result, cursor: change.cursor };
      },
    );

    this.broadcastChange(campaignId, "character", cursor);
    return toCharacterSummary(updated);
  }

  async assign(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: AssignCharacterInput,
  ): Promise<CampaignCharacterSummary> {
    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    this.policy.canManageCharacter(user, ctx);
    if (row.revision !== input.baseRevision) {
      throw conflict(row);
    }

    let ownerUserId: string | null = null;
    if (input.ownerUserId !== null) {
      if (!isNonEmptyString(input.ownerUserId)) {
        throw new BadRequestException("ownerUserId must be a string or null");
      }
      const membership = await this.prismaService.campaignMember.findFirst({
        where: { campaignId, userId: input.ownerUserId },
      });
      if (!membership) {
        throw new BadRequestException(
          "ownerUserId must reference a campaign member",
        );
      }
      ownerUserId = input.ownerUserId;
    }

    const nextRevision = row.revision + 1;
    const { row: updated, cursor } = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.campaignCharacter.update({
        where: { id: characterId },
        data: {
          ownerUserId,
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
          changedPaths: ["ownerUserId"] as unknown as Prisma.InputJsonValue,
          beforeJson: { ownerUserId: row.ownerUserId } as unknown as Prisma.InputJsonValue,
          afterJson: { ownerUserId } as unknown as Prisma.InputJsonValue,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "character",
        characterId,
        "upsert",
        nextRevision,
      );
      return { row: result, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "character", cursor);
    return toCharacterSummary(updated);
  }

  async applyRuntimeCommands(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: RuntimeCommandInput,
  ): Promise<CampaignCharacterSummary> {
    const { row, ctx } = await this.loadCharacter(campaignId, characterId);
    this.policy.canManageCharacter(user, ctx);
    if (row.revision !== input.baseRevision) {
      throw conflict(row);
    }
    if (!Array.isArray(input.commands) || input.commands.length === 0) {
      throw new BadRequestException("commands must be a non-empty array");
    }
    for (const cmd of input.commands) {
      if (!cmd || typeof cmd.type !== "string" || !RUNTIME_COMMAND_TYPES.has(cmd.type)) {
        throw new BadRequestException(`Unknown runtime command type`);
      }
    }

    const beforeSheet = (row.sheetJson ?? {}) as Record<string, unknown>;
    const afterSheet = applyCommands(beforeSheet, input.commands);
    const nextRevision = row.revision + 1;
    const changedPaths = diffPaths(beforeSheet, afterSheet);

    const updated = await this.prismaService.$transaction(async (tx) => {
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
        tx,
        campaignId,
        "character",
        characterId,
        "upsert",
        nextRevision,
      );
      return { row: result, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "character", updated.cursor);
    return toCharacterSummary(updated.row);
  }

  async listAudits(
    user: AccessTokenPayload,
    campaignId: string,
    characterId: string,
  ): Promise<CampaignCharacterAuditRecord[]> {
    const { ctx } = await this.loadCharacter(campaignId, characterId);
    this.policy.canViewCharacter(user, ctx);

    const rows = await this.prismaService.campaignCharacterAudit.findMany({
      where: { campaignCharacterId: characterId, campaignId },
      orderBy: { createdAt: "asc" },
    });
    return rows.map(toAuditRecord);
  }

  private async applyUpdate(
    user: AccessTokenPayload,
    campaignId: string,
    existing: CharacterRow,
    input: UpdateCharacterInput,
    options: {
      reactivatePublishedCharacter?: boolean;
    } = {},
  ): Promise<CampaignCharacterSummary> {
    if (existing.revision !== input.baseRevision) {
      throw conflict(existing);
    }
    if (!isObject(input.sheet)) {
      throw new BadRequestException("sheet must be an object");
    }

    const beforeSheet = (existing.sheetJson ?? {}) as Record<string, unknown>;
    const afterSheet = input.sheet;
    const nextRevision = existing.revision + 1;
    const changedPaths = diffPaths(beforeSheet, afterSheet);
    // Spec §完整管理: 转为常驻 — 当 lifecycle 实际变化时，把它加入变更路径
    // 并写入 update.data，让审计记录和数据库列都反映新的 lifecycle。
    const currentLifecycle = existing.lifecycle === "temporary" ? "temporary" : "persistent";
    const lifecycleChanged =
      input.lifecycle !== undefined && input.lifecycle !== currentLifecycle;
    if (lifecycleChanged) {
      changedPaths.push("lifecycle");
    }
    const currentVisibility =
      existing.characterType === "player" ||
      existing.visibleToPlayers === true;
    const visibilityChanged =
      input.visibleToPlayers !== undefined &&
      input.visibleToPlayers !== currentVisibility;
    if (visibilityChanged) {
      changedPaths.push("visibleToPlayers");
    }
    const reactivating = options.reactivatePublishedCharacter === true;
    const statusChanged = reactivating && existing.status !== "active";
    const characterTypeChanged =
      reactivating && existing.characterType !== "player";
    const publishedVisibilityChanged =
      reactivating && existing.visibleToPlayers !== true;
    if (statusChanged) {
      changedPaths.push("status");
    }
    if (characterTypeChanged) {
      changedPaths.push("characterType");
    }
    if (publishedVisibilityChanged &&
        !changedPaths.includes("visibleToPlayers")) {
      changedPaths.push("visibleToPlayers");
    }

    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.campaignCharacter.update({
        where: { id: existing.id },
        data: {
          sheetJson: afterSheet as unknown as Prisma.InputJsonValue,
          revision: nextRevision,
          updatedBy: user.userId,
          ...(lifecycleChanged ? { lifecycle: input.lifecycle } : {}),
          ...(visibilityChanged
            ? { visibleToPlayers: input.visibleToPlayers }
            : {}),
          ...(reactivating
            ? {
                status: "active",
                characterType: "player",
                visibleToPlayers: true,
              }
            : {}),
        },
      });
      const stateChanged =
        lifecycleChanged ||
        visibilityChanged ||
        statusChanged ||
        characterTypeChanged ||
        publishedVisibilityChanged;
      await tx.campaignCharacterAudit.create({
        data: {
          campaignCharacterId: existing.id,
          campaignId,
          characterUserId: user.userId,
          baseRevision: existing.revision,
          resultRevision: nextRevision,
          changedPaths: changedPaths as unknown as Prisma.InputJsonValue,
          beforeJson:
            stateChanged
              ? ({
                  sheet: beforeSheet,
                  ...(lifecycleChanged
                    ? { lifecycle: currentLifecycle }
                    : {}),
                  ...(visibilityChanged
                    ? { visibleToPlayers: currentVisibility }
                    : {}),
                  ...(statusChanged ? { status: existing.status } : {}),
                  ...(characterTypeChanged
                    ? { characterType: existing.characterType }
                    : {}),
                  ...(publishedVisibilityChanged
                    ? { visibleToPlayers: existing.visibleToPlayers === true }
                    : {}),
                } as unknown as Prisma.InputJsonValue)
              : (beforeSheet as unknown as Prisma.InputJsonValue),
          afterJson:
            stateChanged
              ? ({
                  sheet: afterSheet,
                  ...(lifecycleChanged
                    ? { lifecycle: input.lifecycle }
                    : {}),
                  ...(visibilityChanged
                    ? { visibleToPlayers: input.visibleToPlayers }
                    : {}),
                  ...(statusChanged ? { status: "active" } : {}),
                  ...(characterTypeChanged
                    ? { characterType: "player" }
                    : {}),
                  ...(publishedVisibilityChanged
                    ? { visibleToPlayers: true }
                    : {}),
                } as unknown as Prisma.InputJsonValue)
              : (afterSheet as unknown as Prisma.InputJsonValue),
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "character",
        existing.id,
        "upsert",
        nextRevision,
      );
      return { row: result, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "character", updated.cursor);
    return toCharacterSummary(updated.row);
  }

  private async loadCharacter(campaignId: string, characterId: string): Promise<{
    row: CharacterRow;
    ctx: CampaignCharacterContext;
  }> {
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

  private broadcastChange(
    campaignId: string,
    entityType: "character" | "content",
    cursor: string,
  ): void {
    this.gateway.broadcastChange({ campaignId, entityType, cursor });
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

function toAuditRecord(row: any): CampaignCharacterAuditRecord {
  return {
    id: row.id,
    campaignCharacterId: row.campaignCharacterId,
    campaignId: row.campaignId,
    characterUserId: row.characterUserId,
    baseRevision: row.baseRevision,
    resultRevision: row.resultRevision,
    changedPaths: Array.isArray(row.changedPaths) ? row.changedPaths : [],
    beforeSheet: (row.beforeJson ?? {}) as Record<string, unknown>,
    afterSheet: (row.afterJson ?? {}) as Record<string, unknown>,
    createdAt: toIso(row.createdAt),
  };
}

function toIso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : value;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function conflict(row: CharacterRow): ConflictException {
  return new ConflictException({
    message: "Character revision conflict",
    current: toCharacterSummary(row),
  });
}

function applyCommands(
  sheet: Record<string, unknown>,
  commands: CampaignRuntimeCommand[],
): Record<string, unknown> {
  const next: Record<string, unknown> = JSON.parse(JSON.stringify(sheet));
  for (const cmd of commands) {
    switch (cmd.type) {
      case "setHp": {
        next["currentHp"] = toInt(cmd.value);
        break;
      }
      case "adjustHp": {
        const delta = typeof cmd.delta === "number" ? cmd.delta : 0;
        let current = toInt(next["currentHp"]);
        if (delta < 0) {
          // 规则：受到伤害时先扣临时生命值，溢出部分才扣当前生命值；
          // 当前生命值不会低于 0（改为死亡豁免流程）。
          const damage = -delta;
          const temporary = toInt(next["temporaryHp"]);
          const absorbed = Math.min(Math.max(temporary, 0), damage);
          if (absorbed > 0) next["temporaryHp"] = temporary - absorbed;
          current = Math.max(current - (damage - absorbed), 0);
        } else {
          // 治疗不改变临时生命值，且不超过最大生命值。
          const maxHp = toInt(next["maxHp"]);
          current = current + delta;
          if (maxHp > 0) current = Math.min(current, maxHp);
        }
        next["currentHp"] = current;
        break;
      }
      case "setTemporaryHp": {
        next["temporaryHp"] = toInt(cmd.value);
        break;
      }
      case "setCondition": {
        const list = toStringArray(next["conditions"]);
        const name = typeof cmd.name === "string" ? cmd.name : "";
        if (name && !list.includes(name)) list.push(name);
        next["conditions"] = list;
        break;
      }
      case "removeCondition": {
        const list = toStringArray(next["conditions"]);
        const name = typeof cmd.name === "string" ? cmd.name : "";
        next["conditions"] = list.filter((c) => c !== name);
        break;
      }
      case "setResource": {
        const resources = isObject(next["resources"])
          ? (next["resources"] as Record<string, unknown>)
          : {};
        const name = typeof cmd.name === "string" ? cmd.name : "";
        if (name) resources[name] = cmd.value;
        next["resources"] = resources;
        break;
      }
      default:
        break;
    }
  }
  return next;
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

function toStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((v): v is string => typeof v === "string")
    : [];
}

function diffPaths(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): string[] {
  const keys = new Set<string>([
    ...Object.keys(before),
    ...Object.keys(after),
  ]);
  const changed: string[] = [];
  for (const key of keys) {
    if (JSON.stringify(before[key]) !== JSON.stringify(after[key])) {
      changed.push(key);
    }
  }
  return changed.sort();
}
