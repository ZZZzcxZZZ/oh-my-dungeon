import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { PrismaService } from "../../prisma/prisma.service";
import { AccessTokenPayload } from "../auth/auth.types";
import { CampaignPolicy } from "../campaigns/policies/campaign.policy";
import { ContentPackageValidatorService } from "./content-package-validator.service";
import type {
  CampaignContentPackageView,
  ContentItemView,
  ContentOverrideView,
  ContentPackageImport,
  ContentPackageView,
  ImportContentPackageResult,
} from "./content.types";

const MANAGE_ROLES = new Set(["owner", "dm"]);

@Injectable()
export class ContentService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly validator: ContentPackageValidatorService,
    private readonly campaignPolicy: CampaignPolicy,
  ) {}

  async importPackage(
    actor: AccessTokenPayload,
    input: unknown,
    dryRun: boolean,
  ): Promise<ImportContentPackageResult> {
    const validation = this.validator.validate(input);
    if (dryRun || !validation.valid) {
      return {
        valid: validation.valid,
        errors: validation.errors,
        package: null,
      };
    }

    this.validator.assertValid(input);
    const contentPackage = input as ContentPackageImport;
    const created = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.contentPackage.create({
        data: {
          scope: "user",
          ownerUserId: actor.userId,
          campaignId: null,
          name: contentPackage.name,
          version: contentPackage.version,
          schemaVersion: contentPackage.schemaVersion ?? 1,
          locale: contentPackage.locale ?? "zh-CN",
          status: "active",
          createdBy: actor.userId,
          items: {
            create: contentPackage.items.map((item) => ({
              type: item.type,
              slug: item.slug,
              name: item.name,
              description: item.description ?? "",
              structured: item.structured ?? {},
              tags: item.tags ?? [],
              sourceLabel: item.sourceLabel ?? "",
              schemaVersion:
                item.schemaVersion ?? contentPackage.schemaVersion ?? 1,
            })),
          },
        },
        include: { items: true },
      });

      await tx.journalEntry.create({
        data: {
          type: "content_package_imported",
          summary: `Imported content package ${contentPackage.name}`,
          refId: result.id,
        },
      });

      return result;
    });

    return {
      valid: true,
      errors: [],
      package: toPackageView(created),
    };
  }

  async listPackages(actor: AccessTokenPayload): Promise<ContentPackageView[]> {
    const packages = await this.prismaService.contentPackage.findMany({
      where: {
        OR: [{ ownerUserId: actor.userId }, { createdBy: actor.userId }],
        status: { not: "archived" },
      },
      orderBy: { updatedAt: "desc" },
    });

    return packages.map(toPackageView);
  }

  async exportPackage(
    actor: AccessTokenPayload,
    packageId: string,
  ): Promise<ContentPackageImport> {
    const contentPackage = await this.prismaService.contentPackage.findUnique({
      where: { id: packageId },
      include: { items: true },
    });
    if (!contentPackage) {
      throw new NotFoundException("Content package not found");
    }
    if (
      contentPackage.ownerUserId !== actor.userId &&
      contentPackage.createdBy !== actor.userId
    ) {
      throw new ForbiddenException("Content package is not visible");
    }

    return {
      name: contentPackage.name,
      version: contentPackage.version,
      schemaVersion: contentPackage.schemaVersion,
      locale: contentPackage.locale,
      items: (contentPackage.items ?? []).map((item: any) => ({
        type: item.type,
        slug: item.slug,
        name: item.name,
        description: item.description,
        structured: item.structured,
        tags: Array.isArray(item.tags) ? item.tags : [],
        sourceLabel: item.sourceLabel,
        schemaVersion: item.schemaVersion,
      })),
    };
  }

  async listItems(
    actor: AccessTokenPayload,
    query: { type?: string; q?: string; packageId?: string },
  ): Promise<ContentItemView[]> {
    const packages = await this.prismaService.contentPackage.findMany({
      where: {
        OR: [{ ownerUserId: actor.userId }, { createdBy: actor.userId }],
        status: "active",
      },
      select: { id: true },
    });
    const visiblePackageIds = packages.map((item: any) => item.id);
    if (query.packageId && !visiblePackageIds.includes(query.packageId)) {
      throw new ForbiddenException("Content package is not visible");
    }

    const items = await this.prismaService.contentItem.findMany({
      where: {
        packageId: query.packageId ?? { in: visiblePackageIds },
        ...(query.type ? { type: query.type } : {}),
        ...(query.q
          ? {
              OR: [
                { name: { contains: query.q, mode: "insensitive" } },
                { slug: { contains: query.q, mode: "insensitive" } },
              ],
            }
          : {}),
      },
      orderBy: { name: "asc" },
    });

    return items.map(toItemView);
  }

  async getItem(
    actor: AccessTokenPayload,
    itemId: string,
  ): Promise<ContentItemView> {
    const item = await this.prismaService.contentItem.findUnique({
      where: { id: itemId },
      include: { package: true },
    });
    if (!item) {
      throw new NotFoundException("Content item not found");
    }
    if (
      item.package.ownerUserId !== actor.userId &&
      item.package.createdBy !== actor.userId
    ) {
      throw new ForbiddenException("Content item is not visible");
    }
    return toItemView(item);
  }

  async setCampaignPackage(
    actor: AccessTokenPayload,
    campaignId: string,
    packageId: string,
    enabled: boolean,
  ): Promise<CampaignContentPackageView> {
    const campaign = await this.fetchCampaign(campaignId);
    this.campaignPolicy.canManageCampaign(actor, {
      campaignId: campaign.id,
      ownerId: campaign.ownerId,
      members: campaign.members,
    });

    const contentPackage = await this.prismaService.contentPackage.findUnique({
      where: { id: packageId },
    });
    if (!contentPackage) {
      throw new NotFoundException("Content package not found");
    }

    const result = await this.prismaService.$transaction(async (tx) => {
      const enabledPackage = await tx.campaignContentPackage.upsert({
        where: {
          campaignId_packageId: {
            campaignId,
            packageId,
          },
        },
        update: {
          enabled,
          enabledBy: actor.userId,
        },
        create: {
          campaignId,
          packageId,
          enabled,
          enabledBy: actor.userId,
        },
      });

      await tx.journalEntry.create({
        data: {
          campaignId,
          type: enabled
            ? "content_package_enabled"
            : "content_package_disabled",
          summary: `${enabled ? "Enabled" : "Disabled"} content package ${contentPackage.name}`,
          refId: packageId,
        },
      });

      return enabledPackage;
    });

    return {
      campaignId: result.campaignId ?? campaignId,
      packageId: result.packageId ?? packageId,
      enabled: result.enabled ?? enabled,
    };
  }

  async listAvailableCampaignItems(
    actor: AccessTokenPayload,
    campaignId: string,
    query: { type?: string; q?: string },
  ): Promise<ContentItemView[]> {
    const campaign = await this.fetchCampaign(campaignId);
    this.campaignPolicy.canViewCampaign(actor, {
      campaignId: campaign.id,
      ownerId: campaign.ownerId,
      members: campaign.members,
    });

    const enables = await this.prismaService.campaignContentPackage.findMany({
      where: { campaignId, enabled: true },
      select: { packageId: true },
    });
    const packageIds = enables.map((item: any) => item.packageId);
    if (packageIds.length === 0) {
      return [];
    }

    const overrides = await this.prismaService.contentOverride.findMany({
      where: { campaignId, overrideType: "disable" },
      select: { baseContentItemId: true, overrideType: true },
    });
    const disabledItemIds = new Set(
      overrides.map((item: any) => item.baseContentItemId),
    );

    const items = await this.prismaService.contentItem.findMany({
      where: {
        packageId: { in: packageIds },
        ...(query.type ? { type: query.type } : {}),
        ...(query.q
          ? {
              OR: [
                { name: { contains: query.q, mode: "insensitive" } },
                { slug: { contains: query.q, mode: "insensitive" } },
              ],
            }
          : {}),
      },
      orderBy: { name: "asc" },
    });

    return items
      .filter((item: any) => !disabledItemIds.has(item.id))
      .map(toItemView);
  }

  async createCampaignOverride(
    actor: AccessTokenPayload,
    campaignId: string,
    input: {
      baseContentItemId: string;
      overrideType: string;
      reason?: string;
    },
  ): Promise<ContentOverrideView> {
    if (input.overrideType !== "disable") {
      throw new ForbiddenException(
        "Only disable overrides are supported in v0.6",
      );
    }

    const campaign = await this.fetchCampaign(campaignId);
    this.campaignPolicy.canManageCampaign(actor, {
      campaignId: campaign.id,
      ownerId: campaign.ownerId,
      members: campaign.members,
    });

    const item = await this.prismaService.contentItem.findUnique({
      where: { id: input.baseContentItemId },
    });
    if (!item) {
      throw new NotFoundException("Content item not found");
    }

    const created = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.contentOverride.create({
        data: {
          campaignId,
          baseContentItemId: input.baseContentItemId,
          overrideType: "disable",
          patchData: {},
          reason: input.reason ?? "",
          createdBy: actor.userId,
        },
      });

      await tx.journalEntry.create({
        data: {
          campaignId,
          type: "content_item_disabled",
          summary: `Disabled content item ${item.name}`,
          refId: input.baseContentItemId,
        },
      });

      return result;
    });

    return toOverrideView(created, campaignId, input, actor.userId);
  }

  private async fetchCampaign(campaignId: string): Promise<any> {
    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true },
    });
    if (!campaign) {
      throw new NotFoundException("Campaign not found");
    }
    return campaign;
  }

  get canManageRoles(): Set<string> {
    return MANAGE_ROLES;
  }
}

function toPackageView(contentPackage: any): ContentPackageView {
  return {
    id: contentPackage.id,
    scope: contentPackage.scope,
    ownerUserId: contentPackage.ownerUserId ?? null,
    campaignId: contentPackage.campaignId ?? null,
    name: contentPackage.name,
    version: contentPackage.version,
    schemaVersion: contentPackage.schemaVersion,
    locale: contentPackage.locale,
    status: contentPackage.status,
    createdBy: contentPackage.createdBy,
    createdAt: toIso(contentPackage.createdAt),
    updatedAt: toIso(contentPackage.updatedAt),
    items: contentPackage.items
      ? contentPackage.items.map(toItemView)
      : undefined,
  };
}

function toItemView(item: any): ContentItemView {
  return {
    id: item.id,
    packageId: item.packageId,
    type: item.type,
    slug: item.slug,
    name: item.name,
    description: item.description,
    structured: item.structured,
    tags: item.tags,
    sourceLabel: item.sourceLabel,
    schemaVersion: item.schemaVersion,
    createdAt: toIso(item.createdAt),
    updatedAt: toIso(item.updatedAt),
  };
}

function toOverrideView(
  row: any,
  campaignId: string,
  input: { baseContentItemId: string; overrideType: string; reason?: string },
  actorId: string,
): ContentOverrideView {
  return {
    id: row.id,
    campaignId: row.campaignId ?? campaignId,
    baseContentItemId: row.baseContentItemId ?? input.baseContentItemId,
    overrideType: row.overrideType ?? input.overrideType,
    reason: row.reason ?? input.reason ?? "",
    createdBy: row.createdBy ?? actorId,
    createdAt: row.createdAt ? toIso(row.createdAt) : undefined,
    updatedAt: row.updatedAt ? toIso(row.updatedAt) : undefined,
  };
}

function toIso(value: any): string {
  return value instanceof Date ? value.toISOString() : value;
}
