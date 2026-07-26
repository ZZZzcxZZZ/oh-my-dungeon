import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import type {
  AppendGameEventInput,
  GameEventQuery,
} from './game-events.types';

type EventClient = Pick<PrismaService, 'gameEvent'> | Prisma.TransactionClient;

@Injectable()
export class GameEventsService {
  constructor(private readonly prisma: PrismaService) {}

  async append(client: EventClient, input: AppendGameEventInput) {
    const existing = await client.gameEvent.findUnique({
      where: { requestId: input.requestId },
    });
    if (existing) return existing;
    return client.gameEvent.create({
      data: {
        schemaVersion: 1,
        type: input.type,
        campaignId: input.campaignId ?? null,
        characterId: input.characterId ?? null,
        actorType: input.actorType,
        actorId: input.actorId,
        requestId: input.requestId,
        targets: input.targets as Prisma.InputJsonValue,
        cause: input.cause
          ? (input.cause as Prisma.InputJsonValue)
          : Prisma.JsonNull,
        before: input.before as Prisma.InputJsonValue,
        after: input.after as Prisma.InputJsonValue,
        payload: input.payload as Prisma.InputJsonValue,
      },
    });
  }

  listCharacterEvents(characterId: string, query: GameEventQuery) {
    const take = Math.min(100, Math.max(1, query.limit ?? 50));
    return this.prisma.gameEvent.findMany({
      where: {
        characterId,
        ...(query.type ? { type: query.type } : {}),
        ...(query.since ? { occurredAt: { gte: query.since } } : {}),
      },
      orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
      ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
      take,
    });
  }

  listCampaignEvents(campaignId: string, query: GameEventQuery) {
    const take = Math.min(100, Math.max(1, query.limit ?? 50));
    return this.prisma.gameEvent.findMany({
      where: {
        campaignId,
        ...(query.type ? { type: query.type } : {}),
        ...(query.since ? { occurredAt: { gte: query.since } } : {}),
      },
      orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
      ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
      take,
    });
  }
}
