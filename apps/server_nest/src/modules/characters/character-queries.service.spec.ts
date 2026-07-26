import { CharacterQueriesService } from './character-queries.service';
import { parseCharacterState } from './domain/character-state';

describe('CharacterQueriesService', () => {
  const prisma = {
    character: { findUnique: jest.fn() },
    campaign: { findUnique: jest.fn() },
  };
  const stateStore = { get: jest.fn() };
  const actor = { userId: 'user-1', username: 'aria' };

  beforeEach(() => {
    jest.resetAllMocks();
    prisma.character.findUnique.mockResolvedValue({
      id: 'character-1',
      ownerUserId: 'user-1',
      name: '艾莉娅',
      avatarUrl: null,
      system: 'dnd5e-2024',
      level: 5,
      classSummary: '法师',
      raceSummary: '精灵',
      currentHp: 1,
      maxHp: 1,
      armorClass: 15,
      speed: 30,
      initiativeBonus: 2,
      abilities: {},
      saves: {},
      skills: {},
      inventory: [],
      currency: {},
      notes: '',
      data: {},
      createdAt: new Date('2026-07-01T00:00:00.000Z'),
      updatedAt: new Date('2026-07-02T00:00:00.000Z'),
    });
    stateStore.get.mockResolvedValue({
      revision: 4,
      scopeKey: 'campaign:campaign-1',
      state: parseCharacterState({
        hitPoints: { current: 24, maximum: 35, temporary: 0 },
        conditions: [{ id: 'poison-1', type: 'poisoned' }],
        items: [{ id: 'staff-1', name: '法杖', quantity: 1, equipped: true }],
      }),
    });
  });

  it('returns a compact machine-readable summary', async () => {
    const service = new CharacterQueriesService(
      prisma as never,
      stateStore as never,
    );

    const summary = await service.getSummary(
      actor,
      'character-1',
      'campaign-1',
    );

    expect(summary).toEqual({
      id: 'character-1',
      name: '艾莉娅',
      level: 5,
      classSummary: '法师',
      raceSummary: '精灵',
      hitPoints: { current: 24, maximum: 35, temporary: 0 },
      conditions: [{ id: 'poison-1', type: 'poisoned' }],
      equipment: [{ id: 'staff-1', name: '法杖', quantity: 1 }],
      stateRevision: 4,
      stateScope: 'campaign:campaign-1',
    });
  });
});
