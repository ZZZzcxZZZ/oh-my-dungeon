import {
  Controller,
  ForbiddenException,
  Get,
  NotFoundException,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AccessTokenPayload } from '../auth/auth.types';
import { CampaignPolicy } from '../campaigns/policies/campaign.policy';
import { GameEventsService } from './game-events.service';

@Controller()
@UseGuards(JwtAuthGuard)
export class GameEventsController {
  constructor(
    private readonly events: GameEventsService,
    private readonly prisma: PrismaService,
    private readonly campaignPolicy: CampaignPolicy,
  ) {}

  @Get('characters/:characterId/events')
  async listCharacterEvents(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Query('cursor') cursor?: string,
    @Query('type') type?: string,
    @Query('since') since?: string,
    @Query('limit') limit?: string,
  ) {
    const character = await this.prisma.character.findUnique({
      where: { id: characterId },
      select: { ownerUserId: true },
    });
    if (!character) throw new NotFoundException('Character not found');
    if (character.ownerUserId !== user.userId) {
      throw new ForbiddenException('Character access denied');
    }
    return this.events.listCharacterEvents(
      characterId,
      parseQuery(cursor, type, since, limit),
    );
  }

  @Get('campaigns/:campaignId/events')
  async listCampaignEvents(
    @CurrentUser() user: AccessTokenPayload,
    @Param('campaignId') campaignId: string,
    @Query('cursor') cursor?: string,
    @Query('type') type?: string,
    @Query('since') since?: string,
    @Query('limit') limit?: string,
  ) {
    const campaign = await this.prisma.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true },
    });
    if (!campaign) throw new NotFoundException('Campaign not found');
    this.campaignPolicy.canViewCampaign(user, {
      campaignId,
      ownerId: campaign.ownerId,
      members: campaign.members.map((member) => ({
        userId: member.userId,
        role: member.role,
      })),
    });
    return this.events.listCampaignEvents(
      campaignId,
      parseQuery(cursor, type, since, limit),
    );
  }
}

function parseQuery(
  cursor?: string,
  type?: string,
  since?: string,
  limit?: string,
) {
  const parsedSince = since ? new Date(since) : undefined;
  const parsedLimit = limit ? Number(limit) : undefined;
  return {
    cursor: cursor || undefined,
    type: type || undefined,
    since:
      parsedSince && !Number.isNaN(parsedSince.getTime())
        ? parsedSince
        : undefined,
    limit:
      parsedLimit !== undefined && Number.isFinite(parsedLimit)
        ? parsedLimit
        : undefined,
  };
}
