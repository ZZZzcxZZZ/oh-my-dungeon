import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/character_api_client.dart';
import '../data/character_repository.dart';
import '../domain/character.dart';
import '../domain/character_document.dart';
import '../domain/character_edit_draft.dart';
import '../domain/dnd5e_rules.dart';

class CharacterController extends ChangeNotifier {
  CharacterController({
    required CharacterRepository repository,
    CharacterOperationsClient? operationsClient,
    String Function()? apiBaseUrlProvider,
    String Function()? accessTokenProvider,
  }) : _repository = repository,
       _operationsClient = operationsClient,
       _apiBaseUrlProvider = apiBaseUrlProvider,
       _accessTokenProvider = accessTokenProvider {
    loadLocalCharacters();
  }

  final CharacterRepository _repository;
  final CharacterOperationsClient? _operationsClient;
  final String Function()? _apiBaseUrlProvider;
  final String Function()? _accessTokenProvider;
  StreamSubscription<List<CharacterSheet>>? _subscription;
  int _requestSequence = 0;

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

  Future<List<CharacterMarkdownExternalChange>>
  detectExternalMarkdownChanges() {
    final repository = _repository;
    if (repository is! CharacterMarkdownChangeRepository) {
      return Future.value(const []);
    }
    return (repository as CharacterMarkdownChangeRepository)
        .detectExternalMarkdownChanges();
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

  Future<bool> deleteCharacter(String characterId) async {
    _error = null;
    try {
      await _repository.delete(characterId);
      if (_lastCreatedCharacter?.id == characterId) {
        _lastCreatedCharacter = null;
      }
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('deleteCharacter failed: $e\n$stack');
      _error = '删除角色失败：$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> adjustHitPoints({
    required String characterId,
    String? campaignId,
    int? expectedRevision,
    int? delta,
    int? current,
    int? temporary,
  }) async {
    final character = await _repository.getById(characterId);
    if (character == null) return false;
    if (delta == null && current == null && temporary == null) return true;

    final remote = _operationsClient;
    final token = _accessTokenProvider?.call() ?? '';
    if (campaignId != null && remote != null && token.isNotEmpty) {
      return _runRemoteOperation(
        character,
        () => remote.adjustHitPoints(
          apiBaseUrl: _apiBaseUrlProvider?.call() ?? '',
          accessToken: token,
          characterId: characterId,
          requestId: _nextRequestId('hp', characterId),
          campaignId: campaignId,
          expectedRevision: expectedRevision,
          delta: delta,
          current: current,
          temporary: temporary,
        ),
      );
    }

    final document = _documentFor(character);
    final hitPoints = document.hitPoints;
    var nextCurrent = hitPoints.current;
    var nextTemporary = (temporary ?? hitPoints.temporary).clamp(0, 1 << 31);
    if (current != null) {
      nextCurrent = current.clamp(0, hitPoints.maximum);
    } else if (delta != null) {
      // 2024：伤害先扣临时生命值，溢出才扣当前生命值；治疗不改临时生命值。
      final settled = Dnd5eRules.applyHitPointDelta(
        current: hitPoints.current,
        maximum: hitPoints.maximum,
        temporary: nextTemporary,
        delta: delta,
      );
      nextCurrent = settled.current;
      nextTemporary = settled.temporary;
    }
    final next = CharacterDocument(
      hitPoints: CharacterHitPoints(
        current: nextCurrent,
        maximum: hitPoints.maximum,
        temporary: nextTemporary.clamp(0, 1 << 31),
      ),
      deathSaves: document.deathSaves,
      resources: document.resources,
      conditions: document.conditions,
      items: document.items,
      extensions: document.extensions,
    );
    return updateCharacter(_applyDocument(character, next));
  }

  Future<bool> addCondition({
    required String characterId,
    required Map<String, Object?> condition,
    String? campaignId,
    int? expectedRevision,
  }) async {
    final character = await _repository.getById(characterId);
    final parsed = CharacterCondition.fromJson(condition);
    if (character == null || parsed == null) return false;
    final remote = _remoteFor(campaignId);
    if (remote != null) {
      return _runRemoteOperation(
        character,
        () => remote.client.addCondition(
          apiBaseUrl: remote.apiBaseUrl,
          accessToken: remote.accessToken,
          characterId: characterId,
          requestId: _nextRequestId('condition-add', characterId),
          campaignId: campaignId,
          expectedRevision: expectedRevision,
          condition: condition,
        ),
      );
    }
    final document = _documentFor(character);
    final conditions = [
      ...document.conditions.where((item) => item.id != parsed.id),
      parsed,
    ];
    return updateCharacter(
      _applyDocument(
        character,
        _copyDocument(document, conditions: conditions),
      ),
    );
  }

  Future<bool> removeCondition({
    required String characterId,
    required String conditionId,
    String? campaignId,
    int? expectedRevision,
  }) async {
    final character = await _repository.getById(characterId);
    if (character == null) return false;
    final remote = _remoteFor(campaignId);
    if (remote != null) {
      return _runRemoteOperation(
        character,
        () => remote.client.removeCondition(
          apiBaseUrl: remote.apiBaseUrl,
          accessToken: remote.accessToken,
          characterId: characterId,
          requestId: _nextRequestId('condition-remove', characterId),
          campaignId: campaignId,
          expectedRevision: expectedRevision,
          conditionId: conditionId,
        ),
      );
    }
    final document = _documentFor(character);
    return updateCharacter(
      _applyDocument(
        character,
        _copyDocument(
          document,
          conditions: document.conditions
              .where((item) => item.id != conditionId)
              .toList(),
        ),
      ),
    );
  }

  Future<bool> consumeResource({
    required String characterId,
    required String resourceId,
    int amount = 1,
    String? campaignId,
    int? expectedRevision,
  }) {
    return _changeResource(
      characterId: characterId,
      resourceId: resourceId,
      amount: amount,
      restore: false,
      campaignId: campaignId,
      expectedRevision: expectedRevision,
    );
  }

  Future<bool> restoreResource({
    required String characterId,
    required String resourceId,
    int amount = 1,
    String? campaignId,
    int? expectedRevision,
  }) {
    return _changeResource(
      characterId: characterId,
      resourceId: resourceId,
      amount: amount,
      restore: true,
      campaignId: campaignId,
      expectedRevision: expectedRevision,
    );
  }

  Future<bool> _changeResource({
    required String characterId,
    required String resourceId,
    required int amount,
    required bool restore,
    String? campaignId,
    int? expectedRevision,
  }) async {
    if (amount <= 0) return false;
    final character = await _repository.getById(characterId);
    if (character == null) return false;
    final remote = _remoteFor(campaignId);
    if (remote != null) {
      final action = restore
          ? remote.client.restoreResource
          : remote.client.consumeResource;
      return _runRemoteOperation(
        character,
        () => action(
          apiBaseUrl: remote.apiBaseUrl,
          accessToken: remote.accessToken,
          characterId: characterId,
          requestId: _nextRequestId(
            restore ? 'resource-restore' : 'resource-consume',
            characterId,
          ),
          campaignId: campaignId,
          expectedRevision: expectedRevision,
          resourceId: resourceId,
          amount: amount,
        ),
      );
    }
    final document = _documentFor(character);
    final resources = document.resources.map((resource) {
      if (resource.id != resourceId) return resource;
      final current = restore
          ? (resource.current + amount).clamp(0, resource.maximum)
          : (resource.current - amount).clamp(0, resource.maximum);
      return CharacterResource(
        id: resource.id,
        name: resource.name,
        current: current,
        maximum: resource.maximum,
        restoreOn: resource.restoreOn,
        sourceRef: resource.sourceRef,
        custom: resource.custom,
      );
    }).toList();
    return updateCharacter(
      _applyDocument(character, _copyDocument(document, resources: resources)),
    );
  }

  Future<bool> grantItem({
    required String characterId,
    required Map<String, Object?> item,
    String? campaignId,
    int? expectedRevision,
  }) async {
    final character = await _repository.getById(characterId);
    final parsed = CharacterItem.fromJson(item);
    if (character == null || parsed == null || parsed.quantity <= 0) {
      return false;
    }
    final remote = _remoteFor(campaignId);
    if (remote != null) {
      return _runRemoteOperation(
        character,
        () => remote.client.grantItem(
          apiBaseUrl: remote.apiBaseUrl,
          accessToken: remote.accessToken,
          characterId: characterId,
          requestId: _nextRequestId('item-grant', characterId),
          campaignId: campaignId,
          expectedRevision: expectedRevision,
          item: item,
        ),
      );
    }
    final document = _documentFor(character);
    final existing = document.items.where((value) => value.id == parsed.id);
    final items = [
      ...document.items.where((value) => value.id != parsed.id),
      if (existing.isEmpty)
        parsed
      else
        CharacterItem(
          id: parsed.id,
          name: parsed.name,
          templateRef: parsed.templateRef,
          quantity: existing.first.quantity + parsed.quantity,
          equipped: existing.first.equipped,
          attuned: existing.first.attuned,
          instanceData: {
            ...existing.first.instanceData,
            ...parsed.instanceData,
          },
        ),
    ];
    return updateCharacter(
      _applyDocument(character, _copyDocument(document, items: items)),
    );
  }

  _RemoteCharacterOperations? _remoteFor(String? campaignId) {
    final client = _operationsClient;
    final accessToken = _accessTokenProvider?.call() ?? '';
    if (campaignId == null || client == null || accessToken.isEmpty) {
      return null;
    }
    return _RemoteCharacterOperations(
      client: client,
      apiBaseUrl: _apiBaseUrlProvider?.call() ?? '',
      accessToken: accessToken,
    );
  }

  Future<bool> _runRemoteOperation(
    CharacterSheet character,
    Future<CharacterOperationResult> Function() action,
  ) async {
    _error = null;
    try {
      final result = await action();
      await _repository.saveRemote(
        _applyDocument(character, result.state),
        result.revision,
      );
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('character operation failed: $e\n$stack');
      _error = '更新角色状态失败：$e';
      notifyListeners();
      return false;
    }
  }

  String _nextRequestId(String action, String characterId) {
    _requestSequence += 1;
    return [
      'client',
      characterId,
      action,
      DateTime.now().toUtc().microsecondsSinceEpoch,
      _requestSequence,
    ].join(':');
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

CharacterDocument _documentFor(CharacterSheet character) {
  final canonical = _asMap(character.dataMap['characterState']);
  return CharacterDocument.fromJson({
    ...canonical,
    'hitPoints': {
      ..._asMap(canonical['hitPoints']),
      'current': character.currentHp,
      'maximum': character.maxHp,
      'temporary': character.temporaryHp,
    },
    'conditions': canonical['conditions'] ?? character.conditions,
    'inventory': canonical['items'] ?? _inventoryWithStableIds(character),
  });
}

CharacterSheet _applyDocument(
  CharacterSheet character,
  CharacterDocument document,
) {
  final data = <String, Object?>{
    ...character.dataMap,
    'characterState': document.toJson(),
    'runtime': {
      ...character.runtimeMap,
      'temporaryHp': document.hitPoints.temporary,
      'conditions': document.conditions.map((item) => item.type).toList(),
      'deathSaves': document.deathSaves.toJson(),
    },
  };
  return character.copyWith(
    currentHp: document.hitPoints.current,
    maxHp: document.hitPoints.maximum,
    inventory: document.items.map((item) => item.toJson()).toList(),
    data: data,
  );
}

List<Map<String, Object?>> _inventoryWithStableIds(CharacterSheet character) {
  return [
    for (var index = 0; index < character.inventoryList.length; index++)
      {
        ..._asMap(character.inventoryList[index]),
        'id':
            _asMap(character.inventoryList[index])['id'] ??
            'legacy-item-$index',
      },
  ];
}

CharacterDocument _copyDocument(
  CharacterDocument document, {
  List<CharacterResource>? resources,
  List<CharacterCondition>? conditions,
  List<CharacterItem>? items,
}) {
  return CharacterDocument(
    hitPoints: document.hitPoints,
    deathSaves: document.deathSaves,
    resources: resources ?? document.resources,
    conditions: conditions ?? document.conditions,
    items: items ?? document.items,
    extensions: document.extensions,
  );
}

class _RemoteCharacterOperations {
  const _RemoteCharacterOperations({
    required this.client,
    required this.apiBaseUrl,
    required this.accessToken,
  });

  final CharacterOperationsClient client;
  final String apiBaseUrl;
  final String accessToken;
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return {};
}
