import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_document.dart';
import 'package:dnd_table_client/src/features/characters/data/character_api_client.dart';
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
      abilities: {
        'str': 8,
        'dex': 14,
        'con': 12,
        'int': 16,
        'wis': 10,
        'cha': 10,
      },
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

  test(
    'updates runtime state without dropping existing character data',
    () async {
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
    },
  );

  test(
    'updates character inventory and currency from sheet quick actions',
    () async {
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
    },
  );

  test(
    'offline HP operation persists locally through the repository',
    () async {
      final repository = MemoryCharacterRepository(initial: [_character]);
      final controller = CharacterController(repository: repository);
      await drainStream();

      final ok = await controller.adjustHitPoints(
        characterId: 'char-1',
        delta: -7,
      );

      expect(ok, isTrue);
      expect((await repository.getById('char-1'))?.currentHp, 17);
      expect(repository.localSaveCount, 1);
      controller.dispose();
    },
  );

  test('campaign HP operation replaces cache with server state', () async {
    final repository = MemoryCharacterRepository(initial: [_character]);
    final operations = _FakeCharacterOperationsClient(
      result: CharacterOperationResult(
        state: CharacterDocument.fromJson(const {
          'hitPoints': {'current': 11, 'maximum': 24, 'temporary': 2},
        }),
        revision: 8,
        event: const {'type': 'character.hp.adjusted'},
      ),
    );
    final controller = CharacterController(
      repository: repository,
      operationsClient: operations,
      apiBaseUrlProvider: () => 'http://localhost:3000/api',
      accessTokenProvider: () => 'token',
    );
    await drainStream();

    final ok = await controller.adjustHitPoints(
      characterId: 'char-1',
      campaignId: 'camp-1',
      delta: -13,
      expectedRevision: 7,
    );

    expect(ok, isTrue);
    expect(operations.lastCampaignId, 'camp-1');
    expect(operations.lastDelta, -13);
    expect(repository.remoteSaveCount, 1);
    expect(repository.localSaveCount, 0);
    final stored = await repository.getById('char-1');
    expect(stored?.currentHp, 11);
    expect(stored?.temporaryHp, 2);
    controller.dispose();
  });

  test(
    'offline condition, resource, and item operations stay structured',
    () async {
      final structured = _character.copyWith(
        data: const {
          'characterState': {
            'schemaVersion': 2,
            'resources': [
              {
                'id': 'second-wind',
                'name': '回气',
                'current': 1,
                'maximum': 1,
                'restoreOn': 'shortRest',
                'custom': false,
              },
            ],
          },
        },
      );
      final repository = MemoryCharacterRepository(initial: [structured]);
      final controller = CharacterController(repository: repository);
      await drainStream();

      expect(
        await controller.addCondition(
          characterId: 'char-1',
          condition: const {'id': 'poisoned', 'type': '中毒'},
        ),
        isTrue,
      );
      expect(
        await controller.consumeResource(
          characterId: 'char-1',
          resourceId: 'second-wind',
        ),
        isTrue,
      );
      expect(
        await controller.grantItem(
          characterId: 'char-1',
          item: const {'id': 'potion-1', 'name': '治疗药水', 'quantity': 2},
        ),
        isTrue,
      );

      final stored = await repository.getById('char-1');
      final state = CharacterDocument.fromJson(
        Map<String, Object?>.from(stored!.dataMap['characterState']! as Map),
      );
      expect(state.conditions.single.type, '中毒');
      expect(state.resources.single.current, 0);
      expect(state.items.single.quantity, 2);
      controller.dispose();
    },
  );

  test(
    'copyWith exposes avatarUrl so callers can update the character avatar',
    () {
      // Spec §头像来源: 本地角色头像离线保存在客户端；战役角色头像在本地角色
      // 绑定战役后自动上传。copyWith 必须暴露 avatarUrl 字段，否则上层只能
      // 通过 sheetOverride 绕路，导致发布到战役时丢失头像。
      final updated = _character.copyWith(avatarUrl: 'file:///avatars/1.png');
      expect(updated.avatarUrl, 'file:///avatars/1.png');
      // 其他字段保持不变。
      expect(updated.id, _character.id);
      expect(updated.name, _character.name);
      expect(updated.level, _character.level);

      // 不传 avatarUrl 时保留原值。
      final kept = _character.copyWith(level: 5);
      expect(kept.avatarUrl, _character.avatarUrl);
      expect(kept.level, 5);
    },
  );

  // ignore: deprecated_member_use_from_same_package
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

class _FakeCharacterOperationsClient implements CharacterOperationsClient {
  _FakeCharacterOperationsClient({required this.result});

  final CharacterOperationResult result;
  String? lastCampaignId;
  int? lastDelta;

  @override
  Future<CharacterOperationResult> adjustHitPoints({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    String? campaignId,
    int? expectedRevision,
    int? delta,
    int? current,
    int? temporary,
  }) async {
    lastCampaignId = campaignId;
    lastDelta = delta;
    return result;
  }

  @override
  Future<CharacterOperationResult> addCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required Map<String, Object?> condition,
    String? campaignId,
    int? expectedRevision,
  }) async => result;

  @override
  Future<CharacterOperationResult> consumeResource({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String resourceId,
    int amount = 1,
    String? campaignId,
    int? expectedRevision,
  }) async => result;

  @override
  Future<CharacterOperationResult> grantItem({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required Map<String, Object?> item,
    String? campaignId,
    int? expectedRevision,
  }) async => result;

  @override
  Future<CharacterOperationResult> removeCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String conditionId,
    String? campaignId,
    int? expectedRevision,
  }) async => result;

  @override
  Future<CharacterOperationResult> restoreResource({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String resourceId,
    int amount = 1,
    String? campaignId,
    int? expectedRevision,
  }) async => result;
}
