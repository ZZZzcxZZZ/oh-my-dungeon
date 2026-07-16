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
import { CampaignActorsService } from "./campaign-actors.service";
import type {
  CampaignActorAuditRecord,
  CampaignActorSummary,
  CampaignActorType,
} from "./campaign-sync.types";

interface PublishActorBody {
  sourceCharacterId?: unknown;
  actorType?: unknown;
  baseRevision?: unknown;
  sheet?: unknown;
}

interface CreateActorBody {
  actorType?: unknown;
  ownerUserId?: unknown;
  lifecycle?: unknown;
  sheet?: unknown;
}

interface UpdateActorBody {
  baseRevision?: unknown;
  sheet?: unknown;
}

interface AssignActorBody {
  ownerUserId?: unknown;
  baseRevision?: unknown;
}

interface ArchiveActorBody {
  baseRevision?: unknown;
}

interface RuntimeCommandBody {
  baseRevision?: unknown;
  commands?: unknown;
}

@Controller("campaigns/:campaignId/actors")
@UseGuards(JwtAuthGuard)
export class CampaignActorsController {
  constructor(private readonly actorsService: CampaignActorsService) {}

  @Post("publish")
  publish(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Body() body: PublishActorBody,
  ): Promise<CampaignActorSummary> {
    return this.actorsService.publish(user, campaignId, {
      sourceCharacterId: parseString(body.sourceCharacterId, "sourceCharacterId"),
      actorType: parseActorType(body.actorType),
      baseRevision: parseBaseRevision(body.baseRevision),
      sheet: parseSheet(body.sheet),
    });
  }

  @Post()
  create(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Body() body: CreateActorBody,
  ): Promise<CampaignActorSummary> {
    return this.actorsService.create(user, campaignId, {
      actorType: parseActorType(body.actorType),
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
  ): Promise<CampaignActorSummary[]> {
    return this.actorsService.list(user, campaignId);
  }

  @Get(":actorId")
  get(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("actorId") actorId: string,
  ): Promise<CampaignActorSummary> {
    return this.actorsService.get(user, campaignId, actorId);
  }

  @Put(":actorId")
  update(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("actorId") actorId: string,
    @Body() body: UpdateActorBody,
  ): Promise<CampaignActorSummary> {
    return this.actorsService.update(user, campaignId, actorId, {
      baseRevision: parseBaseRevision(body.baseRevision),
      sheet: parseSheet(body.sheet),
    });
  }

  @Post(":actorId/runtime-commands")
  @HttpCode(200)
  applyRuntimeCommands(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("actorId") actorId: string,
    @Body() body: RuntimeCommandBody,
  ): Promise<CampaignActorSummary> {
    if (!Array.isArray(body.commands)) {
      throw new BadRequestException("commands must be an array");
    }
    return this.actorsService.applyRuntimeCommands(user, campaignId, actorId, {
      baseRevision: parseBaseRevision(body.baseRevision),
      commands: body.commands as any,
    });
  }

  @Post(":actorId/assign")
  @HttpCode(200)
  assign(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("actorId") actorId: string,
    @Body() body: AssignActorBody,
  ): Promise<CampaignActorSummary> {
    return this.actorsService.assign(user, campaignId, actorId, {
      ownerUserId:
        body.ownerUserId === null
          ? null
          : typeof body.ownerUserId === "string" && body.ownerUserId.length > 0
            ? body.ownerUserId
            : null,
      baseRevision: parseBaseRevision(body.baseRevision),
    });
  }

  @Post(":actorId/archive")
  @HttpCode(200)
  archive(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("actorId") actorId: string,
    @Body() body: ArchiveActorBody,
  ): Promise<CampaignActorSummary> {
    return this.actorsService.archive(user, campaignId, actorId, {
      baseRevision: parseBaseRevision(body.baseRevision),
    });
  }

  @Get(":actorId/audits")
  listAudits(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("actorId") actorId: string,
  ): Promise<CampaignActorAuditRecord[]> {
    return this.actorsService.listAudits(user, campaignId, actorId);
  }
}

function parseString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new BadRequestException(`${field} is required`);
  }
  return value;
}

function parseActorType(value: unknown): CampaignActorType {
  if (
    value === "player" ||
    value === "npc" ||
    value === "unclaimed" ||
    value === "companion"
  ) {
    return value;
  }
  throw new BadRequestException("actorType must be one of player|npc|unclaimed|companion");
}

function parseLifecycle(value: unknown): "persistent" | "temporary" {
  if (value === undefined || value === "persistent") return "persistent";
  if (value === "temporary") return "temporary";
  throw new BadRequestException("lifecycle must be persistent or temporary");
}

function parseBaseRevision(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new BadRequestException("baseRevision must be a number");
  }
  return Math.trunc(value);
}

function parseSheet(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new BadRequestException("sheet must be an object");
  }
  return value as Record<string, unknown>;
}
