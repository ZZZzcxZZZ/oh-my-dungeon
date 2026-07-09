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
    ({String characterId, int? level, int? currentHp, int? maxHp, Object? data})
  >
  updateCalls = [];
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
    Object? data,
  }) async {
    updateCalls.add((
      characterId: characterId,
      level: level,
      currentHp: currentHp,
      maxHp: maxHp,
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
    Object? data,
  }) {
    throw UnimplementedError();
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
