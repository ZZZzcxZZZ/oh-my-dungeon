import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import type { AccessTokenPayload } from "../auth/auth.types";
import { CampaignsService } from "./campaigns.service";
import type {
  CampaignChatMessageView,
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
  roleOnJoin?: unknown;
  maxUses?: unknown;
}

interface JoinCampaignBody {
  code?: unknown;
}

interface CreateCampaignChatMessageBody {
  kind?: unknown;
  content?: unknown;
  characterId?: unknown;
  displayName?: unknown;
  avatarUrl?: unknown;
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
  ): Promise<CampaignChatMessageView[]> {
    return this.campaignsService.listMessages(user, campaignId);
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
      characterId:
        typeof body.characterId === "string" ? body.characterId : null,
      displayName:
        typeof body.displayName === "string" ? body.displayName : undefined,
      avatarUrl: typeof body.avatarUrl === "string" ? body.avatarUrl : null,
    });
  }

  @Get(":id")
  getCampaign(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
  ): Promise<CampaignView> {
    return this.campaignsService.getCampaign(user, id);
  }

  @Post(":id/invites")
  createInvite(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") campaignId: string,
    @Body() body: CreateInviteBody,
  ): Promise<InviteView> {
    return this.campaignsService.createInvite(user, {
      campaignId,
      roleOnJoin:
        typeof body.roleOnJoin === "string" ? body.roleOnJoin : undefined,
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
