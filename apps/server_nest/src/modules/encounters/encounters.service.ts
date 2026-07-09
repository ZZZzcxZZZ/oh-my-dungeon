import {
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AccessTokenPayload } from '../auth/auth.types';
import { CampaignPolicy } from '../campaigns/policies/campaign.policy';
import type {
  EncounterParticipantView,
  EncounterView,
  NpcView
} from './encounters.types';

const MANAGE_ROLES = new Set(['owner', 'dm']);

@Injectable()
export class EncountersService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly campaignPolicy: CampaignPolicy
  ) {}

  async createNpc(
    actor: AccessTokenPayload,
    campaignId: string,
    input: {
      name: string;
      contentItemId?: string | null;
      publicDescription?: string;
      dmNotes?: string;
      stats?: unknown;
      tags?: unknown;
    }
  ): Promise<NpcView> {
    const campaign = await this.fetchCampaign(campaignId);
    this.assertCanManage(actor, campaign);

    const npc = await this.prismaService.npc.create({
      data: {
        campaignId,
        contentItemId: input.contentItemId ?? null,
        name: input.name,
        publicDescription: input.publicDescription ?? '',
        dmNotes: input.dmNotes ?? '',
        stats: input.stats ?? {},
        tags: input.tags ?? [],
        createdBy: actor.userId
      }
    });

    return toNpcView(npc);
  }

  async listNpcs(
    actor: AccessTokenPayload,
    campaignId: string
  ): Promise<NpcView[]> {
    const campaign = await this.fetchCampaign(campaignId);
    this.campaignPolicy.canViewCampaign(actor, toCampaignContext(campaign));

    const npcs = await this.prismaService.npc.findMany({
      where: { campaignId },
      orderBy: { updatedAt: 'desc' }
    });
    return npcs.map(toNpcView);
  }

  async createEncounter(
    actor: AccessTokenPayload,
    campaignId: string,
    input: { name: string; sessionId?: string | null }
  ): Promise<EncounterView> {
    const campaign = await this.fetchCampaign(campaignId);
    this.assertCanManage(actor, campaign);

    const encounter = await this.prismaService.encounter.create({
      data: {
        campaignId,
        sessionId: input.sessionId ?? null,
        name: input.name,
        status: 'draft',
        round: 0,
        currentTurnParticipantId: null,
        createdBy: actor.userId
      },
      include: { participants: true }
    });

    return toEncounterView(encounter, true);
  }

  async listEncounters(
    actor: AccessTokenPayload,
    campaignId: string
  ): Promise<EncounterView[]> {
    const campaign = await this.fetchCampaign(campaignId);
    const canManage = this.canManage(actor, campaign);
    this.campaignPolicy.canViewCampaign(actor, toCampaignContext(campaign));

    const encounters = await this.prismaService.encounter.findMany({
      where: { campaignId },
      include: { participants: true },
      orderBy: { updatedAt: 'desc' }
    });

    return encounters.map((encounter: any) =>
      toEncounterView(encounter, canManage)
    );
  }

  async getEncounter(
    actor: AccessTokenPayload,
    encounterId: string
  ): Promise<EncounterView> {
    const encounter = await this.fetchEncounter(encounterId);
    const canManage = this.canManage(actor, encounter.campaign);
    this.campaignPolicy.canViewCampaign(
      actor,
      toCampaignContext(encounter.campaign)
    );

    return toEncounterView(encounter, canManage);
  }

  async addParticipant(
    actor: AccessTokenPayload,
    encounterId: string,
    input: {
      participantType: string;
      characterId?: string;
      npcId?: string;
      displayName?: string;
      initiative?: number;
      hpCurrent?: number;
      hpMax?: number;
      armorClass?: number;
      isHiddenFromPlayers?: boolean;
    }
  ): Promise<EncounterParticipantView> {
    const encounter = await this.fetchEncounter(encounterId);
    this.assertCanManage(actor, encounter.campaign);

    const snapshot = await this.buildParticipantSnapshot(encounter, input);
    const participant = await this.prismaService.encounterParticipant.create({
      data: {
        encounterId,
        participantType: input.participantType,
        characterId: snapshot.characterId,
        npcId: snapshot.npcId,
        displayName: input.displayName ?? snapshot.displayName,
        initiative: input.initiative ?? 0,
        hpCurrent: input.hpCurrent ?? snapshot.hpCurrent,
        hpMax: input.hpMax ?? snapshot.hpMax,
        armorClass: input.armorClass ?? snapshot.armorClass,
        isHiddenFromPlayers: input.isHiddenFromPlayers ?? false,
        conditions: [],
        sortOrder: encounter.participants?.length ?? 0,
        snapshot
      }
    });

    return toParticipantView(participant);
  }

  async startEncounter(
    actor: AccessTokenPayload,
    encounterId: string
  ): Promise<EncounterView> {
    const encounter = await this.fetchEncounter(encounterId);
    this.assertCanManage(actor, encounter.campaign);
    const ordered = orderParticipants(encounter.participants ?? []);
    const first = ordered[0]?.id ?? null;

    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.encounter.update({
        where: { id: encounterId },
        data: {
          status: 'active',
          round: 1,
          currentTurnParticipantId: first
        },
        include: { participants: true }
      });
      await tx.journalEntry.create({
        data: {
          campaignId: encounter.campaignId,
          sessionId: encounter.sessionId ?? null,
          type: 'encounter_started',
          summary: `${encounter.name} started`,
          refId: encounterId
        }
      });
      return result;
    });

    return toEncounterView(updated, true);
  }

  async advanceTurn(
    actor: AccessTokenPayload,
    encounterId: string
  ): Promise<EncounterView> {
    const encounter = await this.fetchEncounter(encounterId);
    this.assertCanManage(actor, encounter.campaign);
    const ordered = orderParticipants(encounter.participants ?? []);
    const currentIndex = ordered.findIndex(
      (item: any) => item.id === encounter.currentTurnParticipantId
    );
    const nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % ordered.length;
    const wraps = ordered.length > 0 && currentIndex === ordered.length - 1;
    const next = ordered[nextIndex]?.id ?? null;
    const nextRound = wraps ? encounter.round + 1 : Math.max(encounter.round, 1);

    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.encounter.update({
        where: { id: encounterId },
        data: {
          status: 'active',
          round: nextRound,
          currentTurnParticipantId: next
        },
        include: { participants: true }
      });
      await tx.journalEntry.create({
        data: {
          campaignId: encounter.campaignId,
          sessionId: encounter.sessionId ?? null,
          type: 'encounter_turn_advanced',
          summary: `${encounter.name} advanced turn`,
          refId: encounterId
        }
      });
      return result;
    });

    return toEncounterView(updated, true);
  }

  async endEncounter(
    actor: AccessTokenPayload,
    encounterId: string
  ): Promise<EncounterView> {
    const encounter = await this.fetchEncounter(encounterId);
    this.assertCanManage(actor, encounter.campaign);

    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.encounter.update({
        where: { id: encounterId },
        data: { status: 'completed' },
        include: { participants: true }
      });
      await tx.journalEntry.create({
        data: {
          campaignId: encounter.campaignId,
          sessionId: encounter.sessionId ?? null,
          type: 'encounter_ended',
          summary: `${encounter.name} ended`,
          refId: encounterId
        }
      });
      return result;
    });

    return toEncounterView(updated, true);
  }

  async updateParticipant(
    actor: AccessTokenPayload,
    encounterId: string,
    participantId: string,
    input: {
      initiative?: number;
      hpCurrent?: number;
      hpMax?: number;
      armorClass?: number;
      conditions?: unknown;
      isHiddenFromPlayers?: boolean;
    }
  ): Promise<EncounterParticipantView> {
    const participant =
      await this.prismaService.encounterParticipant.findUnique({
        where: { id: participantId },
        include: { encounter: { include: { campaign: { include: { members: true } } } } }
      });
    if (!participant || participant.encounterId !== encounterId) {
      throw new NotFoundException('Encounter participant not found');
    }
    this.assertCanManage(actor, participant.encounter.campaign);

    const data: Record<string, unknown> = {};
    setIfDefined(data, 'initiative', input.initiative);
    setIfDefined(data, 'hpCurrent', input.hpCurrent);
    setIfDefined(data, 'hpMax', input.hpMax);
    setIfDefined(data, 'armorClass', input.armorClass);
    setIfDefined(data, 'conditions', input.conditions);
    setIfDefined(data, 'isHiddenFromPlayers', input.isHiddenFromPlayers);

    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.encounterParticipant.update({
        where: { id: participantId },
        data
      });
      await tx.journalEntry.create({
        data: {
          campaignId: participant.encounter.campaignId,
          sessionId: participant.encounter.sessionId ?? null,
          type: 'encounter_participant_updated',
          summary: `${participant.displayName} updated`,
          refId: participantId
        }
      });
      return result;
    });

    return toParticipantView(updated);
  }

  private async buildParticipantSnapshot(
    encounter: any,
    input: {
      participantType: string;
      characterId?: string;
      npcId?: string;
      displayName?: string;
    }
  ): Promise<any> {
    if (input.participantType === 'character') {
      if (!input.characterId) {
        throw new ForbiddenException('Character participant requires characterId');
      }
      const binding =
        await this.prismaService.characterCampaignBinding.findUnique({
          where: {
            campaignId_characterId: {
              campaignId: encounter.campaignId,
              characterId: input.characterId
            }
          },
          include: { character: true }
        });
      if (!binding) {
        throw new NotFoundException('Campaign character binding not found');
      }
      return {
        characterId: input.characterId,
        npcId: null,
        displayName: binding.character.name,
        hpCurrent: binding.character.currentHp,
        hpMax: binding.character.maxHp,
        armorClass: binding.character.armorClass
      };
    }

    if (input.npcId) {
      const npc = await this.prismaService.npc.findUnique({
        where: { id: input.npcId }
      });
      if (!npc || npc.campaignId !== encounter.campaignId) {
        throw new NotFoundException('Npc not found');
      }
      const stats = isRecord(npc.stats)
        ? (npc.stats as Record<string, unknown>)
        : {};
      return {
        characterId: null,
        npcId: input.npcId,
        displayName: npc.name,
        hpCurrent: numberFrom(stats.hpCurrent, numberFrom(stats.hpMax, 0)),
        hpMax: numberFrom(stats.hpMax, 0),
        armorClass: numberFrom(stats.armorClass, 10)
      };
    }

    return {
      characterId: null,
      npcId: null,
      displayName: input.displayName ?? 'Participant',
      hpCurrent: 0,
      hpMax: 0,
      armorClass: 10
    };
  }

  private async fetchCampaign(campaignId: string): Promise<any> {
    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true }
    });
    if (!campaign) {
      throw new NotFoundException('Campaign not found');
    }
    return campaign;
  }

  private async fetchEncounter(encounterId: string): Promise<any> {
    const encounter = await this.prismaService.encounter.findUnique({
      where: { id: encounterId },
      include: {
        campaign: { include: { members: true } },
        participants: true
      }
    });
    if (!encounter) {
      throw new NotFoundException('Encounter not found');
    }
    return encounter;
  }

  private assertCanManage(actor: AccessTokenPayload, campaign: any): void {
    this.campaignPolicy.canManageCampaign(actor, toCampaignContext(campaign));
  }

  private canManage(actor: AccessTokenPayload, campaign: any): boolean {
    if (actor.userId === campaign.ownerId) return true;
    const member = (campaign.members ?? []).find(
      (item: any) => item.userId === actor.userId
    );
    return member ? MANAGE_ROLES.has(member.role) : false;
  }
}

function toCampaignContext(campaign: any) {
  return {
    campaignId: campaign.id,
    ownerId: campaign.ownerId,
    members: (campaign.members ?? []).map((member: any) => ({
      userId: member.userId,
      role: member.role
    }))
  };
}

function toNpcView(npc: any): NpcView {
  return {
    id: npc.id,
    campaignId: npc.campaignId,
    contentItemId: npc.contentItemId ?? null,
    name: npc.name,
    publicDescription: npc.publicDescription,
    dmNotes: npc.dmNotes,
    stats: npc.stats,
    tags: npc.tags,
    createdBy: npc.createdBy,
    createdAt: toIso(npc.createdAt),
    updatedAt: toIso(npc.updatedAt)
  };
}

function toEncounterView(encounter: any, canManage: boolean): EncounterView {
  const participants = (encounter.participants ?? [])
    .filter((participant: any) => canManage || !participant.isHiddenFromPlayers)
    .map(toParticipantView);

  return {
    id: encounter.id,
    campaignId: encounter.campaignId,
    sessionId: encounter.sessionId ?? null,
    name: encounter.name,
    status: encounter.status,
    round: encounter.round,
    currentTurnParticipantId: encounter.currentTurnParticipantId ?? null,
    createdBy: encounter.createdBy,
    createdAt: toIso(encounter.createdAt),
    updatedAt: toIso(encounter.updatedAt),
    participants
  };
}

function toParticipantView(participant: any): EncounterParticipantView {
  return {
    id: participant.id,
    encounterId: participant.encounterId,
    participantType: participant.participantType,
    characterId: participant.characterId ?? null,
    npcId: participant.npcId ?? null,
    displayName: participant.displayName,
    initiative: participant.initiative,
    hpCurrent: participant.hpCurrent,
    hpMax: participant.hpMax,
    armorClass: participant.armorClass,
    conditions: participant.conditions,
    isHiddenFromPlayers: participant.isHiddenFromPlayers,
    sortOrder: participant.sortOrder,
    snapshot: participant.snapshot,
    createdAt: toIso(participant.createdAt),
    updatedAt: toIso(participant.updatedAt)
  };
}

function orderParticipants(participants: any[]): any[] {
  return [...participants].sort((left, right) => {
    const initiativeDelta = right.initiative - left.initiative;
    return initiativeDelta === 0
      ? left.sortOrder - right.sortOrder
      : initiativeDelta;
  });
}

function setIfDefined(
  target: Record<string, unknown>,
  key: string,
  value: unknown
): void {
  if (value !== undefined) {
    target[key] = value;
  }
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function numberFrom(value: unknown, fallback: number): number {
  return Number.isFinite(value) ? Number(value) : fallback;
}

function toIso(value: any): string {
  return value instanceof Date ? value.toISOString() : value;
}
