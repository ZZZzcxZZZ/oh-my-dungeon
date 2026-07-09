import {
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AccessTokenPayload } from '../auth/auth.types';
import type {
  BindCharacterInput,
  AdjustCharacterHpInput,
  CharacterCampaignBindingView,
  CharacterView,
  CreateCharacterInput,
  UpdateCharacterInput
} from './characters.types';

const MANAGE_ROLES = new Set(['owner', 'dm']);
const VIEW_ROLES = new Set(['owner', 'dm', 'player', 'spectator']);

@Injectable()
export class CharactersService {
  constructor(private readonly prismaService: PrismaService) {}

  async createCharacter(
    actor: AccessTokenPayload,
    input: CreateCharacterInput
  ): Promise<CharacterView> {
    const character = await this.prismaService.character.create({
      data: {
        ownerUserId: actor.userId,
        name: input.name,
        avatarUrl: input.avatarUrl ?? null,
        system: input.system ?? 'dnd5e',
        level: input.level ?? 1,
        classSummary: input.classSummary ?? '',
        raceSummary: input.raceSummary ?? '',
        currentHp: input.currentHp ?? 0,
        maxHp: input.maxHp ?? 0,
        armorClass: input.armorClass ?? 10,
        speed: input.speed ?? 30,
        initiativeBonus: input.initiativeBonus ?? 0,
        abilities: input.abilities ?? defaultAbilities(),
        saves: input.saves ?? {},
        skills: input.skills ?? {},
        inventory: input.inventory ?? [],
        currency: input.currency ?? {},
        notes: input.notes ?? '',
        data: input.data ?? {}
      }
    });

    return toCharacterView(character);
  }

  async listOwnedCharacters(
    actor: AccessTokenPayload
  ): Promise<CharacterView[]> {
    const characters = await this.prismaService.character.findMany({
      where: { ownerUserId: actor.userId },
      orderBy: { updatedAt: 'desc' }
    });

    return characters.map(toCharacterView);
  }

  async getCharacter(
    actor: AccessTokenPayload,
    characterId: string
  ): Promise<CharacterView> {
    const character = await this.prismaService.character.findUnique({
      where: { id: characterId }
    });
    if (!character) {
      throw new NotFoundException('Character not found');
    }
    this.assertOwnsCharacter(actor, character);
    return toCharacterView(character);
  }

  async updateCharacter(
    actor: AccessTokenPayload,
    characterId: string,
    input: UpdateCharacterInput
  ): Promise<CharacterView> {
    const character = await this.prismaService.character.findUnique({
      where: { id: characterId }
    });
    if (!character) {
      throw new NotFoundException('Character not found');
    }
    this.assertOwnsCharacter(actor, character);

    if (input.campaignId) {
      await this.assertCampaignMembership(actor, input.campaignId);
    }

    const data = characterUpdateData(input);
    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.character.update({
        where: { id: characterId },
        data
      });

      if (input.campaignId) {
        await tx.journalEntry.create({
          data: {
            campaignId: input.campaignId,
            type: 'character_updated',
            summary: `${character.name} updated`,
            refId: characterId
          }
        });
      }

      return result;
    });

    return toCharacterView(updated);
  }

  async bindCharacterToCampaign(
    actor: AccessTokenPayload,
    characterId: string,
    input: BindCharacterInput
  ): Promise<CharacterCampaignBindingView> {
    const character = await this.prismaService.character.findUnique({
      where: { id: characterId }
    });
    if (!character) {
      throw new NotFoundException('Character not found');
    }
    this.assertOwnsCharacter(actor, character);

    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: input.campaignId },
      include: { members: true }
    });
    if (!campaign) {
      throw new NotFoundException('Campaign not found');
    }

    const membership = await this.prismaService.campaignMember.findUnique({
      where: {
        campaignId_userId: {
          campaignId: input.campaignId,
          userId: actor.userId
        }
      }
    });
    if (!membership) {
      throw new ForbiddenException(
        'Only campaign members can bind characters to this campaign'
      );
    }

    const binding = await this.prismaService.characterCampaignBinding.create({
      data: {
        campaignId: input.campaignId,
        characterId,
        userId: actor.userId,
        visibility: input.visibility ?? 'party',
        status: 'active',
        dmNotes: ''
      }
    });

    return toBindingView(binding);
  }

  async adjustCampaignCharacterHp(
    actor: AccessTokenPayload,
    campaignId: string,
    characterId: string,
    input: AdjustCharacterHpInput
  ): Promise<CharacterView> {
    if (input.delta === undefined && input.currentHp === undefined) {
      throw new ForbiddenException('HP adjustment requires delta or currentHp');
    }

    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true }
    });
    if (!campaign) {
      throw new NotFoundException('Campaign not found');
    }
    const role = this.getCampaignRole(actor, campaign);
    const canManage = actor.userId === campaign.ownerId || (role !== null && MANAGE_ROLES.has(role));
    if (!canManage) {
      throw new ForbiddenException('Only the owner or a DM can adjust character HP');
    }

    const binding =
      await this.prismaService.characterCampaignBinding.findUnique({
        where: {
          campaignId_characterId: {
            campaignId,
            characterId
          }
        },
        include: { character: true }
      });
    if (!binding) {
      throw new NotFoundException('Campaign character binding not found');
    }

    const previousHp = binding.character.currentHp;
    const nextHp = input.currentHp ?? previousHp + input.delta!;
    const updated = await this.prismaService.$transaction(async (tx) => {
      const result = await tx.character.update({
        where: { id: characterId },
        data: { currentHp: nextHp }
      });

      await tx.journalEntry.create({
        data: {
          campaignId,
          type: 'character_hp_changed',
          summary: `${binding.character.name} HP ${previousHp} -> ${nextHp}`,
          refId: characterId
        }
      });

      return result;
    });

    return toCharacterView(updated);
  }

  async listCampaignCharacters(
    actor: AccessTokenPayload,
    campaignId: string
  ): Promise<CharacterCampaignBindingView[]> {
    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true }
    });
    if (!campaign) {
      throw new NotFoundException('Campaign not found');
    }

    const role = this.getCampaignRole(actor, campaign);
    if (!role || !VIEW_ROLES.has(role)) {
      throw new ForbiddenException('You are not a member of this campaign');
    }
    const canManage = actor.userId === campaign.ownerId || MANAGE_ROLES.has(role);

    const bindings =
      await this.prismaService.characterCampaignBinding.findMany({
        where: { campaignId, status: 'active' },
        include: { character: true },
        orderBy: { joinedAt: 'asc' }
      });

    return bindings
      .filter((binding: any) => {
        if (canManage) return true;
        return (
          binding.userId === actor.userId ||
          binding.visibility === 'public' ||
          binding.visibility === 'party'
        );
      })
      .map(toBindingView);
  }

  private assertOwnsCharacter(actor: AccessTokenPayload, character: any): void {
    if (character.ownerUserId !== actor.userId) {
      throw new ForbiddenException('Only the character owner can do this');
    }
  }

  private async assertCampaignMembership(
    actor: AccessTokenPayload,
    campaignId: string
  ): Promise<void> {
    const membership = await this.prismaService.campaignMember.findUnique({
      where: {
        campaignId_userId: {
          campaignId,
          userId: actor.userId
        }
      }
    });
    if (!membership) {
      throw new ForbiddenException('Only campaign members can record character changes');
    }
  }

  private getCampaignRole(actor: AccessTokenPayload, campaign: any): string | null {
    if (actor.userId === campaign.ownerId) return 'owner';
    const member = (campaign.members ?? []).find(
      (item: any) => item.userId === actor.userId
    );
    return member?.role ?? null;
  }
}

function characterUpdateData(input: UpdateCharacterInput): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  setIfDefined(data, 'name', input.name);
  setIfDefined(data, 'avatarUrl', input.avatarUrl);
  setIfDefined(data, 'system', input.system);
  setIfDefined(data, 'level', input.level);
  setIfDefined(data, 'classSummary', input.classSummary);
  setIfDefined(data, 'raceSummary', input.raceSummary);
  setIfDefined(data, 'currentHp', input.currentHp);
  setIfDefined(data, 'maxHp', input.maxHp);
  setIfDefined(data, 'armorClass', input.armorClass);
  setIfDefined(data, 'speed', input.speed);
  setIfDefined(data, 'initiativeBonus', input.initiativeBonus);
  setIfDefined(data, 'abilities', input.abilities);
  setIfDefined(data, 'saves', input.saves);
  setIfDefined(data, 'skills', input.skills);
  setIfDefined(data, 'inventory', input.inventory);
  setIfDefined(data, 'currency', input.currency);
  setIfDefined(data, 'notes', input.notes);
  setIfDefined(data, 'data', input.data);
  return data;
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

function toCharacterView(character: any): CharacterView {
  return {
    id: character.id,
    ownerUserId: character.ownerUserId,
    name: character.name,
    avatarUrl: character.avatarUrl ?? null,
    system: character.system,
    level: character.level,
    classSummary: character.classSummary,
    raceSummary: character.raceSummary,
    currentHp: character.currentHp,
    maxHp: character.maxHp,
    armorClass: character.armorClass,
    speed: character.speed,
    initiativeBonus: character.initiativeBonus,
    abilities: character.abilities,
    saves: character.saves,
    skills: character.skills,
    inventory: character.inventory,
    currency: character.currency,
    notes: character.notes,
    data: character.data,
    createdAt: toIso(character.createdAt),
    updatedAt: toIso(character.updatedAt)
  };
}

function toBindingView(binding: any): CharacterCampaignBindingView {
  return {
    id: binding.id,
    campaignId: binding.campaignId,
    characterId: binding.characterId,
    userId: binding.userId,
    visibility: binding.visibility,
    status: binding.status,
    dmNotes: binding.dmNotes,
    joinedAt: toIso(binding.joinedAt),
    updatedAt: toIso(binding.updatedAt),
    character: binding.character ? toCharacterView(binding.character) : undefined
  };
}

function defaultAbilities(): Record<string, number> {
  return {
    str: 10,
    dex: 10,
    con: 10,
    int: 10,
    wis: 10,
    cha: 10
  };
}

function toIso(value: any): string {
  return value instanceof Date ? value.toISOString() : value;
}
