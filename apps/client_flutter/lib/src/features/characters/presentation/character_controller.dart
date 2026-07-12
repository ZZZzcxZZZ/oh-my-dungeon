import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/character_api_client.dart';
import '../domain/character.dart';

class CharacterController extends ChangeNotifier {
  CharacterController({
    required this.apiBaseUrl,
    required this.authController,
    required this.characterClient,
  }) {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final CharacterClient characterClient;

  List<CharacterSheet> _characters = [];
  List<CharacterCampaignBinding> _campaignCharacters = [];
  CharacterSheet? _lastCreatedCharacter;
  bool _loading = false;
  String? _error;

  List<CharacterSheet> get characters => _characters;
  List<CharacterCampaignBinding> get campaignCharacters => _campaignCharacters;
  CharacterSheet? get lastCreatedCharacter => _lastCreatedCharacter;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _characters = [];
      _campaignCharacters = [];
      _lastCreatedCharacter = null;
      _error = null;
      notifyListeners();
    }
  }

  CharacterSheet? takeLastCreatedCharacter() {
    final character = _lastCreatedCharacter;
    _lastCreatedCharacter = null;
    return character;
  }

  Future<void> loadCharacters() async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _characters = await characterClient.listCharacters(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
      );
    } on CharacterApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '加载角色失败';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> createCharacter({
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
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      final character = await characterClient.createCharacter(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        name: name,
        level: level,
        classSummary: classSummary,
        raceSummary: raceSummary,
        currentHp: currentHp,
        maxHp: maxHp,
        armorClass: armorClass,
        speed: speed,
        initiativeBonus: initiativeBonus,
        abilities: abilities,
        saves: saves,
        skills: skills,
        inventory: inventory,
        currency: currency,
        notes: notes,
        data: data,
      );
      _characters = [..._characters, character];
      _lastCreatedCharacter = character;
      notifyListeners();
      return true;
    } on CharacterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCharacter({
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
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      final character = await characterClient.updateCharacter(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        characterId: characterId,
        campaignId: campaignId,
        name: name,
        level: level,
        classSummary: classSummary,
        raceSummary: raceSummary,
        currentHp: currentHp,
        maxHp: maxHp,
        armorClass: armorClass,
        speed: speed,
        initiativeBonus: initiativeBonus,
        abilities: abilities,
        saves: saves,
        skills: skills,
        inventory: inventory,
        currency: currency,
        notes: notes,
        data: data,
      );
      _replaceCharacter(character);
      notifyListeners();
      return true;
    } on CharacterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> bindCharacterToCampaign({
    required String characterId,
    required String campaignId,
  }) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      await characterClient.bindCharacterToCampaign(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        characterId: characterId,
        campaignId: campaignId,
      );
      notifyListeners();
      return true;
    } on CharacterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateContentRefs({
    required String characterId,
    List<String> spells = const [],
    List<String> items = const [],
    List<String> features = const [],
  }) {
    return updateCharacter(
      characterId: characterId,
      data: {
        'contentRefs': {'spells': spells, 'items': items, 'features': features},
      },
    );
  }

  Future<bool> updateRuntimeState({
    required String characterId,
    int? temporaryHp,
    bool? inspiration,
    List<String>? conditions,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    Map<String, int>? spellSlotsUsed,
    Map<String, int>? classResourcesUsed,
  }) {
    final character = _characters
        .where((item) => item.id == characterId)
        .firstOrNull;
    final data = <String, Object?>{if (character != null) ...character.dataMap};
    final currentRuntime = character?.runtimeMap ?? const <String, Object?>{};
    final currentDeathSaves = _asMap(currentRuntime['deathSaves']);
    final deathSaves = <String, Object?>{...currentDeathSaves};
    if (deathSaveSuccesses != null) {
      deathSaves['successes'] = deathSaveSuccesses;
    }
    if (deathSaveFailures != null) {
      deathSaves['failures'] = deathSaveFailures;
    }
    final runtime = <String, Object?>{
      ...currentRuntime,
      'deathSaves': deathSaves,
    };
    if (temporaryHp != null) runtime['temporaryHp'] = temporaryHp;
    if (inspiration != null) runtime['inspiration'] = inspiration;
    if (conditions != null) runtime['conditions'] = conditions;
    if (spellSlotsUsed != null) runtime['spellSlotsUsed'] = spellSlotsUsed;
    if (classResourcesUsed != null) {
      runtime['classResourcesUsed'] = classResourcesUsed;
    }
    data['runtime'] = runtime;
    return updateCharacter(characterId: characterId, data: data);
  }

  Future<bool> updateInventoryAndCurrency({
    required String characterId,
    List<Map<String, Object>>? inventory,
    Map<String, int>? currency,
  }) {
    return updateCharacter(
      characterId: characterId,
      inventory: inventory,
      currency: currency,
    );
  }

  Future<bool> adjustCampaignCharacterHp({
    required String campaignId,
    required String characterId,
    int? delta,
    int? currentHp,
  }) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      final character = await characterClient.adjustCampaignCharacterHp(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        characterId: characterId,
        delta: delta,
        currentHp: currentHp,
      );
      _replaceCharacter(character);
      notifyListeners();
      return true;
    } on CharacterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCampaignCharacters(String campaignId) async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _campaignCharacters = await characterClient.listCampaignCharacters(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on CharacterApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '加载战役角色失败';
    }

    _loading = false;
    notifyListeners();
  }

  void _replaceCharacter(CharacterSheet character) {
    final index = _characters.indexWhere((item) => item.id == character.id);
    if (index == -1) {
      _characters = [..._characters, character];
      return;
    }
    _characters = [
      for (var i = 0; i < _characters.length; i++)
        if (i == index) character else _characters[i],
    ];
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return {};
}
