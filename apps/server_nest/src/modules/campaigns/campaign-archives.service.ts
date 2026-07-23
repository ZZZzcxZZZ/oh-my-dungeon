import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AccessTokenPayload } from '../auth/auth.types';
import { CampaignPolicy } from './policies/campaign.policy';

const kinds = new Set(['document', 'location', 'clue', 'file']);

export interface ArchiveWikiInput {
  bodyBlocks?: unknown;
  tags?: unknown;
  links?: unknown;
  attachmentRefs?: unknown;
}

export interface ArchiveUpdateInput extends ArchiveWikiInput {
  kind?: string;
  title?: string;
  summary?: string;
  payload?: Record<string, unknown>;
  pinned?: boolean;
}

export interface ArchiveCreateInput extends ArchiveWikiInput {
  kind: string;
  title: string;
  summary?: string;
  payload?: Record<string, unknown>;
}

function validateWikiFields(input: ArchiveWikiInput): {
  bodyBlocks?: unknown[];
  tags?: string[];
  links?: unknown[];
  attachmentRefs?: unknown[];
} {
  const result: { bodyBlocks?: unknown[]; tags?: string[]; links?: unknown[]; attachmentRefs?: unknown[] } = {};
  if (input.bodyBlocks !== undefined) {
    if (!Array.isArray(input.bodyBlocks)) throw new BadRequestException('bodyBlocks must be an array');
    // Plan 2026-07-23 task 4.1: element-level validation. The client
    // renders blocks by reading `block['type']`; without a `type` field
    // the entry silently disappears from the detail view.
    for (const block of input.bodyBlocks) {
      if (!block || typeof block !== 'object' || Array.isArray(block)) {
        throw new BadRequestException('bodyBlocks elements must be objects');
      }
      const obj = block as Record<string, unknown>;
      if (typeof obj['type'] !== 'string') {
        throw new BadRequestException('bodyBlocks elements must have a string type field');
      }
    }
    result.bodyBlocks = input.bodyBlocks;
  }
  if (input.tags !== undefined) {
    if (!Array.isArray(input.tags) || input.tags.some((t) => typeof t !== 'string')) {
      throw new BadRequestException('tags must be an array of strings');
    }
    result.tags = input.tags;
  }
  if (input.links !== undefined) {
    if (!Array.isArray(input.links)) throw new BadRequestException('links must be an array');
    result.links = input.links;
  }
  if (input.attachmentRefs !== undefined) {
    if (!Array.isArray(input.attachmentRefs)) throw new BadRequestException('attachmentRefs must be an array');
    result.attachmentRefs = input.attachmentRefs;
  }
  return result;
}

function mergeWikiIntoPayload(
  base: Record<string, unknown>,
  wiki: { bodyBlocks?: unknown[]; tags?: string[]; links?: unknown[]; attachmentRefs?: unknown[] },
): Record<string, unknown> {
  const merged: Record<string, unknown> = { ...base };
  if (wiki.bodyBlocks !== undefined) merged['bodyBlocks'] = wiki.bodyBlocks;
  if (wiki.tags !== undefined) merged['tags'] = wiki.tags;
  if (wiki.links !== undefined) merged['links'] = wiki.links;
  if (wiki.attachmentRefs !== undefined) merged['attachmentRefs'] = wiki.attachmentRefs;
  return merged;
}

function extractBodyText(payload: unknown): string {
  if (!payload || typeof payload !== 'object') return '';
  const obj = payload as Record<string, unknown>;
  const body = obj['body'];
  if (typeof body === 'string') return body;
  const blocks = obj['bodyBlocks'];
  if (!Array.isArray(blocks)) return '';
  return blocks
    .map((block) => {
      if (block && typeof block === 'object') {
        const text = (block as Record<string, unknown>)['text'];
        if (typeof text === 'string') return text;
      }
      return '';
    })
    .join(' ');
}

function extractTags(payload: unknown): string[] {
  if (!payload || typeof payload !== 'object') return [];
  const obj = payload as Record<string, unknown>;
  const tags = obj['tags'];
  if (!Array.isArray(tags)) return [];
  return tags.filter((t): t is string => typeof t === 'string');
}

@Injectable()
export class CampaignArchivesService {
  constructor(private readonly prisma: PrismaService, private readonly policy: CampaignPolicy) {}

  async list(
    actor: AccessTokenPayload,
    campaignId: string,
    kind?: string,
    q?: string,
    tags?: string[],
  ) {
    const campaign = await this.context(campaignId);
    this.policy.canViewCampaign(actor, campaign);
    const entries = await this.prisma.campaignArchiveEntry.findMany({
      where: { campaignId, deletedAt: null, ...(kind ? { kind } : {}) },
      orderBy: [{ pinned: 'desc' }, { updatedAt: 'desc' }],
    });
    // Plan 2026-07-23 task 4.2: tag filter (OR semantics — entry matches
    // if it carries ANY of the requested tags). Applied in memory because
    // tags live inside the JSON payload column.
    const filteredByTags = tags && tags.length > 0
      ? entries.filter((entry) => {
          const entryTags = extractTags(entry.payload).map((t) => t.toLowerCase());
          if (entryTags.length === 0) return false;
          const requested = tags.map((t) => t.toLowerCase());
          return entryTags.some((t) => requested.includes(t));
        })
      : entries;
    const needle = q && q.trim() ? q.trim().toLowerCase() : null;
    const textFiltered = needle
      ? filteredByTags.filter((entry) => {
          const title = (entry.title ?? '').toLowerCase();
          const summary = (entry.summary ?? '').toLowerCase();
          const body = extractBodyText(entry.payload).toLowerCase();
          const entryTags = extractTags(entry.payload).map((t) => t.toLowerCase());
          return (
            title.includes(needle) ||
            summary.includes(needle) ||
            body.includes(needle) ||
            entryTags.some((t) => t.includes(needle))
          );
        })
      : filteredByTags;
    if (textFiltered.length === 0) return [];
    // Plan 2026-07-23 task 4.3: attach editor display name snapshots.
    // Batched lookup so all entries share a single user query regardless
    // of how many distinct editors / creators exist.
    const userIds = new Set<string>();
    for (const entry of textFiltered) {
      if (entry.createdBy) userIds.add(entry.createdBy);
      if (entry.updatedBy) userIds.add(entry.updatedBy);
    }
    const users = userIds.size > 0
      ? await this.prisma.user.findMany({
          where: { id: { in: Array.from(userIds) } },
          select: { id: true, username: true, displayName: true },
        })
      : [];
    const nameById = new Map<string, string>();
    for (const user of users) {
      nameById.set(user.id, user.displayName ?? user.username);
    }
    return textFiltered.map((entry) => ({
      ...entry,
      createdByName: nameById.get(entry.createdBy) ?? null,
      updatedByName: entry.updatedBy ? (nameById.get(entry.updatedBy) ?? null) : null,
    }));
  }

  async create(actor: AccessTokenPayload, campaignId: string, input: ArchiveCreateInput) {
    const campaign = await this.context(campaignId);
    this.policy.canManageCampaign(actor, campaign);
    if (!kinds.has(input.kind) || !input.title.trim()) throw new BadRequestException('Invalid archive entry');
    const wiki = validateWikiFields(input);
    const payload = mergeWikiIntoPayload(input.payload ?? {}, wiki);
    return this.prisma.campaignArchiveEntry.create({ data: {
      campaignId, kind: input.kind, title: input.title.trim(), summary: input.summary?.trim() ?? '',
      payload: payload as Prisma.InputJsonValue, createdBy: actor.userId, updatedBy: actor.userId,
    }});
  }

  async update(
    actor: AccessTokenPayload,
    campaignId: string,
    entryId: string,
    input: ArchiveUpdateInput,
  ) {
    const campaign = await this.context(campaignId);
    const entry = await this.prisma.campaignArchiveEntry.findFirst({
      where: { id: entryId, campaignId, deletedAt: null },
    });
    if (!entry) throw new NotFoundException('Archive entry not found');
    // Plan task 3: creator OR manager can edit; other members are read-only.
    this.assertCanEdit(actor, campaign, entry.createdBy);
    if (input.kind !== undefined && !kinds.has(input.kind)) throw new BadRequestException('Invalid archive entry kind');
    if (input.title !== undefined && !input.title.trim()) throw new BadRequestException('Archive title is required');

    const wiki = validateWikiFields(input);
    const data: Prisma.CampaignArchiveEntryUpdateInput = { updatedBy: actor.userId };
    if (input.kind !== undefined) data.kind = input.kind;
    if (input.title !== undefined) data.title = input.title.trim();
    if (input.summary !== undefined) data.summary = input.summary.trim();
    if (input.pinned !== undefined) data.pinned = input.pinned;

    // Merge wiki fields into the existing payload so partial updates don't
    // wipe unrelated metadata (sourceMessageId, relatedActorId, etc.).
    if (input.payload !== undefined || wiki.bodyBlocks !== undefined || wiki.tags !== undefined || wiki.links !== undefined || wiki.attachmentRefs !== undefined) {
      const existingPayload = (entry.payload && typeof entry.payload === 'object')
        ? (entry.payload as Record<string, unknown>)
        : {};
      const merged = mergeWikiIntoPayload(
        input.payload !== undefined ? { ...existingPayload, ...input.payload } : existingPayload,
        wiki,
      );
      data.payload = merged as Prisma.InputJsonValue;
    }
    return this.prisma.campaignArchiveEntry.update({ where: { id: entryId }, data });
  }

  async archive(actor: AccessTokenPayload, campaignId: string, entryId: string) {
    const campaign = await this.context(campaignId);
    const entry = await this.prisma.campaignArchiveEntry.findFirst({
      where: { id: entryId, campaignId, deletedAt: null },
    });
    if (!entry) throw new NotFoundException('Archive entry not found');
    this.assertCanEdit(actor, campaign, entry.createdBy);
    return this.prisma.campaignArchiveEntry.update({
      where: { id: entryId },
      data: { deletedAt: new Date(), updatedBy: actor.userId },
    });
  }

  private assertCanEdit(
    actor: AccessTokenPayload,
    campaign: { campaignId: string; ownerId: string; members: { userId: string; role: string }[] },
    createdBy: string,
  ): void {
    if (createdBy === actor.userId) return;
    this.policy.canManageCampaign(actor, campaign);
  }

  private async context(campaignId: string) {
    const campaign = await this.prisma.campaign.findUnique({ where: { id: campaignId }, include: { members: true } });
    if (!campaign) throw new NotFoundException('Campaign not found');
    return { campaignId: campaign.id, ownerId: campaign.ownerId, members: campaign.members.map(member => ({ userId: member.userId, role: member.role })) };
  }
}
