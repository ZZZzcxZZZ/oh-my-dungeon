import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

void main() {
  Future<void> drainStream() async {
    await Future.microtask(() {});
    await Future.microtask(() {});
  }

  test('creates a character from draft and stores it locally', () async {
    final repository = MemoryCharacterRepository();
    final controller = CharacterController(repository: repository);
    await drainStream();

    const draft = CharacterEditDraft(
      name: 'Mira',
      level: 2,
      classSummary: '法师',
      raceSummary: '人类',
      currentHp: 12,
      maxHp: 12,
      armorClass: 12,
      speed: 30,
      initiativeBonus: 0,
      abilities: {'str': 8, 'dex': 14, 'con': 12, 'int': 16, 'wis': 10, 'cha': 10},
      saves: {'int': true, 'wis': true},
      skills: {'奥秘': true, '调查': true},
      inventory: [],
      currency: {'gp': 15},
      notes: '学院出身。',
    );

    final ok = await controller.createCharacter(draft);
    await drainStream();

    expect(ok, isTrue);
    expect(controller.characters.single.name, 'Mira');
    expect(controller.lastCreatedCharacter?.name, 'Mira');
    expect(controller.takeLastCreatedCharacter()?.name, 'Mira');
    expect(controller.lastCreatedCharacter, isNull);

    controller.dispose();
  });

  test('updates a character and persists it locally', () async {
    final repository = MemoryCharacterRepository(initial: [_character]);
    final controller = CharacterController(repository: repository);
    await drainStream();

    final ok = await controller.updateCharacter(
      _character.copyWith(level: 4, currentHp: 30, maxHp: 30),
    );
    await drainStream();

    expect(ok, isTrue);
    expect(controller.characters.single.level, 4);
    expect(controller.characters.single.currentHp, 30);
    final stored = await repository.getById(_character.id);
    expect(stored?.level, 4);

    controller.dispose();
  });

  test('updates lightweight content refs on a character', () async {
    final repository = MemoryCharacterRepository(initial: [_character]);
    final controller = CharacterController(repository: repository);
    await drainStream();

    final ok = await controller.updateContentRefs(
      characterId: 'char-1',
      spells: const ['spell-1'],
      items: const ['item-1'],
      features: const ['feature-1'],
    );

    expect(ok, isTrue);
    final stored = await repository.getById('char-1');
    expect(stored?.dataMap['contentRefs'], {
      'spells': ['spell-1'],
      'items': ['item-1'],
      'features': ['feature-1'],
    });

    controller.dispose();
  });

  test('updates runtime state without dropping existing character data', () async {
    final character = _character.copyWith(
      data: const {
        'contentRefs': {
          'spells': ['spell-1'],
        },
      },
    );
    final repository = MemoryCharacterRepository(initial: [character]);
    final controller = CharacterController(repository: repository);
    await drainStream();

    final ok = await controller.updateRuntimeState(
      characterId: 'char-1',
      temporaryHp: 6,
      inspiration: true,
      conditions: const ['中毒', '倒地'],
      deathSaveSuccesses: 1,
      deathSaveFailures: 2,
      spellSlotsUsed: const {'1': 2, '2': 0},
      classResourcesUsed: const {'second_wind': 1},
    );

    expect(ok, isTrue);
    final stored = await repository.getById('char-1');
    expect(stored?.dataMap['contentRefs'], {
      'spells': ['spell-1'],
    });
    expect(stored?.dataMap['runtime'], {
      'temporaryHp': 6,
      'inspiration': true,
      'conditions': ['中毒', '倒地'],
      'deathSaves': {'successes': 1, 'failures': 2},
      'spellSlotsUsed': {'1': 2, '2': 0},
      'classResourcesUsed': {'second_wind': 1},
    });

    controller.dispose();
  });

  test('updates character inventory and currency from sheet quick actions', () async {
    final repository = MemoryCharacterRepository(initial: [_character]);
    final controller = CharacterController(repository: repository);
    await drainStream();

    final ok = await controller.updateInventoryAndCurrency(
      characterId: 'char-1',
      inventory: const [
        {'name': '长弓', 'quantity': 2},
        {'name': '治疗药水', 'quantity': 1},
      ],
      currency: const {'gp': 11},
    );

    expect(ok, isTrue);
    final stored = await repository.getById('char-1');
    expect(stored?.inventoryList, [
      {'name': '长弓', 'quantity': 2},
      {'name': '治疗药水', 'quantity': 1},
    ]);
    expect(stored?.currencyMap, {'gp': 11});

    controller.dispose();
  });

  // ignore: deprecated_member_use_from_same_package
  test('bindCharacterToCampaign stub returns false', () async {
    final repository = MemoryCharacterRepository();
    final controller = CharacterController(repository: repository);
    await drainStream();

    // ignore: deprecated_member_use_from_same_package
    final ok = await controller.bindCharacterToCampaign(
      characterId: 'char-1',
      campaignId: 'camp-1',
    );

    expect(ok, isFalse);

    controller.dispose();
  });

  test('adjustCampaignCharacterHp stub returns false', () async {
    final repository = MemoryCharacterRepository();
    final controller = CharacterController(repository: repository);
    await drainStream();

    // ignore: deprecated_member_use_from_same_package
    final ok = await controller.adjustCampaignCharacterHp(
      campaignId: 'camp-1',
      characterId: 'char-1',
      delta: -6,
    );

    expect(ok, isFalse);

    controller.dispose();
  });

  test('loadCampaignCharacters stub leaves campaignCharacters empty', () async {
    final repository = MemoryCharacterRepository();
    final controller = CharacterController(repository: repository);
    await drainStream();

    // ignore: deprecated_member_use_from_same_package
    await controller.loadCampaignCharacters('camp-1');

    // ignore: deprecated_member_use_from_same_package
    expect(controller.campaignCharacters, isEmpty);

    controller.dispose();
  });
}

const _character = CharacterSheet(
  id: 'char-1',
  ownerUserId: 'user-1',
  name: 'Arannis',
  avatarUrl: null,
  system: 'dnd5e',
  level: 3,
  classSummary: 'Ranger',
  raceSummary: 'Elf',
  currentHp: 24,
  maxHp: 24,
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
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);
