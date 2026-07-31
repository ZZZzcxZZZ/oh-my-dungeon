import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Put,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import type { AccessTokenPayload } from "../auth/auth.types";
import { CampaignCharactersService } from "./campaign-characters.service";
import type {
  CampaignCharacterAuditRecord,
  CampaignCharacterSummary,
  CampaignCharacterType,
} from "./campaign-sync.types";

interface PublishCharacterBody {
  sourceCharacterId?: unknown;
  characterType?: unknown;
  baseRevision?: unknown;
  sheet?: unknown;
}

interface CreateCharacterBody {
  characterType?: unknown;
  ownerUserId?: unknown;
  lifecycle?: unknown;
  sheet?: unknown;
}

interface UpdateCharacterBody {
  baseRevision?: unknown;
  sheet?: unknown;
  lifecycle?: unknown;
  visibleToPlayers?: unknown;
}

interface AssignCharacterBody {
  ownerUserId?: unknown;
  baseRevision?: unknown;
}

interface ArchiveCharacterBody {
  baseRevision?: unknown;
}

interface RuntimeCommandBody {
  baseRevision?: unknown;
  commands?: unknown;
}

@Controller("campaigns/:campaignId/characters")
@UseGuards(JwtAuthGuard)
export class CampaignCharactersController {
  constructor(private readonly charactersService: CampaignCharactersService) {}

  @Post("publish")
  publish(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Body() body: PublishCharacterBody,
  ): Promise<CampaignCharacterSummary> {
    return this.charactersService.publish(user, campaignId, {
      sourceCharacterId: parseString(body.sourceCharacterId, "sourceCharacterId"),
      characterType: parseCharacterType(body.characterType),
      baseRevision: parseBaseRevision(body.baseRevision),
      sheet: parseSheet(body.sheet),
    });
  }

  @Post()
  create(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Body() body: CreateCharacterBody,
  ): Promise<CampaignCharacterSummary> {
    return this.charactersService.create(user, campaignId, {
      characterType: parseCharacterType(body.characterType),
      ownerUserId:
        typeof body.ownerUserId === "string" && body.ownerUserId.length > 0
          ? body.ownerUserId
          : null,
      lifecycle: parseLifecycle(body.lifecycle),
      sheet: parseSheet(body.sheet),
    });
  }

  @Get()
  list(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
  ): Promise<CampaignCharacterSummary[]> {
    return this.charactersService.list(user, campaignId);
  }

  @Get(":characterId")
  get(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
  ): Promise<CampaignCharacterSummary> {
    return this.charactersService.get(user, campaignId, characterId);
  }

  @Put(":characterId")
  update(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
    @Body() body: UpdateCharacterBody,
  ): Promise<CampaignCharacterSummary> {
    return this.charactersService.update(user, campaignId, characterId, {
      baseRevision: parseBaseRevision(body.baseRevision),
      sheet: parseSheet(body.sheet),
      lifecycle: parseOptionalLifecycle(body.lifecycle),
      visibleToPlayers: parseOptionalBoolean(
        body.visibleToPlayers,
        "visibleToPlayers",
      ),
    });
  }

  @Post(":characterId/runtime-commands")
  @HttpCode(200)
  applyRuntimeCommands(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
    @Body() body: RuntimeCommandBody,
  ): Promise<CampaignCharacterSummary> {
    if (!Array.isArray(body.commands)) {
      throw new BadRequestException("commands must be an array");
    }
    return this.charactersService.applyRuntimeCommands(user, campaignId, characterId, {
      baseRevision: parseBaseRevision(body.baseRevision),
      commands: body.commands as any,
    });
  }

  @Post(":characterId/assign")
  @HttpCode(200)
  assign(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
    @Body() body: AssignCharacterBody,
  ): Promise<CampaignCharacterSummary> {
    return this.charactersService.assign(user, campaignId, characterId, {
      ownerUserId:
        body.ownerUserId === null
          ? null
          : typeof body.ownerUserId === "string" && body.ownerUserId.length > 0
            ? body.ownerUserId
            : null,
      baseRevision: parseBaseRevision(body.baseRevision),
    });
  }

  @Post(":characterId/archive")
  @HttpCode(200)
  archive(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
    @Body() body: ArchiveCharacterBody,
  ): Promise<CampaignCharacterSummary> {
    return this.charactersService.archive(user, campaignId, characterId, {
      baseRevision: parseBaseRevision(body.baseRevision),
    });
  }

  @Post(":characterId/restore")
  @HttpCode(200)
  restore(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
    @Body() body: ArchiveCharacterBody,
  ): Promise<CampaignCharacterSummary> {
    return this.charactersService.restore(user, campaignId, characterId, {
      baseRevision: parseBaseRevision(body.baseRevision),
    });
  }

  @Get(":characterId/audits")
  listAudits(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
  ): Promise<CampaignCharacterAuditRecord[]> {
    return this.charactersService.listAudits(user, campaignId, characterId);
  }
}

function parseString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new BadRequestException(`${field} is required`);
  }
  return value;
}

function parseCharacterType(value: unknown): CampaignCharacterType {
  if (
    value === "player" ||
    value === "npc" ||
    value === "unclaimed" ||
    value === "companion" ||
    value === "monster"
  ) {
    return value;
  }
  throw new BadRequestException("characterType must be one of player|npc|unclaimed|companion|monster");
}

function parseLifecycle(value: unknown): "persistent" {
  if (value === undefined || value === "persistent") return "persistent";
  throw new BadRequestException(
    "lifecycle must be persistent; one-shot identities belong to message speakerSnapshot",
  );
}

/**
 * Legacy temporary characters can still be promoted to persistent. New temporary
 * character state is no longer accepted.
 */
function parseOptionalLifecycle(value: unknown): "persistent" | undefined {
  if (value === undefined) return undefined;
  if (value === "persistent") return "persistent";
  throw new BadRequestException(
    "lifecycle must be persistent; one-shot identities belong to message speakerSnapshot",
  );
}

function parseBaseRevision(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new BadRequestException("baseRevision must be a number");
  }
  return Math.trunc(value);
}

function parseOptionalBoolean(
  value: unknown,
  field: string,
): boolean | undefined {
  if (value === undefined) return undefined;
  if (typeof value === "boolean") return value;
  throw new BadRequestException(`${field} must be a boolean`);
}

function parseSheet(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BadRequestException("sheet must be an object");
  }
  return value as Record<string, unknown>;
}
