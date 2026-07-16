import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import type { AccessTokenPayload } from "../auth/auth.types";
import { CampaignsService } from "./campaigns.service";
import type {
  CampaignChatMessageView,
  CampaignWorkspaceContextView,
  CampaignView,
  InviteView,
  MembershipView,
} from "./campaigns.types";

interface CreateCampaignBody {
  name?: unknown;
  description?: unknown;
  system?: unknown;
}

interface CreateInviteBody {
  maxUses?: unknown;
}

interface JoinCampaignBody {
  code?: unknown;
}

interface CreateCampaignChatMessageBody {
  kind?: unknown;
  content?: unknown;
  campaignActorId?: unknown;
  actionId?: unknown;
  eventData?: unknown;
}

interface UpdateMemberBindingBody {
  actorId?: unknown;
}

interface UpdateSpeakerBody {
  speakerMode?: unknown;
  actorId?: unknown;
}

@Controller("campaigns")
@UseGuards(JwtAuthGuard)
export class CampaignsController {
  constructor(private readonly campaignsService: CampaignsService) {}

  @Post()
  createCampaign(
    @CurrentUser() user: AccessTokenPayload,
    @Body() body: CreateCampaignBody,
  ): Promise<CampaignView> {
    if (!isNonEmptyString(body.name)) {
      throw new BadRequestException("Campaign name is required");
    }

    return this.campaignsService.createCampaign(user, {
      name: body.name,
      description:
        typeof body.description === "string" ? body.description : undefined,
      system: typeof body.system === "string" ? body.system : undefined,
    });
  }

  @Get()
  listCampaigns(
    @CurrentUser() user: AccessTokenPayload,
  ): Promise<CampaignView[]> {
    return this.campaignsService.listCampaigns(user);
  }

  @Get(":id/messages")
  listMessages(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Query("query") query?: string,
  ): Promise<CampaignChatMessageView[]> {
    return this.campaignsService.listMessages(user, campaignId, query);
  }

  @Post(":id/messages")
  sendMessage(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Body() body: CreateCampaignChatMessageBody,
  ): Promise<CampaignChatMessageView> {
    if (!isNonEmptyString(body.content)) {
      throw new BadRequestException("Message content is required");
    }

    return this.campaignsService.sendMessage(user, campaignId, {
      kind: typeof body.kind === "string" ? body.kind : undefined,
      content: body.content,
      campaignActorId:
        typeof body.campaignActorId === "string" ? body.campaignActorId : null,
      actionId: typeof body.actionId === "string" ? body.actionId : null,
      eventData: isRecord(body.eventData) ? body.eventData : null,
    });
  }

  @Get(":id")
  getCampaign(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
  ): Promise<CampaignView> {
    return this.campaignsService.getCampaign(user, id);
  }

  @Get(":id/context")
  getWorkspaceContext(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
  ): Promise<CampaignWorkspaceContextView> {
    return this.campaignsService.getWorkspaceContext(user, campaignId);
  }

  @Put(":id/members/:userId/binding")
  updateMemberBinding(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Param("userId") userId: string,
    @Body() body: UpdateMemberBindingBody,
  ): Promise<MembershipView> {
    if (body.actorId !== null && typeof body.actorId !== "string") {
      throw new BadRequestException("actorId must be a string or null");
    }
    return this.campaignsService.updateMemberBinding(
      user,
      campaignId,
      userId,
      body.actorId ?? null,
    );
  }

  @Put(":id/speaker")
  updateSpeaker(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Body() body: UpdateSpeakerBody,
  ): Promise<MembershipView> {
    if (
      body.speakerMode !== "boundActor" &&
      body.speakerMode !== "actor" &&
      body.speakerMode !== "narrator" &&
      body.speakerMode !== "ooc"
    ) {
      throw new BadRequestException("Unsupported speakerMode");
    }
    if (body.actorId !== undefined && typeof body.actorId !== "string") {
      throw new BadRequestException("actorId must be a string when provided");
    }
    return this.campaignsService.updateSpeaker(user, campaignId, {
      speakerMode: body.speakerMode,
      actorId: typeof body.actorId === "string" ? body.actorId : null,
    });
  }

  @Post(":id/read")
  markRead(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
  ): Promise<MembershipView> {
    return this.campaignsService.markRead(user, campaignId);
  }

  @Post(":id/invites")
  createInvite(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Body() body: CreateInviteBody,
  ): Promise<InviteView> {
    return this.campaignsService.createInvite(user, {
      campaignId,
      maxUses: typeof body.maxUses === "number" ? body.maxUses : undefined,
    });
  }

  @Get(":id/invites")
  listInvites(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
  ): Promise<InviteView[]> {
    return this.campaignsService.listInvites(user, campaignId);
  }

  @Post("join")
  joinCampaign(
    @CurrentUser() user: AccessTokenPayload,
    @Body() body: JoinCampaignBody,
  ): Promise<MembershipView> {
    if (!isNonEmptyString(body.code)) {
      throw new BadRequestException("Invite code is required");
    }
    return this.campaignsService.joinCampaign(user, body.code);
  }
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}
