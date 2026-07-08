import {
  BadRequestException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AccessTokenPayload } from '../auth/auth.types';
import type { CampaignContext } from '../campaigns/policies/campaign.policy';
import { SessionsGateway } from '../realtime/sessions.gateway';
import { SessionPolicy } from './policies/session.policy';
import type {
  ChatMessageView,
  CreateChatMessageInput,
  CreateDiceRollInput,
  CreateSessionInput,
  DiceRollComponent,
  DiceRollView,
  JournalEntryView,
  SessionMemberView,
  SessionView
} from './sessions.types';

const RECENT_MESSAGE_LIMIT = 50;

@Injectable()
export class SessionsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly policy: SessionPolicy,
    private readonly gateway: SessionsGateway
  ) {}

  async createSession(
    actor: AccessTokenPayload,
    campaignId: string,
    input: CreateSessionInput
  ): Promise<SessionView> {
    const { context } = await this.fetchCampaignContext(campaignId);
    this.policy.canCreateSession(actor, context);

    const membership = await this.prismaService.campaignMember.findUnique({
      where: { campaignId_userId: { campaignId, userId: actor.userId } }
    });
    if (!membership) {
      throw new NotFoundException('Campaign membership not found');
    }

    const session = await this.prismaService.$transaction(async (tx) => {
      const created = await tx.session.create({
        data: {
          campaignId,
          name: input.name,
          status: 'scheduled'
        }
      });

      await tx.sessionMember.create({
        data: {
          sessionId: created.id,
          userId: actor.userId,
          role: membership.role
        }
      });

      return created;
    });

    return toSessionView(session);
  }

  async listSessions(
    actor: AccessTokenPayload,
    campaignId: string
  ): Promise<SessionView[]> {
    const { context } = await this.fetchCampaignContext(campaignId);
    this.policy.canViewSession(actor, context);

    const sessions = await this.prismaService.session.findMany({
      where: { campaignId }
    });

    return sessions.map((session: any) => toSessionView(session));
  }

  async getSession(
    actor: AccessTokenPayload,
    sessionId: string
  ): Promise<SessionView> {
    const { context, session } = await this.fetchSessionContext(sessionId);
    this.policy.canViewSession(actor, context);

    const recentMessages = await this.prismaService.chatMessage.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'desc' },
      take: RECENT_MESSAGE_LIMIT
    });

    const view = toSessionView(session);
    view.members = (session.members ?? []).map((member: any) =>
      toSessionMemberView(member)
    );
    view.recentMessages = recentMessages
      .map((message: any) => toChatMessageView(message))
      .reverse();
    return view;
  }

  async startSession(
    actor: AccessTokenPayload,
    sessionId: string
  ): Promise<SessionView> {
    const { context, session } = await this.fetchSessionContext(sessionId);
    this.policy.canStartSession(actor, context);

    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.session.update({
        where: { id: sessionId },
        data: {
          status: 'active',
          startedAt: new Date()
        }
      });

      await tx.journalEntry.create({
        data: {
          sessionId,
          type: 'session_started',
          summary: `Session "${session.name}" started`
        }
      });

      return result;
    });

    return toSessionView(updated);
  }

  async endSession(
    actor: AccessTokenPayload,
    sessionId: string
  ): Promise<SessionView> {
    const { context, session } = await this.fetchSessionContext(sessionId);
    this.policy.canEndSession(actor, context);

    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.session.update({
        where: { id: sessionId },
        data: {
          status: 'ended',
          endedAt: new Date()
        }
      });

      await tx.journalEntry.create({
        data: {
          sessionId,
          type: 'session_ended',
          summary: `Session "${session.name}" ended`
        }
      });

      return result;
    });

    return toSessionView(updated);
  }

  async listMessages(
    actor: AccessTokenPayload,
    sessionId: string
  ): Promise<ChatMessageView[]> {
    const { context } = await this.fetchSessionContext(sessionId);
    this.policy.canViewSession(actor, context);

    const messages = await this.prismaService.chatMessage.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' }
    });

    const canViewDM = this.canViewDMContent(actor, context);
    return messages
      .filter((message: any) => canViewDM || message.visibility !== 'dm')
      .map((message: any) => toChatMessageView(message));
  }

  async sendMessage(
    actor: AccessTokenPayload,
    sessionId: string,
    input: CreateChatMessageInput
  ): Promise<ChatMessageView> {
    const { context } = await this.fetchSessionContext(sessionId);
    this.policy.canViewSession(actor, context);

    const visibility = input.visibility ?? 'public';
    if (visibility === 'dm') {
      this.policy.canSendDMMessage(actor, context);
    }

    const kind = input.kind ?? 'text';
    const created = await this.prismaService.chatMessage.create({
      data: {
        sessionId,
        senderId: actor.userId,
        kind,
        visibility,
        content: input.content
      }
    });

    const view = toChatMessageView(created);
    if (visibility === 'dm') {
      this.gateway.broadcastToSessionManagers(sessionId, 'message:new', view);
    } else {
      this.gateway.broadcastToSession(sessionId, 'message:new', view);
    }

    return view;
  }

  async listRolls(
    actor: AccessTokenPayload,
    sessionId: string
  ): Promise<DiceRollView[]> {
    const { context } = await this.fetchSessionContext(sessionId);
    this.policy.canViewSession(actor, context);

    const rolls = await this.prismaService.diceRoll.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' }
    });

    const canViewDM = this.canViewDMContent(actor, context);
    return rolls
      .filter((roll: any) =>
        canViewDM || (roll.visibility !== 'dm' && roll.visibility !== 'blind')
      )
      .map((roll: any) => toDiceRollView(roll));
  }

  async createRoll(
    actor: AccessTokenPayload,
    sessionId: string,
    input: CreateDiceRollInput
  ): Promise<DiceRollView> {
    const { context } = await this.fetchSessionContext(sessionId);
    this.policy.canViewSession(actor, context);

    const visibility = input.visibility ?? 'public';
    if (visibility === 'dm' || visibility === 'blind') {
      this.policy.canRollDM(actor, context);
    }

    const { total, components } = parseDiceNotation(input.notation);

    const roll = await this.prismaService.$transaction(async (tx) => {
      const created = await tx.diceRoll.create({
        data: {
          sessionId,
          actorId: actor.userId,
          actorName: input.actorName,
          notation: input.notation,
          total,
          components: components as unknown as object,
          visibility
        }
      });

      await tx.journalEntry.create({
        data: {
          sessionId,
          type: 'roll',
          summary: `${input.actorName} rolled ${input.notation} = ${total}`,
          refId: created.id
        }
      });

      return created;
    });

    const view = toDiceRollView(roll);
    if (visibility === 'dm' || visibility === 'blind') {
      this.gateway.broadcastToSessionManagers(sessionId, 'roll:new', view);
    } else {
      this.gateway.broadcastToSession(sessionId, 'roll:new', view);
    }

    return view;
  }

  async listJournal(
    actor: AccessTokenPayload,
    sessionId: string
  ): Promise<JournalEntryView[]> {
    const { context } = await this.fetchSessionContext(sessionId);
    this.policy.canViewSession(actor, context);

    const entries = await this.prismaService.journalEntry.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' }
    });

    return entries.map((entry: any) => toJournalEntryView(entry));
  }

  private canViewDMContent(
    actor: AccessTokenPayload,
    context: CampaignContext
  ): boolean {
    try {
      this.policy.canViewDMContent(actor, context);
      return true;
    } catch {
      return false;
    }
  }

  private async fetchCampaignContext(campaignId: string): Promise<{
    context: CampaignContext;
  }> {
    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true }
    });

    if (!campaign) {
      throw new NotFoundException('Campaign not found');
    }

    return {
      context: {
        campaignId: campaign.id,
        ownerId: campaign.ownerId,
        members: campaign.members.map((member: any) => ({
          userId: member.userId,
          role: member.role
        }))
      }
    };
  }

  private async fetchSessionContext(sessionId: string): Promise<{
    session: any;
    context: CampaignContext;
  }> {
    const session = await this.prismaService.session.findUnique({
      where: { id: sessionId },
      include: {
        campaign: { include: { members: true } },
        members: true
      }
    });

    if (!session) {
      throw new NotFoundException('Session not found');
    }

    const campaign = session.campaign;
    return {
      session,
      context: {
        campaignId: campaign.id,
        ownerId: campaign.ownerId,
        members: campaign.members.map((member: any) => ({
          userId: member.userId,
          role: member.role
        }))
      }
    };
  }
}

function toSessionView(session: any): SessionView {
  return {
    id: session.id,
    campaignId: session.campaignId,
    name: session.name,
    status: session.status,
    startedAt: toIsoOrNull(session.startedAt),
    endedAt: toIsoOrNull(session.endedAt),
    createdAt: toIso(session.createdAt),
    updatedAt: toIso(session.updatedAt)
  };
}

function toSessionMemberView(member: any): SessionMemberView {
  return {
    id: member.id,
    sessionId: member.sessionId,
    userId: member.userId,
    role: member.role,
    joinedAt: toIso(member.joinedAt),
    leftAt: toIsoOrNull(member.leftAt)
  };
}

function toChatMessageView(message: any): ChatMessageView {
  return {
    id: message.id,
    sessionId: message.sessionId,
    senderId: message.senderId,
    kind: message.kind,
    visibility: message.visibility,
    content: message.content,
    createdAt: toIso(message.createdAt)
  };
}

function toDiceRollView(roll: any): DiceRollView {
  return {
    id: roll.id,
    sessionId: roll.sessionId,
    actorId: roll.actorId,
    actorName: roll.actorName,
    notation: roll.notation,
    total: roll.total,
    components: Array.isArray(roll.components) ? roll.components : [],
    visibility: roll.visibility,
    createdAt: toIso(roll.createdAt)
  };
}

function toJournalEntryView(entry: any): JournalEntryView {
  return {
    id: entry.id,
    sessionId: entry.sessionId,
    type: entry.type,
    summary: entry.summary,
    refId: entry.refId ?? null,
    createdAt: toIso(entry.createdAt)
  };
}

function toIso(value: any): string {
  return value instanceof Date ? value.toISOString() : value;
}

function toIsoOrNull(value: any): string | null {
  if (value === null || value === undefined) return null;
  return value instanceof Date ? value.toISOString() : value;
}

function parseDiceNotation(
  notation: string
): { total: number; components: DiceRollComponent[] } {
  if (typeof notation !== 'string' || notation.trim().length === 0) {
    throw new BadRequestException('Dice notation is required');
  }

  const normalized = notation.replace(/\s+/g, '').toLowerCase();
  if (!/^[0-9d+\-]+$/.test(normalized)) {
    throw new BadRequestException(`Invalid dice notation: ${notation}`);
  }

  const terms: Array<{ sign: number; raw: string }> = [];
  const tokenRegex = /([+-]?)([^+-]+)/g;
  let match;
  while ((match = tokenRegex.exec(normalized)) !== null) {
    const sign = match[1] === '-' ? -1 : 1;
    terms.push({ sign, raw: match[2] });
  }

  if (terms.length === 0) {
    throw new BadRequestException(`Invalid dice notation: ${notation}`);
  }

  let total = 0;
  const components: DiceRollComponent[] = [];

  for (const term of terms) {
    const diceMatch = term.raw.match(/^(\d*)d(\d+)$/);
    if (diceMatch) {
      const count = diceMatch[1] ? parseInt(diceMatch[1], 10) : 1;
      const sides = parseInt(diceMatch[2], 10);
      if (count < 1 || sides < 1) {
        throw new BadRequestException(`Invalid dice term: ${term.raw}`);
      }
      const results: number[] = [];
      for (let i = 0; i < count; i++) {
        results.push(1 + Math.floor(Math.random() * sides));
      }
      const subtotal = results.reduce((a, b) => a + b, 0);
      total += term.sign * subtotal;
      components.push({
        notation: `${term.sign === -1 ? '-' : ''}${count}d${sides}`,
        results
      });
    } else {
      const modifier = parseInt(term.raw, 10);
      if (Number.isNaN(modifier)) {
        throw new BadRequestException(`Invalid dice term: ${term.raw}`);
      }
      total += term.sign * modifier;
      components.push({
        notation: `${term.sign === -1 ? '-' : '+'}${modifier}`,
        results: []
      });
    }
  }

  return { total, components };
}
