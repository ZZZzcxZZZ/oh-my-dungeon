import {
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AccessTokenPayload } from '../auth/auth.types';
import type {
  CharacterView,
  CreateCharacterInput,
  UpdateCharacterInput
} from './characters.types';
import { parseCharacterState } from './domain/character-state';

@Injectable()
export class CharactersService {
  constructor(private readonly prismaService: PrismaService) {}

  async createCharacter(
    user: AccessTokenPayload,
    input: CreateCharacterInput
  ): Promise<CharacterView> {
    const character = await this.prismaService.character.create({
      data: {
        ownerUserId: user.userId,
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
    user: AccessTokenPayload
  ): Promise<CharacterView[]> {
    const characters = await this.prismaService.character.findMany({
      where: { ownerUserId: user.userId },
      orderBy: { updatedAt: 'desc' }
    });

    return characters.map(toCharacterView);
  }

  async getCharacter(
    user: AccessTokenPayload,
    characterId: string
  ): Promise<CharacterView> {
    const character = await this.prismaService.character.findUnique({
      where: { id: characterId }
    });
    if (!character) {
      throw new NotFoundException('Character not found');
    }
    this.assertOwnsCharacter(user, character);
    return toCharacterView(character);
  }

  async updateCharacter(
    user: AccessTokenPayload,
    characterId: string,
    input: UpdateCharacterInput
  ): Promise<CharacterView> {
    const character = await this.prismaService.character.findUnique({
      where: { id: characterId }
    });
    if (!character) {
      throw new NotFoundException('Character not found');
    }
    this.assertOwnsCharacter(user, character);

    if (input.campaignId) {
      await this.assertCampaignMembership(user, input.campaignId);
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

  private assertOwnsCharacter(user: AccessTokenPayload, character: any): void {
    if (character.ownerUserId !== user.userId) {
      throw new ForbiddenException('Only the character owner can do this');
    }
  }

  private async assertCampaignMembership(
    user: AccessTokenPayload,
    campaignId: string
  ): Promise<void> {
    const membership = await this.prismaService.campaignMember.findUnique({
      where: {
        campaignId_userId: {
          campaignId,
          userId: user.userId
        }
      }
    });
    if (!membership) {
      throw new ForbiddenException('Only campaign members can record character changes');
    }
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
  const data =
    character.data && typeof character.data === 'object'
      ? (character.data as Record<string, unknown>)
      : {};
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
    state: parseCharacterState({
      ...data,
      currentHp: character.currentHp,
      maxHp: character.maxHp,
      inventory: character.inventory
    }),
    createdAt: toIso(character.createdAt),
    updatedAt: toIso(character.updatedAt)
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
