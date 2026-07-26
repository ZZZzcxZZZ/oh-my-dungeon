import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import type { AccessTokenPayload } from "../auth/auth.types";
import { CampaignConversationsService } from "./campaign-conversations.service";
import type {
  CampaignConversationView,
} from "./campaigns.types";

interface CreateDirectConversationBody {
  otherUserId?: unknown;
}

interface CreateGroupConversationBody {
  title?: unknown;
  participantIds?: unknown;
}

interface UpdateConversationBody {
  title?: unknown;
  archived?: unknown;
}

@Controller("campaigns/:campaignId/conversations")
@UseGuards(JwtAuthGuard)
export class CampaignConversationsController {
  constructor(
    private readonly conversations: CampaignConversationsService,
  ) {}

  @Get()
  list(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
  ): Promise<CampaignConversationView[]> {
    return this.conversations.listConversations(user, campaignId);
  }

  @Post("direct")
  createDirect(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Body() body: CreateDirectConversationBody,
  ): Promise<CampaignConversationView> {
    if (typeof body.otherUserId !== "string" || !body.otherUserId.trim()) {
      throw new BadRequestException("otherUserId is required");
    }
    return this.conversations.createDirectConversation(user, campaignId, {
      otherUserId: body.otherUserId,
    });
  }

  @Post("group")
  createGroup(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Body() body: CreateGroupConversationBody,
  ): Promise<CampaignConversationView> {
    if (typeof body.title !== "string" || !body.title.trim()) {
      throw new BadRequestException("title is required");
    }
    if (!Array.isArray(body.participantIds)) {
      throw new BadRequestException("participantIds must be an array");
    }
    return this.conversations.createGroupConversation(user, campaignId, {
      title: body.title,
      participantIds: body.participantIds as string[],
    });
  }

  @Patch(":conversationId")
  update(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("conversationId") conversationId: string,
    @Body() body: UpdateConversationBody,
  ): Promise<CampaignConversationView> {
    if (
      body.title !== undefined &&
      (typeof body.title !== "string" || !body.title.trim())
    ) {
      throw new BadRequestException("title must be a non-empty string");
    }
    if (body.archived !== undefined && typeof body.archived !== "boolean") {
      throw new BadRequestException("archived must be a boolean");
    }
    return this.conversations.updateConversation(user, campaignId, conversationId, {
      title: typeof body.title === "string" ? body.title : undefined,
      archived: typeof body.archived === "boolean" ? body.archived : undefined,
    });
  }

  @Post(":conversationId/read")
  markRead(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("conversationId") conversationId: string,
  ): Promise<{ lastReadAt: string }> {
    return this.conversations.markRead(user, campaignId, conversationId);
  }
}
