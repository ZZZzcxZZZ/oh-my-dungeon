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
  bool _loading = false;
  String? _error;

  List<CharacterSheet> get characters => _characters;
  List<CharacterCampaignBinding> get campaignCharacters => _campaignCharacters;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _characters = [];
      _campaignCharacters = [];
      _error = null;
      notifyListeners();
    }
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
      );
      _characters = [..._characters, character];
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
