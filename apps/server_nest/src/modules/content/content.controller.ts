import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Delete,
  Param,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import type { AccessTokenPayload } from "../auth/auth.types";
import { ContentService } from "./content.service";
import type {
  CampaignContentPackageView,
  ContentItemView,
  CampaignContentItemDetailView,
  ContentPackageImport,
  ContentOverrideView,
  ContentPackageView,
  ImportContentPackageResult,
} from "./content.types";

interface ImportPackageBody {
  dryRun?: unknown;
  package?: unknown;
}

interface EnablePackageBody {
  packageId?: unknown;
  enabled?: unknown;
}

interface OverrideBody {
  baseContentItemId?: unknown;
  overrideType?: unknown;
  reason?: unknown;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class ContentController {
  constructor(private readonly contentService: ContentService) {}

  @Post("content/packages/import")
  importPackage(
    @CurrentUser() user: AccessTokenPayload,
    @Body() body: ImportPackageBody,
  ): Promise<ImportContentPackageResult> {
    return this.contentService.importPackage(
      user,
      body.package,
      body.dryRun === true,
    );
  }

  @Post("campaigns/:id/content/packages/import")
  importCampaignPackage(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Body() body: ImportPackageBody,
  ): Promise<ImportContentPackageResult> {
    return this.contentService.importCampaignPackage(
      user,
      campaignId,
      body.package,
      body.dryRun === true,
    );
  }

  @Get("content/packages")
  listPackages(
    @CurrentUser() user: AccessTokenPayload,
  ): Promise<ContentPackageView[]> {
    return this.contentService.listPackages(user);
  }

  @Get("content/packages/:id/export")
  exportPackage(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
  ): Promise<ContentPackageImport> {
    return this.contentService.exportPackage(user, id);
  }

  @Get("content/items")
  listItems(
    @CurrentUser() user: AccessTokenPayload,
    @Query("type") type?: string,
    @Query("q") q?: string,
    @Query("packageId") packageId?: string,
  ): Promise<ContentItemView[]> {
    return this.contentService.listItems(user, { type, q, packageId });
  }

  @Get("content/items/:id")
  getItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
  ): Promise<ContentItemView> {
    return this.contentService.getItem(user, id);
  }

  @Post("campaigns/:id/content/packages")
  setCampaignPackage(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
    @Body() body: EnablePackageBody,
  ): Promise<CampaignContentPackageView> {
    if (!isNonEmptyString(body.packageId)) {
      throw new BadRequestException("Package id is required");
    }
    if (typeof body.enabled !== "boolean") {
      throw new BadRequestException("Enabled flag is required");
    }

    return this.contentService.setCampaignPackage(
      user,
      id,
      body.packageId,
      body.enabled,
    );
  }

  @Get("campaigns/:id/content/available")
  listAvailableCampaignItems(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
    @Query("type") type?: string,
    @Query("q") q?: string,
    @Query("favoriteOnly") favoriteOnly?: string,
  ): Promise<ContentItemView[]> {
    return this.contentService.listAvailableCampaignItems(user, id, {
      type,
      q,
      favoriteOnly: favoriteOnly === "true",
    });
  }

  @Post("campaigns/:id/content/items/:itemId/favorite")
  favoriteItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Param("itemId") itemId: string,
  ): Promise<void> {
    return this.contentService.setCampaignItemFavorite(user, campaignId, itemId, true);
  }

  @Get("campaigns/:id/content/items/:itemId")
  getCampaignItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Param("itemId") itemId: string,
  ): Promise<CampaignContentItemDetailView> {
    return this.contentService.getCampaignItem(user, campaignId, itemId);
  }

  @Delete("campaigns/:id/content/items/:itemId/favorite")
  unfavoriteItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Param("itemId") itemId: string,
  ): Promise<void> {
    return this.contentService.setCampaignItemFavorite(user, campaignId, itemId, false);
  }

  @Post("campaigns/:id/content/overrides")
  createCampaignOverride(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
    @Body() body: OverrideBody,
  ): Promise<ContentOverrideView> {
    if (!isNonEmptyString(body.baseContentItemId)) {
      throw new BadRequestException("Base content item id is required");
    }
    if (!isNonEmptyString(body.overrideType)) {
      throw new BadRequestException("Override type is required");
    }

    return this.contentService.createCampaignOverride(user, id, {
      baseContentItemId: body.baseContentItemId,
      overrideType: body.overrideType,
      reason: optionalString(body.reason),
    });
  }
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}
