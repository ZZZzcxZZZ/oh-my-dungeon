import { GameEventsService } from './game-events.service';

describe('GameEventsService', () => {
  const prisma = {
    gameEvent: {
      findMany: jest.fn(),
      create: jest.fn(),
      findUnique: jest.fn(),
    },
  };

  beforeEach(() => jest.resetAllMocks());

  it('filters character events by cursor, type and time', async () => {
    prisma.gameEvent.findMany.mockResolvedValue([]);
    const service = new GameEventsService(prisma as never);

    await service.listCharacterEvents('character-1', {
      cursor: 'event-10',
      type: 'character.hp.adjusted',
      since: new Date('2026-07-01T00:00:00.000Z'),
      limit: 20,
    });

    expect(prisma.gameEvent.findMany).toHaveBeenCalledWith({
      where: {
        characterId: 'character-1',
        type: 'character.hp.adjusted',
        occurredAt: { gte: new Date('2026-07-01T00:00:00.000Z') },
      },
      orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
      cursor: { id: 'event-10' },
      skip: 1,
      take: 20,
    });
  });

  it('returns the existing event for a repeated request id', async () => {
    const existing = { id: 'event-1', requestId: 'request-1' };
    prisma.gameEvent.findUnique.mockResolvedValue(existing);
    const service = new GameEventsService(prisma as never);

    const result = await service.append(prisma as never, {
      type: 'character.hp.adjusted',
      characterId: 'character-1',
      initiatorType: 'user',
      initiatorId: 'user-1',
      requestId: 'request-1',
      targets: [],
      before: {},
      after: {},
      payload: {},
    });

    expect(result).toBe(existing);
    expect(prisma.gameEvent.create).not.toHaveBeenCalled();
  });
});
