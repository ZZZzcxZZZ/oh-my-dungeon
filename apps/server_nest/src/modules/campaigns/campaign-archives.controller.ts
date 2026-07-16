import { BadRequestException, Body, Controller, Delete, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { AccessTokenPayload } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CampaignArchivesService } from './campaign-archives.service';

@Controller('campaigns/:campaignId/archives')
@UseGuards(JwtAuthGuard)
export class CampaignArchivesController {
  constructor(private readonly archives: CampaignArchivesService) {}

  @Get()
  list(@CurrentUser() user: AccessTokenPayload, @Param('campaignId') campaignId: string, @Query('kind') kind?: string) {
    return this.archives.list(user, campaignId, kind);
  }

  @Post()
  create(@CurrentUser() user: AccessTokenPayload, @Param('campaignId') campaignId: string, @Body() body: { kind?: unknown; title?: unknown; summary?: unknown; payload?: unknown }) {
    if (typeof body.kind !== 'string' || typeof body.title !== 'string') throw new BadRequestException('kind and title are required');
    if (body.payload != null && (typeof body.payload !== 'object' || Array.isArray(body.payload))) throw new BadRequestException('payload must be an object');
    return this.archives.create(user, campaignId, { kind: body.kind, title: body.title, summary: typeof body.summary === 'string' ? body.summary : undefined, payload: body.payload as Record<string, unknown> | undefined });
  }

  @Put(':entryId')
  update(
    @CurrentUser() user: AccessTokenPayload,
    @Param('campaignId') campaignId: string,
    @Param('entryId') entryId: string,
    @Body() body: { kind?: unknown; title?: unknown; summary?: unknown; payload?: unknown; pinned?: unknown },
  ) {
    if (body.kind !== undefined && typeof body.kind !== 'string') throw new BadRequestException('kind must be a string');
    if (body.title !== undefined && typeof body.title !== 'string') throw new BadRequestException('title must be a string');
    if (body.summary !== undefined && typeof body.summary !== 'string') throw new BadRequestException('summary must be a string');
    if (body.pinned !== undefined && typeof body.pinned !== 'boolean') throw new BadRequestException('pinned must be a boolean');
    if (body.payload !== undefined && (typeof body.payload !== 'object' || body.payload === null || Array.isArray(body.payload))) throw new BadRequestException('payload must be an object');
    return this.archives.update(user, campaignId, entryId, {
      kind: body.kind as string | undefined,
      title: body.title as string | undefined,
      summary: body.summary as string | undefined,
      payload: body.payload as Record<string, unknown> | undefined,
      pinned: body.pinned as boolean | undefined,
    });
  }

  @Delete(':entryId')
  archive(@CurrentUser() user: AccessTokenPayload, @Param('campaignId') campaignId: string, @Param('entryId') entryId: string) {
    return this.archives.archive(user, campaignId, entryId);
  }
}
