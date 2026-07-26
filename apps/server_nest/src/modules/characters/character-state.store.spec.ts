import { CharacterStateStore } from './character-state.store';

describe('CharacterStateStore', () => {
  const prisma = {
    characterState: {
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    character: { findUnique: jest.fn() },
  };

  beforeEach(() => jest.resetAllMocks());

  it('creates a campaign-scoped state from legacy character fields', async () => {
    prisma.characterState.findUnique.mockResolvedValue(null);
    prisma.character.findUnique.mockResolvedValue({
      id: 'character-1',
      currentHp: 7,
      maxHp: 12,
      inventory: [],
      data: { runtime: { temporaryHp: 2 } },
    });
    prisma.characterState.create.mockImplementation(async ({ data }) => ({
      id: 'state-1',
      revision: 1,
      ...data,
    }));
    const store = new CharacterStateStore(prisma as never);

    const state = await store.getOrCreate(
      prisma as never,
      'character-1',
      'campaign-1',
    );

    expect(state.scopeKey).toBe('campaign:campaign-1');
    expect(state.state.hitPoints).toEqual({
      current: 7,
      maximum: 12,
      temporary: 2,
    });
  });
});
