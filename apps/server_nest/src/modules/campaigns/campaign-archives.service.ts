import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AccessTokenPayload } from '../auth/auth.types';
import { CampaignPolicy } from './policies/campaign.policy';

const kinds = new Set(['document', 'location', 'clue', 'file']);

@Injectable()
export class CampaignArchivesService {
  constructor(private readonly prisma: PrismaService, private readonly policy: CampaignPolicy) {}

  async list(actor: AccessTokenPayload, campaignId: string, kind?: string) {
    const campaign = await this.context(campaignId);
    this.policy.canViewCampaign(actor, campaign);
    return this.prisma.campaignArchiveEntry.findMany({
      where: { campaignId, deletedAt: null, ...(kind ? { kind } : {}) },
      orderBy: [{ pinned: 'desc' }, { updatedAt: 'desc' }],
    });
  }

  async create(actor: AccessTokenPayload, campaignId: string, input: { kind: string; title: string; summary?: string; payload?: Record<string, unknown> }) {
    const campaign = await this.context(campaignId);
    this.policy.canManageCampaign(actor, campaign);
    if (!kinds.has(input.kind) || !input.title.trim()) throw new BadRequestException('Invalid archive entry');
    return this.prisma.campaignArchiveEntry.create({ data: {
      campaignId, kind: input.kind, title: input.title.trim(), summary: input.summary?.trim() ?? '',
      payload: (input.payload ?? {}) as Prisma.InputJsonValue, createdBy: actor.userId, updatedBy: actor.userId,
    }});
  }

  async update(
    actor: AccessTokenPayload,
    campaignId: string,
    entryId: string,
    input: { kind?: string; title?: string; summary?: string; payload?: Record<string, unknown>; pinned?: boolean },
  ) {
    const campaign = await this.context(campaignId);
    this.policy.canManageCampaign(actor, campaign);
    const entry = await this.prisma.campaignArchiveEntry.findFirst({
      where: { id: entryId, campaignId, deletedAt: null },
    });
    if (!entry) throw new NotFoundException('Archive entry not found');
    if (input.kind !== undefined && !kinds.has(input.kind)) throw new BadRequestException('Invalid archive entry kind');
    if (input.title !== undefined && !input.title.trim()) throw new BadRequestException('Archive title is required');

    const data: Prisma.CampaignArchiveEntryUpdateInput = { updatedBy: actor.userId };
    if (input.kind !== undefined) data.kind = input.kind;
    if (input.title !== undefined) data.title = input.title.trim();
    if (input.summary !== undefined) data.summary = input.summary.trim();
    if (input.payload !== undefined) data.payload = input.payload as Prisma.InputJsonValue;
    if (input.pinned !== undefined) data.pinned = input.pinned;
    return this.prisma.campaignArchiveEntry.update({ where: { id: entryId }, data });
  }

  async archive(actor: AccessTokenPayload, campaignId: string, entryId: string) {
    const campaign = await this.context(campaignId);
    this.policy.canManageCampaign(actor, campaign);
    const entry = await this.prisma.campaignArchiveEntry.findFirst({
      where: { id: entryId, campaignId, deletedAt: null },
    });
    if (!entry) throw new NotFoundException('Archive entry not found');
    return this.prisma.campaignArchiveEntry.update({
      where: { id: entryId },
      data: { deletedAt: new Date(), updatedBy: actor.userId },
    });
  }

  private async context(campaignId: string) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId }, include: { members: true } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    return { campaignId: campaign.id, ownerId: campaign.ownerId, members: campaign.members.map(member => ({ userId: member.userId, role: member.role })) };
  }
}
