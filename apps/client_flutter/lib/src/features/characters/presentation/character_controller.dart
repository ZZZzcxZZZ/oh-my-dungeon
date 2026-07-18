import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/character_repository.dart';
import '../domain/character.dart';
import '../domain/character_edit_draft.dart';

class CharacterController extends ChangeNotifier {
  CharacterController({required CharacterRepository repository})
    : _repository = repository {
    loadLocalCharacters();
  }

  final CharacterRepository _repository;
  StreamSubscription<List<CharacterSheet>>? _subscription;

  List<CharacterSheet> _characters = [];

  CharacterSheet? _lastCreatedCharacter;
  bool _loading = false;
  String? _error;

  List<CharacterSheet> get characters => _characters;

  CharacterSheet? get lastCreatedCharacter => _lastCreatedCharacter;
  bool get isLoading => _loading;
  String? get error => _error;

  CharacterSheet? takeLastCreatedCharacter() {
    final character = _lastCreatedCharacter;
    _lastCreatedCharacter = null;
    return character;
  }

  void loadLocalCharacters() {
    _loading = true;
    _error = null;
    notifyListeners();
    _subscription ??= _repository.watchOwnedCharacters().listen(
      (characters) {
        _characters = characters;
        _loading = false;
        notifyListeners();
      },
      onError: (Object _) {
        _error = '加载角色失败';
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> createCharacter(CharacterEditDraft draft) async {
    _error = null;
    try {
      final character = draft.toLocalCharacter();
      await _repository.save(character);
      _lastCreatedCharacter = character;
      notifyListeners();
      return true;
    } catch (e, stack) {
      // Spec §错误反馈: 真实异常打到 console 方便定位 (Drift 事务失败、
      // rules engine 解析失败、约束冲突等), 同时给用户可读的错误信息。
      debugPrint('createCharacter failed: $e\n$stack');
      _error = '创建角色失败：$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCharacter(CharacterSheet character) async {
    _error = null;
    try {
      await _repository.save(character);
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('updateCharacter failed: $e\n$stack');
      _error = '保存角色失败：$e';
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
    final character = _characters
        .where((item) => item.id == characterId)
        .firstOrNull;
    if (character == null) return Future.value(false);
    return updateCharacter(
      character.copyWith(
        data: {
          ...character.dataMap,
          'contentRefs': {
            'spells': spells,
            'items': items,
            'features': features,
          },
        },
      ),
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
    if (character == null) return Future.value(false);
    final data = <String, Object?>{...character.dataMap};
    final currentRuntime = <String, Object?>{...character.runtimeMap};
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
    return updateCharacter(character.copyWith(data: data));
  }

  Future<bool> updateInventoryAndCurrency({
    required String characterId,
    List<Map<String, Object>>? inventory,
    Map<String, int>? currency,
  }) {
    final character = _characters
        .where((item) => item.id == characterId)
        .firstOrNull;
    if (character == null) return Future.value(false);
    return updateCharacter(
      character.copyWith(inventory: inventory, currency: currency),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
