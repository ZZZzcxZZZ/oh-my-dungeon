import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AccessTokenPayload } from '../auth/auth.types';
import type { CampaignContext } from '../campaigns/policies/campaign.policy';
import { SessionPolicy } from './policies/session.policy';
import type {
  CheckRequestView,
  CheckResponseView,
  CreateCheckRequestInput,
  RespondToCheckRequestInput
} from './check-requests.types';

@Injectable()
export class CheckRequestsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly policy: SessionPolicy
  ) {}

  async createCheckRequest(
    actor: AccessTokenPayload,
    sessionId: string,
    input: CreateCheckRequestInput
  ): Promise<CheckRequestView> {
    const { context } = await this.fetchSessionContext(sessionId);
    this.policy.canStartSession(actor, context);

    const created = await this.prismaService.checkRequest.create({
      data: {
        sessionId,
        requestedBy: actor.userId,
        label: input.label,
        checkType: input.checkType ?? 'skill',
        ability: input.ability,
        skill: input.skill,
        dc: input.dc,
        dcVisibility: input.dcVisibility ?? 'public',
        targetMode: input.targetMode ?? 'all',
        targetUserIds: input.targetUserIds ?? [],
        targetCharacterIds: input.targetCharacterIds ?? []
      },
      include: { responses: true }
    });

    return toCheckRequestView(created, true);
  }

  async listCheckRequests(
    actor: AccessTokenPayload,
    sessionId: string
  ): Promise<CheckRequestView[]> {
    const { context } = await this.fetchSessionContext(sessionId);
    this.policy.canViewSession(actor, context);
    const canViewDM = this.canViewDMContent(actor, context);

    const requests = await this.prismaService.checkRequest.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' },
      include: { responses: true }
    });

    return requests
      .filter((request: any) => canViewDM || isTargeted(actor, request))
      .map((request: any) => toCheckRequestView(request, canViewDM));
  }

  async respondToCheckRequest(
    actor: AccessTokenPayload,
    requestId: string,
    input: RespondToCheckRequestInput
  ): Promise<CheckResponseView> {
    const request = await this.fetchCheckRequest(requestId);
    const { context } = toSessionContext(request.session);
    this.policy.canViewSession(actor, context);

    if (request.status !== 'open') {
      throw new ConflictException('Check request is closed');
    }
    if (!isTargeted(actor, request, input.characterId)) {
      throw new ForbiddenException('Check request is not targeted to this user');
    }
    if (
      request.responses.some((response: any) => response.responderId === actor.userId)
    ) {
      throw new ConflictException('Check request already has a response');
    }

    const modifier = input.modifier ?? 0;
    const roll = 1 + Math.floor(Math.random() * 20);
    const total = roll + modifier;
    const notation = `1d20${modifier >= 0 ? '+' : ''}${modifier}`;
    const components = [
      { notation: '1d20', results: [roll] },
      { notation: `${modifier >= 0 ? '+' : ''}${modifier}`, results: [] }
    ];
    const result = getCheckResult(total, request.dc);

    const response = await this.prismaService.$transaction(async (tx) => {
      const created = await tx.checkResponse.create({
        data: {
          requestId,
          responderId: actor.userId,
          characterId: input.characterId,
          notation,
          total,
          components: components as unknown as object,
          result
        }
      });

      const diceRoll = await tx.diceRoll.create({
        data: {
          sessionId: request.sessionId,
          actorId: actor.userId,
          actorName: input.actorName,
          notation,
          total,
          components: components as unknown as object,
          visibility: 'public'
        }
      });

      await tx.chatMessage.create({
        data: {
          sessionId: request.sessionId,
          senderId: actor.userId,
          kind: 'roll',
          visibility: 'public',
          content: `${input.actorName} responded to ${request.label}: ${total}`
        }
      });

      await tx.journalEntry.create({
        data: {
          sessionId: request.sessionId,
          type: 'check_response',
          summary: `${input.actorName} responded to ${request.label}: ${total}`,
          refId: diceRoll.id
        }
      });

      return created;
    });

    return toCheckResponseView(response);
  }

  async closeCheckRequest(
    actor: AccessTokenPayload,
    requestId: string
  ): Promise<CheckRequestView> {
    const request = await this.fetchCheckRequest(requestId);
    const { context } = toSessionContext(request.session);
    this.policy.canStartSession(actor, context);

    const updated = await this.prismaService.checkRequest.update({
      where: { id: requestId },
      data: { status: 'closed' },
      include: { responses: true }
    });

    return toCheckRequestView(updated, true);
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

    return { session, context: toSessionContext(session).context };
  }

  private async fetchCheckRequest(requestId: string): Promise<any> {
    const request = await this.prismaService.checkRequest.findUnique({
      where: { id: requestId },
      include: {
        responses: true,
        session: {
          include: {
            campaign: { include: { members: true } },
            members: true
          }
        }
      }
    });

    if (!request) {
      throw new NotFoundException('Check request not found');
    }

    return request;
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
}

function toSessionContext(session: any): {
  context: CampaignContext;
} {
  const campaign = session.campaign;
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

function isTargeted(
  actor: AccessTokenPayload,
  request: any,
  characterId?: string
): boolean {
  const mode = request.targetMode ?? 'all';
  if (mode === 'all') return true;
  if (mode === 'users') {
    return toStringArray(request.targetUserIds).includes(actor.userId);
  }
  if (mode === 'characters') {
    if (!characterId) return false;
    return toStringArray(request.targetCharacterIds).includes(characterId);
  }
  return false;
}

function getCheckResult(total: number, dc: number | null | undefined): string {
  if (typeof dc !== 'number') return 'unknown';
  return total >= dc ? 'success' : 'failure';
}

function toCheckRequestView(request: any, canViewDC: boolean): CheckRequestView {
  return {
    id: request.id,
    sessionId: request.sessionId,
    requestedBy: request.requestedBy,
    label: request.label,
    checkType: request.checkType,
    ability: request.ability ?? null,
    skill: request.skill ?? null,
    dc: request.dcVisibility === 'hidden' && !canViewDC ? null : request.dc ?? null,
    dcVisibility: request.dcVisibility,
    targetMode: request.targetMode,
    targetUserIds: toStringArray(request.targetUserIds),
    targetCharacterIds: toStringArray(request.targetCharacterIds),
    status: request.status,
    createdAt: toIso(request.createdAt),
    updatedAt: toIso(request.updatedAt),
    responses: (request.responses ?? []).map((response: any) =>
      toCheckResponseView(response)
    )
  };
}

function toCheckResponseView(response: any): CheckResponseView {
  return {
    id: response.id,
    requestId: response.requestId,
    responderId: response.responderId,
    characterId: response.characterId ?? null,
    notation: response.notation,
    total: response.total,
    components: Array.isArray(response.components) ? response.components : [],
    result: response.result,
    createdAt: toIso(response.createdAt)
  };
}

function toStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === 'string')
    : [];
}

function toIso(value: any): string {
  return value instanceof Date ? value.toISOString() : value;
}
