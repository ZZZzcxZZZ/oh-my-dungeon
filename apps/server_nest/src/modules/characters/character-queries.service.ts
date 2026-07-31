import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import type { AccessTokenPayload } from '../auth/auth.types';
import { CharacterStateStore } from './character-state.store';

@Injectable()
export class CharacterQueriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stateStore: CharacterStateStore,
  ) {}

  async getResolved(
    user: AccessTokenPayload,
    characterId: string,
    campaignId: string | null,
  ) {
    const character = await this.loadAuthorizedCharacter(
      user,
      characterId,
      campaignId,
    );
    const scoped = await this.stateStore.get(characterId, campaignId);
    return {
      id: character.id,
      ownerUserId: character.ownerUserId,
      name: character.name,
      avatarUrl: character.avatarUrl ?? null,
      system: character.system,
      level: character.level,
      classSummary: character.classSummary,
      raceSummary: character.raceSummary,
      armorClass: character.armorClass,
      speed: character.speed,
      initiativeBonus: character.initiativeBonus,
      abilities: character.abilities,
      saves: character.saves,
      skills: character.skills,
      currency: character.currency,
      notes: character.notes,
      data: character.data,
      state: scoped.state,
      stateRevision: scoped.revision,
      stateScope: scoped.scopeKey,
      createdAt: toIso(character.createdAt),
      updatedAt: toIso(character.updatedAt),
    };
  }

  async getSummary(
    user: AccessTokenPayload,
    characterId: string,
    campaignId: string | null,
  ) {
    const character = await this.loadAuthorizedCharacter(
      user,
      characterId,
      campaignId,
    );
    const scoped = await this.stateStore.get(characterId, campaignId);
    return {
      id: character.id,
      name: character.name,
      level: character.level,
      classSummary: character.classSummary,
      raceSummary: character.raceSummary,
      hitPoints: scoped.state.hitPoints,
      conditions: scoped.state.conditions.map((item) => ({
        id: item.id,
        type: item.type,
      })),
      equipment: scoped.state.items
        .filter((item) => item.equipped)
        .map((item) => ({
          id: item.id,
          name: item.name,
          quantity: item.quantity,
        })),
      stateRevision: scoped.revision,
      stateScope: scoped.scopeKey,
    };
  }

  private async loadAuthorizedCharacter(
    user: AccessTokenPayload,
    characterId: string,
    campaignId: string | null,
  ) {
    const character = await this.prisma.character.findUnique({
      where: { id: characterId },
    });
    if (!character) throw new NotFoundException('Character not found');
    if (character.ownerUserId === user.userId) return character;
    if (!campaignId) throw new ForbiddenException('Character access denied');
    const campaign = await this.prisma.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true },
    });
    if (
      !campaign ||
      !campaign.members.some((member) => member.userId === user.userId)
    ) {
      throw new ForbiddenException('Character access denied');
    }
    return character;
  }
}

function toIso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : value;
}
