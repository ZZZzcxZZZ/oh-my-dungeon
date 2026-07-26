import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CharacterState,
  parseCharacterState,
  serializeCharacterState,
} from './domain/character-state';

type StateClient =
  | PrismaService
  | PrismaClient
  | Prisma.TransactionClient;

export interface ScopedCharacterState {
  id: string;
  characterId: string;
  campaignId: string | null;
  scopeKey: string;
  revision: number;
  state: CharacterState;
}

@Injectable()
export class CharacterStateStore {
  constructor(private readonly prisma: PrismaService) {}

  async getOrCreate(
    client: StateClient,
    characterId: string,
    campaignId: string | null,
  ): Promise<ScopedCharacterState> {
    const scopeKey = campaignId ? `campaign:${campaignId}` : 'local';
    const existing = await client.characterState.findUnique({
      where: { characterId_scopeKey: { characterId, scopeKey } },
    });
    if (existing) return toScopedState(existing);

    const character = await client.character.findUnique({
      where: { id: characterId },
    });
    if (!character) throw new NotFoundException('Character not found');
    const data =
      character.data && typeof character.data === 'object'
        ? (character.data as Record<string, unknown>)
        : {};
    const state = parseCharacterState({
      ...data,
      currentHp: character.currentHp,
      maxHp: character.maxHp,
      inventory: character.inventory,
    });
    const created = await client.characterState.create({
      data: {
        characterId,
        campaignId,
        scopeKey,
        stateJson: serializeCharacterState(state) as Prisma.InputJsonValue,
      },
    });
    return toScopedState(created);
  }

  async get(
    characterId: string,
    campaignId: string | null,
  ): Promise<ScopedCharacterState> {
    return this.getOrCreate(this.prisma, characterId, campaignId);
  }
}

function toScopedState(row: {
  id: string;
  characterId: string;
  campaignId: string | null;
  scopeKey: string;
  revision: number;
  stateJson: unknown;
}): ScopedCharacterState {
  return {
    id: row.id,
    characterId: row.characterId,
    campaignId: row.campaignId,
    scopeKey: row.scopeKey,
    revision: row.revision,
    state: parseCharacterState(row.stateJson),
  };
}
