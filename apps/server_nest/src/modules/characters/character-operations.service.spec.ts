import { CharacterOperationsService } from './character-operations.service';
import { parseCharacterState } from './domain/character-state';

describe('CharacterOperationsService', () => {
  const prisma = {
    character: { findUnique: jest.fn(), update: jest.fn() },
    campaign: { findUnique: jest.fn() },
    characterState: { update: jest.fn() },
    gameEvent: { findUnique: jest.fn(), create: jest.fn() },
    $transaction: jest.fn(),
  };
  const stateStore = { getOrCreate: jest.fn() };
  const events = { append: jest.fn() };
  const actor = { userId: 'user-1', username: 'aria' };

  beforeEach(() => {
    jest.resetAllMocks();
    prisma.character.findUnique.mockResolvedValue({
      id: 'character-1',
      ownerUserId: 'user-1',
    });
    prisma.$transaction.mockImplementation(async (callback) => callback(prisma));
    prisma.characterState.update.mockImplementation(async ({ data }) => ({
      id: 'state-1',
      characterId: 'character-1',
      campaignId: null,
      scopeKey: 'local',
      revision: 2,
      stateJson: data.stateJson,
    }));
    events.append.mockImplementation(async (_client, input) => ({
      id: 'event-1',
      ...input,
    }));
    stateStore.getOrCreate.mockResolvedValue({
      id: 'state-1',
      characterId: 'character-1',
      campaignId: null,
      scopeKey: 'local',
      revision: 1,
      state: parseCharacterState({
        hitPoints: { current: 25, maximum: 40, temporary: 0 },
        resources: [
          {
            id: 'second-wind',
            name: '回气',
            current: 1,
            maximum: 1,
            restoreOn: 'shortRest',
          },
        ],
      }),
    });
  });

  it('adjusts HP, updates compatibility cache and records before/after', async () => {
    const service = new CharacterOperationsService(
      prisma as never,
      stateStore as never,
      events as never,
    );

    const result = await service.adjustHitPoints(actor, 'character-1', {
      requestId: 'request-1',
      delta: -8,
    });

    expect(result.state.hitPoints.current).toBe(17);
    expect(prisma.character.update).toHaveBeenCalledWith({
      where: { id: 'character-1' },
      data: { currentHp: 17, maxHp: 40 },
    });
    expect(events.append).toHaveBeenCalledWith(
      prisma,
      expect.objectContaining({
        type: 'character.hp.adjusted',
        before: { current: 25, temporary: 0 },
        after: { current: 17, temporary: 0 },
      }),
    );
  });

  it('adds a structured condition', async () => {
    const service = new CharacterOperationsService(
      prisma as never,
      stateStore as never,
      events as never,
    );

    const result = await service.addCondition(actor, 'character-1', {
      requestId: 'request-2',
      condition: { id: 'poison-1', type: 'poisoned', remaining: 2 },
    });

    expect(result.state.conditions[0]).toEqual(
      expect.objectContaining({ id: 'poison-1', type: 'poisoned' }),
    );
  });

  it('consumes a resource without allowing a negative value', async () => {
    const service = new CharacterOperationsService(
      prisma as never,
      stateStore as never,
      events as never,
    );

    const result = await service.consumeResource(actor, 'character-1', {
      requestId: 'request-3',
      resourceId: 'second-wind',
      amount: 2,
    });

    expect(result.state.resources[0].current).toBe(0);
  });

  it('grants a structured item instance', async () => {
    const service = new CharacterOperationsService(
      prisma as never,
      stateStore as never,
      events as never,
    );

    const result = await service.grantItem(actor, 'character-1', {
      requestId: 'request-4',
      item: { id: 'potion-1', name: '治疗药水', quantity: 2 },
    });

    expect(result.state.items[0]).toEqual(
      expect.objectContaining({ id: 'potion-1', quantity: 2 }),
    );
  });

  it('transfers item quantity between two character states atomically', async () => {
    stateStore.getOrCreate
      .mockResolvedValueOnce({
        id: 'source-state',
        characterId: 'character-1',
        campaignId: 'campaign-1',
        scopeKey: 'campaign:campaign-1',
        revision: 1,
        state: parseCharacterState({
          hitPoints: { current: 10, maximum: 10 },
          items: [{ id: 'potion-1', name: '治疗药水', quantity: 3 }],
        }),
      })
      .mockResolvedValueOnce({
        id: 'target-state',
        characterId: 'character-2',
        campaignId: 'campaign-1',
        scopeKey: 'campaign:campaign-1',
        revision: 1,
        state: parseCharacterState({
          hitPoints: { current: 10, maximum: 10 },
        }),
      });
    prisma.character.findUnique
      .mockResolvedValueOnce({
        id: 'character-1',
        ownerUserId: 'user-1',
      })
      .mockResolvedValueOnce({
        id: 'character-2',
        ownerUserId: 'user-2',
      });
    prisma.campaign.findUnique.mockResolvedValue({
      id: 'campaign-1',
      ownerId: 'dm-1',
      members: [
        { userId: 'user-1', role: 'player' },
        { userId: 'user-2', role: 'player' },
      ],
    });
    prisma.characterState.update
      .mockImplementation(async ({ where, data }) => ({
        id: where.id,
        revision: 2,
        stateJson: data.stateJson,
      }));
    const service = new CharacterOperationsService(
      prisma as never,
      stateStore as never,
      events as never,
    );

    const result = await service.transferItem(actor, 'character-1', {
      requestId: 'request-5',
      campaignId: 'campaign-1',
      targetCharacterId: 'character-2',
      itemId: 'potion-1',
      quantity: 2,
    });

    expect(result.sourceState.items[0].quantity).toBe(1);
    expect(result.targetState.items[0].quantity).toBe(2);
    expect(prisma.characterState.update).toHaveBeenCalledTimes(2);
  });
});
