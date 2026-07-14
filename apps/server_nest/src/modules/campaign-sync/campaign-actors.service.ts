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
  ArchiveActorInput,
  AssignActorInput,
  CampaignActorAuditRecord,
  CampaignActorSummary,
  CampaignActorStatus,
  CampaignActorType,
  CampaignRuntimeCommand,
  CreateActorInput,
  PublishActorInput,
  RuntimeCommandInput,
  UpdateActorInput,
} from "./campaign-sync.types";

const ALLOWED_ACTOR_TYPES: ReadonlySet<CampaignActorType> = new Set([
  "player",
  "npc",
  "unclaimed",
  "companion",
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
export class CampaignActorsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly policy: CampaignPolicy,
    private readonly changeService: CampaignChangeService,
    private readonly gateway: CampaignsGateway,
  ) {}

  async publish(
    actor: AccessTokenPayload,
    campaignId: string,
    input: PublishActorInput,
  ): Promise<CampaignActorSummary> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canPublishActor(actor, campaign);

    if (!isNonEmptyString(input.sourceCharacterId)) {
      throw new BadRequestException("sourceCharacterId is required");
    }
    if (!ALLOWED_ACTOR_TYPES.has(input.actorType)) {
      throw new BadRequestException(`Unknown actorType: ${input.actorType}`);
    }
    if (input.actorType !== "player") {
      throw new BadRequestException(
        "Only player actors can be self-published; use the DM create endpoint for NPCs",
      );
    }
    if (!isObject(input.sheet)) {
      throw new BadRequestException("sheet must be an object");
    }

    const existing = await this.prismaService.campaignActor.findUnique({
      where: {
        campaignId_sourceCharacterId: {
          campaignId,
          sourceCharacterId: input.sourceCharacterId,
        },
      },
    });

    const revision = 1;
    const sheetJson = input.sheet as Record<string, unknown>;

    if (existing) {
      // Re-publishing is idempotent: update the sheet in place and bump
      // revision, leaving ownerUserId untouched so a re-publish does not
      // reassign ownership.
      return this.applyUpdate(actor, campaignId, existing, {
        baseRevision: input.baseRevision,
        sheet: sheetJson,
      });
    }

    const { row: created, cursor } = await this.prismaService.$transaction(async (tx) => {
      const row = await tx.campaignActor.create({
        data: {
          campaignId,
          ownerUserId: actor.userId,
          sourceCharacterId: input.sourceCharacterId,
          actorType: input.actorType,
          status: "active",
          sheetJson: sheetJson as unknown as Prisma.InputJsonValue,
          revision,
          updatedBy: actor.userId,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "actor",
        row.id,
        "upsert",
        revision,
      );
      return { row, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "actor", cursor);
    return toActorSummary(created);
  }

  async create(
    actor: AccessTokenPayload,
    campaignId: string,
    input: CreateActorInput,
  ): Promise<CampaignActorSummary> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canManageCampaign(actor, campaign);

    if (!ALLOWED_ACTOR_TYPES.has(input.actorType)) {
      throw new BadRequestException(`Unknown actorType: ${input.actorType}`);
    }
    if (input.actorType === "player") {
      throw new BadRequestException(
        "Player actors must be self-published via /actors/publish",
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
      const row = await tx.campaignActor.create({
        data: {
          campaignId,
          ownerUserId,
          sourceCharacterId: null,
          actorType: input.actorType,
          status: "active",
          sheetJson: input.sheet as unknown as Prisma.InputJsonValue,
          revision,
          updatedBy: actor.userId,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "actor",
        row.id,
        "upsert",
        revision,
      );
      return { row, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "actor", cursor);
    return toActorSummary(created);
  }

  async list(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignActorSummary[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign);

    const rows = await this.prismaService.campaignActor.findMany({
      where: { campaignId },
      orderBy: { createdAt: "asc" },
    });
    return rows.map(toActorSummary);
  }

  async get(
    actor: AccessTokenPayload,
    campaignId: string,
    actorId: string,
  ): Promise<CampaignActorSummary> {
    const { row, ctx } = await this.loadActor(campaignId, actorId);
    this.policy.canViewActor(actor, ctx);
    return toActorSummary(row);
  }

  async update(
    actor: AccessTokenPayload,
    campaignId: string,
    actorId: string,
    input: UpdateActorInput,
  ): Promise<CampaignActorSummary> {
    const { row, ctx } = await this.loadActor(campaignId, actorId);
    this.policy.canEditOwnedActor(actor, ctx);
    return this.applyUpdate(actor, campaignId, row, input);
  }

  async archive(
    actor: AccessTokenPayload,
    campaignId: string,
    actorId: string,
    input: ArchiveActorInput,
  ): Promise<CampaignActorSummary> {
    const { row, ctx } = await this.loadActor(campaignId, actorId);
    this.policy.canManageActor(actor, ctx);
    if (row.revision !== input.baseRevision) {
      throw conflict(row);
    }

    const nextRevision = row.revision + 1;
    const { row: updated, cursor } = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.campaignActor.update({
        where: { id: actorId },
        data: {
          status: "archived" satisfies CampaignActorStatus,
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
          changedPaths: ["status"] as unknown as Prisma.InputJsonValue,
          beforeJson: { status: row.status } as unknown as Prisma.InputJsonValue,
          afterJson: { status: "archived" } as unknown as Prisma.InputJsonValue,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "actor",
        actorId,
        "upsert",
        nextRevision,
      );
      return { row: result, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "actor", cursor);
    return toActorSummary(updated);
  }

  async assign(
    actor: AccessTokenPayload,
    campaignId: string,
    actorId: string,
    input: AssignActorInput,
  ): Promise<CampaignActorSummary> {
    const { row, ctx } = await this.loadActor(campaignId, actorId);
    this.policy.canManageActor(actor, ctx);
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
      const result = await tx.campaignActor.update({
        where: { id: actorId },
        data: {
          ownerUserId,
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
          changedPaths: ["ownerUserId"] as unknown as Prisma.InputJsonValue,
          beforeJson: { ownerUserId: row.ownerUserId } as unknown as Prisma.InputJsonValue,
          afterJson: { ownerUserId } as unknown as Prisma.InputJsonValue,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "actor",
        actorId,
        "upsert",
        nextRevision,
      );
      return { row: result, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "actor", cursor);
    return toActorSummary(updated);
  }

  async applyRuntimeCommands(
    actor: AccessTokenPayload,
    campaignId: string,
    actorId: string,
    input: RuntimeCommandInput,
  ): Promise<CampaignActorSummary> {
    const { row, ctx } = await this.loadActor(campaignId, actorId);
    this.policy.canManageActor(actor, ctx);
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
        tx,
        campaignId,
        "actor",
        actorId,
        "upsert",
        nextRevision,
      );
      return { row: result, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "actor", updated.cursor);
    return toActorSummary(updated.row);
  }

  async listAudits(
    actor: AccessTokenPayload,
    campaignId: string,
    actorId: string,
  ): Promise<CampaignActorAuditRecord[]> {
    const { ctx } = await this.loadActor(campaignId, actorId);
    this.policy.canViewActor(actor, ctx);

    const rows = await this.prismaService.campaignActorAudit.findMany({
      where: { campaignActorId: actorId, campaignId },
      orderBy: { createdAt: "asc" },
    });
    return rows.map(toAuditRecord);
  }

  private async applyUpdate(
    actor: AccessTokenPayload,
    campaignId: string,
    existing: ActorRow,
    input: UpdateActorInput,
  ): Promise<CampaignActorSummary> {
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

    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.campaignActor.update({
        where: { id: existing.id },
        data: {
          sheetJson: afterSheet as unknown as Prisma.InputJsonValue,
          revision: nextRevision,
          updatedBy: actor.userId,
        },
      });
      await tx.campaignActorAudit.create({
        data: {
          campaignActorId: existing.id,
          campaignId,
          actorUserId: actor.userId,
          baseRevision: existing.revision,
          resultRevision: nextRevision,
          changedPaths: changedPaths as unknown as Prisma.InputJsonValue,
          beforeJson: beforeSheet as unknown as Prisma.InputJsonValue,
          afterJson: afterSheet as unknown as Prisma.InputJsonValue,
        },
      });
      const change = await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "actor",
        existing.id,
        "upsert",
        nextRevision,
      );
      return { row: result, cursor: change.cursor };
    });

    this.broadcastChange(campaignId, "actor", updated.cursor);
    return toActorSummary(updated.row);
  }

  private async loadActor(campaignId: string, actorId: string): Promise<{
    row: ActorRow;
    ctx: CampaignActorContext;
  }> {
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

  private broadcastChange(
    campaignId: string,
    entityType: "actor" | "content",
    cursor: string,
  ): void {
    this.gateway.broadcastChange({ campaignId, entityType, cursor });
  }
}

interface ActorRow {
  id: string;
  campaignId: string;
  ownerUserId: string | null;
  sourceCharacterId: string | null;
  actorType: string;
  status: string;
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
    sheet: (row.sheetJson ?? {}) as Record<string, unknown>,
    revision: row.revision,
    updatedBy: row.updatedBy,
    createdAt: toIso(row.createdAt),
    updatedAt: toIso(row.updatedAt),
  };
}

function toAuditRecord(row: any): CampaignActorAuditRecord {
  return {
    id: row.id,
    campaignActorId: row.campaignActorId,
    campaignId: row.campaignId,
    actorUserId: row.actorUserId,
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

function conflict(row: ActorRow): ConflictException {
  return new ConflictException({
    message: "Actor revision conflict",
    current: toActorSummary(row),
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
        const current = toInt(next["currentHp"]);
        next["currentHp"] = current + (typeof cmd.delta === "number" ? cmd.delta : 0);
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
