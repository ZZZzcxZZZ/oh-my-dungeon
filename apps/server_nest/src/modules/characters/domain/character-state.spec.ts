import {
  parseCharacterState,
  serializeCharacterState,
} from './character-state';

describe('character state v2', () => {
  it('adapts legacy hp text into structured hit points', () => {
    expect(parseCharacterState({ hp: '25/40' })).toEqual(
      expect.objectContaining({
        schemaVersion: 2,
        hitPoints: { current: 25, maximum: 40, temporary: 0 },
        deathSaves: { successes: 0, failures: 0 },
        resources: [],
        conditions: [],
        items: [],
        extensions: {},
      }),
    );
  });

  it('preserves structured custom entries and namespaced extensions', () => {
    const state = parseCharacterState({
      schemaVersion: 2,
      hitPoints: { current: 9, maximum: 12, temporary: 3 },
      resources: [
        {
          id: 'homebrew-focus',
          name: '专注点',
          current: 1,
          maximum: 2,
          restoreOn: 'shortRest',
          custom: true,
        },
      ],
      conditions: [
        {
          id: 'poison-1',
          type: 'poisoned',
          source: { type: 'monster', id: 'spider-1' },
          duration: { unit: 'round', value: 3 },
          remaining: 2,
          removable: true,
        },
      ],
      items: [
        {
          id: 'potion-1',
          templateRef: 'item:healing-potion',
          name: '治疗药水',
          quantity: 2,
          equipped: false,
          attuned: false,
          instanceData: { quality: 'standard' },
        },
      ],
      extensions: {
        'homebrew.dragonBloodline': { element: 'fire' },
        invalid: { ignored: true },
      },
    });

    expect(serializeCharacterState(state)).toEqual(
      expect.objectContaining({
        resources: [expect.objectContaining({ id: 'homebrew-focus' })],
        conditions: [expect.objectContaining({ remaining: 2 })],
        items: [expect.objectContaining({ quantity: 2 })],
        extensions: {
          'homebrew.dragonBloodline': { element: 'fire' },
        },
      }),
    );
  });

  it('normalizes unsafe numeric values', () => {
    const state = parseCharacterState({
      hitPoints: { current: 99, maximum: 20, temporary: -4 },
      deathSaves: { successes: 8, failures: -1 },
    });

    expect(state.hitPoints).toEqual({
      current: 20,
      maximum: 20,
      temporary: 0,
    });
    expect(state.deathSaves).toEqual({ successes: 3, failures: 0 });
  });
});
