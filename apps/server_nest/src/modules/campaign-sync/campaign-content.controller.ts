import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import type { AccessTokenPayload } from "../auth/auth.types";
import { CampaignContentService } from "./campaign-content.service";
import type {
  CampaignChangePage,
  CampaignContentEntrySummary,
  ContentValidationReport,
} from "./campaign-sync.types";

interface CreateEntryBody {
  type?: unknown;
  slug?: unknown;
  name?: unknown;
  entry?: unknown;
  [key: string]: unknown;
}

interface UpdateEntryBody {
  baseRevision?: unknown;
  entry?: unknown;
}

@Controller("campaigns/:campaignId")
@UseGuards(JwtAuthGuard)
export class CampaignContentController {
  constructor(private readonly contentService: CampaignContentService) {}

  @Post("content/entries/validate")
  @HttpCode(200)
  validate(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Body() body: CreateEntryBody,
  ): Promise<ContentValidationReport> {
    return this.contentService.validate(user, campaignId, body);
  }

  @Post("content/entries")
  create(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Body() body: CreateEntryBody,
  ): Promise<CampaignContentEntrySummary> {
    return this.contentService.create(user, campaignId, body);
  }

  @Get("content/entries")
  list(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
  ): Promise<CampaignContentEntrySummary[]> {
    return this.contentService.list(user, campaignId);
  }

  @Put("content/entries/:entryId")
  update(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("entryId") entryId: string,
    @Body() body: UpdateEntryBody,
  ): Promise<CampaignContentEntrySummary> {
    return this.contentService.update(user, campaignId, entryId, {
      baseRevision: parseBaseRevision(body.baseRevision),
      entry: parseEntry(body.entry),
    });
  }

  @Delete("content/entries/:entryId")
  @HttpCode(200)
  delete(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("entryId") entryId: string,
  ): Promise<CampaignContentEntrySummary> {
    return this.contentService.delete(user, campaignId, entryId);
  }

  @Get("changes")
  listChanges(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Query("cursor") cursor?: string,
    @Query("limit") limit?: string,
  ): Promise<CampaignChangePage> {
    const cursorStr = typeof cursor === "string" && cursor.length > 0 ? cursor : "0";
    let limitNum: number | undefined;
    if (typeof limit === "string" && limit.length > 0) {
      const parsed = Number.parseInt(limit, 10);
      if (!Number.isNaN(parsed) && parsed > 0) {
        limitNum = parsed;
      } else {
        throw new BadRequestException("limit must be a positive integer");
      }
    }
    return this.contentService.listChanges(user, campaignId, cursorStr, limitNum);
  }
}

function parseBaseRevision(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new BadRequestException("baseRevision must be a number");
  }
  return Math.trunc(value);
}

function parseEntry(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BadRequestException("entry must be an object");
  }
  return value as Record<string, unknown>;
}
