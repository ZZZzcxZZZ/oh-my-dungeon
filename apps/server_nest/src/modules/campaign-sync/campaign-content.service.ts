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
  CampaignContext,
  CampaignPolicy,
} from "../campaigns/policies/campaign.policy";
import { CampaignsGateway } from "../realtime/campaigns.gateway";
import { CampaignChangeService } from "./campaign-change.service";
import { CampaignEntryValidatorService } from "./campaign-entry-validator.service";
import type {
  CampaignChangePage,
  CampaignContentEntrySummary,
  ContentValidationReport,
  CreateContentEntryInput,
  UpdateContentEntryInput,
} from "./campaign-sync.types";

@Injectable()
export class CampaignContentService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly policy: CampaignPolicy,
    private readonly changeService: CampaignChangeService,
    private readonly validator: CampaignEntryValidatorService,
    private readonly gateway: CampaignsGateway,
  ) {}

  async validate(
    actor: AccessTokenPayload,
    campaignId: string,
    input: {
      type?: unknown;
      slug?: unknown;
      name?: unknown;
      entry?: unknown;
      [key: string]: unknown;
    },
  ): Promise<ContentValidationReport> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canManageCampaign(actor, campaign);
    return this.validator.validate(input);
  }

  async listChanges(
    actor: AccessTokenPayload,
    campaignId: string,
    cursor: string,
    limit?: number,
  ): Promise<CampaignChangePage> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign);
    return this.changeService.listChanges(campaignId, cursor, limit);
  }

  async create(
    actor: AccessTokenPayload,
    campaignId: string,
    body: {
      type?: unknown;
      slug?: unknown;
      name?: unknown;
      entry?: unknown;
      [key: string]: unknown;
    },
  ): Promise<CampaignContentEntrySummary> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canManageCampaign(actor, campaign);

    const report = this.validator.validate(body);
    if (!report.valid) {
      throw new BadRequestException(
        report.errors.map((e) => `${e.path}: ${e.message}`).join("; "),
      );
    }

    const input: CreateContentEntryInput = {
      type: body.type as string,
      slug: body.slug as string,
      name: body.name as string,
      entry: body.entry as Record<string, unknown>,
    };

    const existing = await this.prismaService.campaignContentEntry.findUnique({
      where: {
        campaignId_slug: { campaignId, slug: input.slug },
      },
    });
    if (existing && !existing.deletedAt) {
      throw new ConflictException({
        message: "A content entry with this slug already exists",
        current: toEntrySummary(existing),
      });
    }

    const revision = 1;
    const created = await this.prismaService.$transaction(async (tx) => {
      const row = await tx.campaignContentEntry.create({
        data: {
          campaignId,
          type: input.type,
          slug: input.slug,
          name: input.name,
          entryJson: input.entry as unknown as Prisma.InputJsonValue,
          revision,
          createdBy: actor.userId,
          updatedBy: actor.userId,
        },
      });
      await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "content",
        row.id,
        "upsert",
        revision,
      );
      return row;
    });

    this.broadcastChange(campaignId, "content");
    return toEntrySummary(created);
  }

  async list(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignContentEntrySummary[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign);

    const rows = await this.prismaService.campaignContentEntry.findMany({
      where: { campaignId, deletedAt: null },
      orderBy: { createdAt: "asc" },
    });
    return rows.map(toEntrySummary);
  }

  async update(
    actor: AccessTokenPayload,
    campaignId: string,
    entryId: string,
    input: UpdateContentEntryInput,
  ): Promise<CampaignContentEntrySummary> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canManageCampaign(actor, campaign);
    const row = await this.fetchEntry(campaignId, entryId);
    if (row.revision !== input.baseRevision) {
      throw conflict(row);
    }

    const report = this.validator.validate({
      type: row.type,
      slug: row.slug,
      name: row.name,
      entry: input.entry,
    });
    if (!report.valid) {
      throw new BadRequestException(
        report.errors.map((e) => `${e.path}: ${e.message}`).join("; "),
      );
    }

    const nextRevision = row.revision + 1;
    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.campaignContentEntry.update({
        where: { id: entryId },
        data: {
          entryJson: input.entry as unknown as Prisma.InputJsonValue,
          revision: nextRevision,
          updatedBy: actor.userId,
        },
      });
      await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "content",
        entryId,
        "upsert",
        nextRevision,
      );
      return result;
    });

    this.broadcastChange(campaignId, "content");
    return toEntrySummary(updated);
  }

  async delete(
    actor: AccessTokenPayload,
    campaignId: string,
    entryId: string,
  ): Promise<CampaignContentEntrySummary> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canManageCampaign(actor, campaign);
    const row = await this.fetchEntry(campaignId, entryId);

    const nextRevision = row.revision + 1;
    const now = new Date();
    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.campaignContentEntry.update({
        where: { id: entryId },
        data: {
          deletedAt: now,
          revision: nextRevision,
          updatedBy: actor.userId,
        },
      });
      await this.changeService.recordInTransaction(
        tx,
        campaignId,
        "content",
        entryId,
        "delete",
        nextRevision,
      );
      return result;
    });

    this.broadcastChange(campaignId, "content");
    return toEntrySummary(updated);
  }

  private async fetchEntry(
    campaignId: string,
    entryId: string,
  ): Promise<EntryRow> {
    const row = await this.prismaService.campaignContentEntry.findUnique({
      where: { id: entryId },
    });
    if (!row || row.campaignId !== campaignId) {
      throw new NotFoundException("Campaign content entry not found");
    }
    return row;
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
  ): void {
    if (typeof (this.gateway as any).broadcastChange === "function") {
      (this.gateway as any).broadcastChange({ campaignId, entityType });
    }
  }
}

interface EntryRow {
  id: string;
  campaignId: string;
  type: string;
  slug: string;
  name: string;
  entryJson: unknown;
  revision: number;
  createdBy: string;
  updatedBy: string;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}

function toEntrySummary(row: EntryRow): CampaignContentEntrySummary {
  return {
    id: row.id,
    campaignId: row.campaignId,
    type: row.type,
    slug: row.slug,
    name: row.name,
    entry: (row.entryJson ?? {}) as Record<string, unknown>,
    revision: row.revision,
    createdBy: row.createdBy,
    updatedBy: row.updatedBy,
    createdAt: toIso(row.createdAt),
    updatedAt: toIso(row.updatedAt),
    deletedAt: row.deletedAt ? toIso(row.deletedAt) : null,
  };
}

function toIso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : value;
}

function conflict(row: EntryRow): ConflictException {
  return new ConflictException({
    message: "Content entry revision conflict",
    current: toEntrySummary(row),
  });
}
