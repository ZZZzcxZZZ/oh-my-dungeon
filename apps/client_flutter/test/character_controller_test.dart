import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/characters/data/character_api_client.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  Future<AuthController> buildLoggedInAuthController() async {
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      'localhost',
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: _FakeAuthClient(),
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();
    return controller;
  }

  test('updates a character and replaces it in the local list', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCharacterClient(characters: [_character]);
    final controller = CharacterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      characterClient: client,
    );
    await controller.loadCharacters();

    final ok = await controller.updateCharacter(
      characterId: 'char-1',
      level: 4,
      currentHp: 30,
      maxHp: 30,
    );

    expect(ok, isTrue);
    expect(controller.characters.single.level, 4);
    expect(controller.characters.single.currentHp, 30);
    expect(client.updateCalls.single.characterId, 'char-1');

    controller.dispose();
    authController.dispose();
  });

  test('binds a character to a campaign', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCharacterClient(characters: [_character]);
    final controller = CharacterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      characterClient: client,
    );

    final ok = await controller.bindCharacterToCampaign(
      characterId: 'char-1',
      campaignId: 'camp-1',
    );

    expect(ok, isTrue);
    expect(client.bindCalls.single, ('char-1', 'camp-1'));

    controller.dispose();
    authController.dispose();
  });

  test('adjusts campaign character hp and updates local list', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCharacterClient(characters: [_character]);
    final controller = CharacterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      characterClient: client,
    );
    await controller.loadCharacters();

    final ok = await controller.adjustCampaignCharacterHp(
      campaignId: 'camp-1',
      characterId: 'char-1',
      delta: -6,
    );

    expect(ok, isTrue);
    expect(controller.characters.single.currentHp, 18);
    expect(client.hpCalls.single, ('camp-1', 'char-1', -6));

    controller.dispose();
    authController.dispose();
  });

  test('loads campaign character bindings for dm campaign detail', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCharacterClient(characters: [_character]);
    final controller = CharacterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      characterClient: client,
    );

    await controller.loadCampaignCharacters('camp-1');

    expect(controller.campaignCharacters, hasLength(1));
    expect(controller.campaignCharacters.single.character?.name, 'Arannis');
    expect(client.listCampaignCalls, ['camp-1']);

    controller.dispose();
    authController.dispose();
  });

  test('updates lightweight content refs on a character', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCharacterClient(characters: [_character]);
    final controller = CharacterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      characterClient: client,
    );
    await controller.loadCharacters();

    final ok = await controller.updateContentRefs(
      characterId: 'char-1',
      spells: const ['spell-1'],
      items: const ['item-1'],
      features: const ['feature-1'],
    );

    expect(ok, isTrue);
    expect(client.updateCalls.single.data, {
      'contentRefs': {
        'spells': ['spell-1'],
        'items': ['item-1'],
        'features': ['feature-1'],
      },
    });

    controller.dispose();
    authController.dispose();
  });

  test('creates a character with expanded sheet fields', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCharacterClient(characters: const []);
    final controller = CharacterController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      characterClient: client,
    );

    final ok = await controller.createCharacter(
      name: 'Mira',
      level: 2,
      classSummary: '法师',
      raceSummary: '人类',
      currentHp: 12,
      maxHp: 12,
      armorClass: 12,
      speed: 30,
      abilities: const {
        'str': 8,
        'dex': 14,
        'con': 12,
        'int': 16,
        'wis': 10,
        'cha': 10,
      },
      saves: const {'int': true, 'wis': true},
      skills: const {'奥秘': true, '调查': true},
      inventory: const [
        {'name': '法术书', 'quantity': 1},
      ],
      currency: const {'gp': 15},
      notes: '学院出身。',
    );

    expect(ok, isTrue);
    expect(controller.characters.single.name, 'Mira');
    expect(controller.lastCreatedCharacter?.name, 'Mira');
    expect(controller.takeLastCreatedCharacter()?.name, 'Mira');
    expect(controller.lastCreatedCharacter, isNull);
    expect(client.createCalls.single.abilities, {
      'str': 8,
      'dex': 14,
      'con': 12,
      'int': 16,
      'wis': 10,
      'cha': 10,
    });
    expect(client.createCalls.single.notes, '学院出身。');

    controller.dispose();
    authController.dispose();
  });

  test(
    'updates expanded sheet fields without losing existing character state',
    () async {
      final authController = await buildLoggedInAuthController();
      final client = _FakeCharacterClient(characters: [_character]);
      final controller = CharacterController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        characterClient: client,
      );
      await controller.loadCharacters();

      final ok = await controller.updateCharacter(
        characterId: 'char-1',
        abilities: const {'dex': 16},
        saves: const {'dex': true},
        skills: const {'隐匿': true},
        inventory: const [
          {'name': '短剑', 'quantity': 2},
        ],
        currency: const {'gp': 7},
        notes: '擅长潜行。',
      );

      expect(ok, isTrue);
      expect(client.updateCalls.single.abilities, {'dex': 16});
      expect(client.updateCalls.single.skills, {'隐匿': true});
      expect(client.updateCalls.single.notes, '擅长潜行。');

      controller.dispose();
      authController.dispose();
    },
  );

  test(
    'updates runtime state without dropping existing character data',
    () async {
      final authController = await buildLoggedInAuthController();
      final client = _FakeCharacterClient(
        characters: [
          _character.copyWith(
            data: const {
              'contentRefs': {
                'spells': ['spell-1'],
              },
            },
          ),
        ],
      );
      final controller = CharacterController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        characterClient: client,
      );
      await controller.loadCharacters();

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
      expect(client.updateCalls.single.data, {
        'contentRefs': {
          'spells': ['spell-1'],
        },
        'runtime': {
          'temporaryHp': 6,
          'inspiration': true,
          'conditions': ['中毒', '倒地'],
          'deathSaves': {'successes': 1, 'failures': 2},
          'spellSlotsUsed': {'1': 2, '2': 0},
          'classResourcesUsed': {'second_wind': 1},
        },
      });

      controller.dispose();
      authController.dispose();
    },
  );

  test(
    'updates character inventory and currency from sheet quick actions',
    () async {
      final authController = await buildLoggedInAuthController();
      final client = _FakeCharacterClient(characters: [_character]);
      final controller = CharacterController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        characterClient: client,
      );
      await controller.loadCharacters();

      final ok = await controller.updateInventoryAndCurrency(
        characterId: 'char-1',
        inventory: const [
          {'name': '长弓', 'quantity': 2},
          {'name': '治疗药水', 'quantity': 1},
        ],
        currency: const {'gp': 11},
      );

      expect(ok, isTrue);
      expect(client.updateCalls.single.inventory, [
        {'name': '长弓', 'quantity': 2},
        {'name': '治疗药水', 'quantity': 1},
      ]);
      expect(client.updateCalls.single.currency, {'gp': 11});

      controller.dispose();
      authController.dispose();
    },
  );
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

class _FakeAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {}

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const AuthUser(
      id: 'user-1',
      username: 'ranger',
      email: 'ranger@example.com',
    );
  }

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }
}

class _FakeCharacterClient implements CharacterClient {
  _FakeCharacterClient({required List<CharacterSheet> characters})
    : _characters = [...characters];

  final List<CharacterSheet> _characters;
  final List<
    ({
      String characterId,
      int? level,
      int? currentHp,
      int? maxHp,
      Object? abilities,
      Object? saves,
      Object? skills,
      Object? inventory,
      Object? currency,
      String? notes,
      Object? data,
    })
  >
  updateCalls = [];
  final List<
    ({
      String name,
      Object? abilities,
      Object? saves,
      Object? skills,
      Object? inventory,
      Object? currency,
      String? notes,
    })
  >
  createCalls = [];
  final List<(String, String)> bindCalls = [];
  final List<(String, String, int?)> hpCalls = [];
  final List<String> listCampaignCalls = [];

  @override
  Future<List<CharacterSheet>> listCharacters({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return List.unmodifiable(_characters);
  }

  @override
  Future<CharacterSheet> updateCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    String? campaignId,
    String? name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
    Object? abilities,
    Object? saves,
    Object? skills,
    Object? inventory,
    Object? currency,
    String? notes,
    Object? data,
  }) async {
    updateCalls.add((
      characterId: characterId,
      level: level,
      currentHp: currentHp,
      maxHp: maxHp,
      abilities: abilities,
      saves: saves,
      skills: skills,
      inventory: inventory,
      currency: currency,
      notes: notes,
      data: data,
    ));
    final updated = _characters.single.copyWith(
      level: level,
      currentHp: currentHp,
      maxHp: maxHp,
    );
    _characters[0] = updated;
    return updated;
  }

  @override
  Future<CharacterCampaignBinding> bindCharacterToCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String campaignId,
  }) async {
    bindCalls.add((characterId, campaignId));
    return CharacterCampaignBinding(
      id: 'bind-1',
      campaignId: campaignId,
      characterId: characterId,
      userId: 'user-1',
      visibility: 'party',
      status: 'active',
      dmNotes: '',
      joinedAt: '2026-07-09T00:00:00.000Z',
      updatedAt: '2026-07-09T00:00:00.000Z',
    );
  }

  @override
  Future<CharacterSheet> adjustCampaignCharacterHp({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    int? delta,
    int? currentHp,
  }) async {
    hpCalls.add((campaignId, characterId, delta));
    final nextHp = currentHp ?? _characters.single.currentHp + (delta ?? 0);
    final updated = _characters.single.copyWith(currentHp: nextHp);
    _characters[0] = updated;
    return updated;
  }

  @override
  Future<CharacterSheet> createCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
    Object? abilities,
    Object? saves,
    Object? skills,
    Object? inventory,
    Object? currency,
    String? notes,
    Object? data,
  }) async {
    createCalls.add((
      name: name,
      abilities: abilities,
      saves: saves,
      skills: skills,
      inventory: inventory,
      currency: currency,
      notes: notes,
    ));
    final character = CharacterSheet(
      id: 'char-${_characters.length + 1}',
      ownerUserId: 'user-1',
      name: name,
      avatarUrl: null,
      system: 'dnd5e',
      level: level ?? 1,
      classSummary: classSummary ?? '',
      raceSummary: raceSummary ?? '',
      currentHp: currentHp ?? 0,
      maxHp: maxHp ?? 0,
      armorClass: armorClass ?? 10,
      speed: speed ?? 30,
      initiativeBonus: initiativeBonus ?? 0,
      abilities: abilities,
      saves: saves,
      skills: skills,
      inventory: inventory,
      currency: currency,
      notes: notes ?? '',
      data: data,
      createdAt: '2026-07-09T00:00:00.000Z',
      updatedAt: '2026-07-09T00:00:00.000Z',
    );
    _characters.add(character);
    return character;
  }

  @override
  Future<List<CharacterCampaignBinding>> listCampaignCharacters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    listCampaignCalls.add(campaignId);
    return [
      CharacterCampaignBinding(
        id: 'bind-1',
        campaignId: campaignId,
        characterId: 'char-1',
        userId: 'user-1',
        visibility: 'party',
        status: 'active',
        dmNotes: '',
        joinedAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z',
        character: _character,
      ),
    ];
  }
}
