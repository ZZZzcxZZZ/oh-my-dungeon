import 'dart:async';

import 'package:dnd_table_client/src/features/campaigns/data/local/campaign_cache_repository.dart';
import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_character.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_character_audit.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_change.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_event.dart';

CampaignCharacter testCampaignCharacter({
  String id = 'character-1',
  String campaignId = 'campaign-1',
  String? ownerUserId,
  String? sourceCharacterId,
  String characterType = 'player',
  String status = 'active',
  String lifecycle = 'persistent',
  bool visibleToPlayers = true,
  Map<String, Object?>? sheet,
  int revision = 1,
}) => CampaignCharacter(
  id: id,
  campaignId: campaignId,
  ownerUserId: ownerUserId,
  sourceCharacterId: sourceCharacterId,
  characterType: characterType,
  status: status,
  lifecycle: lifecycle,
  visibleToPlayers: visibleToPlayers,
  sheet: sheet ?? {'name': 'Test Hero', 'currentHp': 10, 'maxHp': 20},
  revision: revision,
  updatedBy: 'user-1',
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
);

CampaignContentEntrySummary testContentEntry({
  String id = 'entry-1',
  String campaignId = 'campaign-1',
  String type = 'location',
  String slug = 'moon-harbor',
  String name = '月港',
  Map<String, Object?>? entry,
  int revision = 1,
}) => CampaignContentEntrySummary(
  id: id,
  campaignId: campaignId,
  type: type,
  slug: slug,
  name: name,
  entry: entry ?? {'body': <Map<String, Object?>>[]},
  revision: revision,
  createdBy: 'user-1',
  updatedBy: 'user-1',
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
  deletedAt: null,
);

class MemoryCampaignCacheRepository implements CampaignCacheRepository {
  MemoryCampaignCacheRepository({
    List<CampaignCharacter> characters = const [],
    List<CampaignContentEntrySummary> entries = const [],
    Map<String, String> cursors = const {},
  }) : _characters = {for (final a in characters) a.id: a},
       _entries = {for (final e in entries) e.id: e},
       _cursors = Map.of(cursors);

  final Map<String, CampaignCharacter> _characters;
  final Map<String, CampaignContentEntrySummary> _entries;
  final Map<String, String> _cursors;
  final StreamController<List<CampaignCharacter>> _controller =
      StreamController<List<CampaignCharacter>>.broadcast();
  final StreamController<List<CampaignContentEntrySummary>> _entryController =
      StreamController<List<CampaignContentEntrySummary>>.broadcast();

  List<CampaignCharacter> get characters =>
      _characters.values.toList(growable: false);
  List<CampaignContentEntrySummary> get entries =>
      _entries.values.toList(growable: false);

  void _emit(String campaignId) {
    _controller.add(
      _characters.values
          .where((character) => character.campaignId == campaignId)
          .toList(growable: false),
    );
    _entryController.add(
      _entries.values
          .where((entry) => entry.campaignId == campaignId)
          .toList(growable: false),
    );
  }

  @override
  Stream<List<CampaignCharacter>> watchCharacters(String campaignId) {
    final controller = StreamController<List<CampaignCharacter>>.broadcast();
    scheduleMicrotask(
      () => controller.add(
        _characters.values
            .where((character) => character.campaignId == campaignId)
            .toList(growable: false),
      ),
    );
    _controller.stream.listen(controller.add);
    return controller.stream;
  }

  @override
  Stream<List<CampaignContentEntrySummary>> watchContentEntries(
    String campaignId,
  ) {
    final controller =
        StreamController<List<CampaignContentEntrySummary>>.broadcast();
    scheduleMicrotask(
      () => controller.add(
        _entries.values
            .where((entry) => entry.campaignId == campaignId)
            .toList(growable: false),
      ),
    );
    _entryController.stream.listen(controller.add);
    return controller.stream;
  }

  @override
  Future<CampaignCharacter?> getCharacter(
    String campaignId,
    String characterId,
  ) async {
    final character = _characters[characterId];
    if (character == null || character.campaignId != campaignId) return null;
    return character;
  }

  @override
  Future<CampaignContentEntrySummary?> getContentEntry(
    String campaignId,
    String entryId,
  ) async {
    final entry = _entries[entryId];
    if (entry == null || entry.campaignId != campaignId) return null;
    return entry;
  }

  @override
  Future<String> cursorFor(String campaignId) async =>
      _cursors[campaignId] ?? '0';

  @override
  Future<void> applyPage(String campaignId, CampaignChangePage page) async {
    for (final change in page.items) {
      if (change.entityType == 'character') {
        if (change.operation == 'upsert' && change.entity != null) {
          final character = CampaignCharacter.fromJson(change.entity!);
          _characters[character.id] = character;
        } else if (change.operation == 'delete') {
          _characters.remove(change.entityId);
        }
      } else if (change.entityType == 'content') {
        if (change.operation == 'upsert' && change.entity != null) {
          final entry = CampaignContentEntrySummary.fromJson(change.entity!);
          _entries[entry.id] = entry;
        } else if (change.operation == 'delete') {
          _entries.remove(change.entityId);
        }
      }
    }
    _cursors[campaignId] = page.nextCursor;
    _emit(campaignId);
  }

  @override
  Future<void> clearCampaign(String campaignId) async {
    _characters.removeWhere(
      (_, character) => character.campaignId == campaignId,
    );
    _entries.removeWhere((_, entry) => entry.campaignId == campaignId);
    _cursors.remove(campaignId);
    _emit(campaignId);
  }
}

class MemoryCampaignSyncApiClient implements CampaignSyncApiClient {
  MemoryCampaignSyncApiClient({
    List<CampaignChangePage> changePages = const [],
    List<CampaignCharacterAudit> characterAudits = const [],
    this.listChangesException,
  }) : _changePages = List.of(changePages),
       _characterAudits = List.of(characterAudits);

  final List<CampaignChangePage> _changePages;
  final List<CampaignCharacterAudit> _characterAudits;
  int _changePageIndex = 0;
  final Object? listChangesException;

  /// 注入下一次 `updateCharacter` 调用要抛出的异常；用于 409 冲突场景测试。
  Object? nextUpdateCharacterException;

  /// 注入下一次 `publishCharacter` 调用要抛出的异常；用于 400/403 错误路径测试。
  Object? nextPublishCharacterException;

  /// 注入下一次 `createCharacter` 调用要抛出的异常；用于 400/403 错误路径测试。
  Object? nextCreateCharacterException;

  final List<Map<String, Object?>> publishCalls = [];
  final List<Map<String, Object?>> createCharacterCalls = [];
  final List<Map<String, Object?>> updateCharacterCalls = [];
  final List<Map<String, Object?>> archiveCalls = [];
  final List<Map<String, Object?>> createEntryCalls = [];
  final List<Map<String, Object?>> updateEntryCalls = [];
  final List<String> deleteEntryCalls = [];
  final List<String> listCharacterAuditCalls = [];

  /// Task 3.1 — CampaignEvent 原子事件调用记录, 便于测试断言.
  final List<Map<String, Object?>> changeCharacterHpCalls = [];
  final List<Map<String, Object?>> grantItemCalls = [];
  final List<Map<String, Object?>> addConditionCalls = [];

  /// 注入下一次 `changeCharacterHp` 调用要抛出的异常; 用于 409/403 错误路径测试.
  Object? nextChangeCharacterHpException;

  /// 注入下一次 `grantItem` 调用要抛出的异常; 用于 409/403 错误路径测试.
  Object? nextGrantItemException;

  Object? nextAddConditionException;

  @override
  Future<CampaignChangePage> listChanges({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String cursor,
    int? limit,
  }) async {
    if (listChangesException != null) throw listChangesException!;
    if (_changePageIndex < _changePages.length) {
      return _changePages[_changePageIndex++];
    }
    return const CampaignChangePage(items: [], nextCursor: '0', hasMore: false);
  }

  @override
  Future<CampaignCharacter> publishCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String sourceCharacterId,
    required String characterType,
    required int baseRevision,
    required Map<String, Object?> sheet,
  }) async {
    publishCalls.add({
      'apiBaseUrl': apiBaseUrl,
      'accessToken': accessToken,
      'campaignId': campaignId,
      'sourceCharacterId': sourceCharacterId,
      'characterType': characterType,
      'baseRevision': baseRevision,
      'sheet': sheet,
    });
    final exception = nextPublishCharacterException;
    if (exception != null) {
      nextPublishCharacterException = null;
      throw exception;
    }
    return testCampaignCharacter(
      campaignId: campaignId,
      sourceCharacterId: sourceCharacterId,
      characterType: characterType,
      sheet: sheet,
    );
  }

  @override
  Future<CampaignCharacter> createCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterType,
    String? ownerUserId,
    String lifecycle = 'persistent',
    required Map<String, Object?> sheet,
  }) async {
    createCharacterCalls.add({
      'campaignId': campaignId,
      'characterType': characterType,
      'ownerUserId': ownerUserId,
      'lifecycle': lifecycle,
      'sheet': sheet,
    });
    final exception = nextCreateCharacterException;
    if (exception != null) {
      nextCreateCharacterException = null;
      throw exception;
    }
    return testCampaignCharacter(
      campaignId: campaignId,
      characterType: characterType,
      ownerUserId: ownerUserId,
      sheet: sheet,
    );
  }

  @override
  Future<List<CampaignCharacter>> listCharacters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async => [testCampaignCharacter(campaignId: campaignId)];

  @override
  Future<CampaignCharacter> getCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
  }) async => testCampaignCharacter(id: characterId, campaignId: campaignId);

  @override
  Future<List<CampaignCharacterAudit>> listCharacterAudits({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
  }) async {
    listCharacterAuditCalls.add(characterId);
    return List.unmodifiable(_characterAudits);
  }

  @override
  Future<CampaignCharacter> updateCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
    required Map<String, Object?> sheet,
    String? lifecycle,
    bool? visibleToPlayers,
  }) async {
    updateCharacterCalls.add({
      'campaignId': campaignId,
      'characterId': characterId,
      'baseRevision': baseRevision,
      'sheet': sheet,
      'lifecycle': ?lifecycle,
      'visibleToPlayers': ?visibleToPlayers,
    });
    final exception = nextUpdateCharacterException;
    if (exception != null) {
      nextUpdateCharacterException = null;
      throw exception;
    }
    return testCampaignCharacter(
      id: characterId,
      campaignId: campaignId,
      sheet: sheet,
      lifecycle: lifecycle ?? 'persistent',
      visibleToPlayers: visibleToPlayers ?? true,
    );
  }

  @override
  Future<CampaignCharacter> archiveCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
  }) async {
    archiveCalls.add({
      'campaignId': campaignId,
      'characterId': characterId,
      'baseRevision': baseRevision,
    });
    return testCampaignCharacter(
      id: characterId,
      campaignId: campaignId,
      status: 'archived',
    );
  }

  @override
  Future<CampaignCharacter> restoreCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
  }) async {
    return testCampaignCharacter(
      id: characterId,
      campaignId: campaignId,
      status: 'active',
    );
  }

  @override
  Future<CampaignContentEntrySummary> createEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  }) async {
    createEntryCalls.add({
      'apiBaseUrl': apiBaseUrl,
      'accessToken': accessToken,
      'campaignId': campaignId,
      'type': type,
      'slug': slug,
      'name': name,
      'entry': entry,
    });
    return testContentEntry(
      campaignId: campaignId,
      type: type,
      slug: slug,
      name: name,
      entry: entry,
    );
  }

  @override
  Future<CampaignContentEntrySummary> updateEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
    required int baseRevision,
    required Map<String, Object?> entry,
  }) async {
    updateEntryCalls.add({
      'campaignId': campaignId,
      'entryId': entryId,
      'baseRevision': baseRevision,
      'entry': entry,
    });
    return testContentEntry(id: entryId, campaignId: campaignId, entry: entry);
  }

  @override
  Future<void> deleteEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  }) async {
    deleteEntryCalls.add(entryId);
  }

  @override
  Future<Map<String, Object?>> validateEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  }) async => {'valid': true, 'errors': <String>[]};

  @override
  Future<CampaignEventResult> changeCharacterHp({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required String requestId,
    required int delta,
    String? reason,
    int? baseRevision,
  }) async {
    changeCharacterHpCalls.add({
      'campaignId': campaignId,
      'characterId': characterId,
      'requestId': requestId,
      'delta': delta,
      'reason': reason,
      'baseRevision': baseRevision,
    });
    final exception = nextChangeCharacterHpException;
    if (exception != null) {
      nextChangeCharacterHpException = null;
      throw exception;
    }
    final baseRevisionValue = baseRevision ?? 1;
    return _buildHpEventResult(
      campaignId: campaignId,
      characterId: characterId,
      delta: delta,
      newRevision: baseRevisionValue + 1,
      reason: reason,
    );
  }

  @override
  Future<CampaignEventResult> grantItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required String requestId,
    required String itemId,
    required String name,
    int quantity = 1,
    int? baseRevision,
  }) async {
    grantItemCalls.add({
      'campaignId': campaignId,
      'characterId': characterId,
      'requestId': requestId,
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'baseRevision': baseRevision,
    });
    final exception = nextGrantItemException;
    if (exception != null) {
      nextGrantItemException = null;
      throw exception;
    }
    final baseRevisionValue = baseRevision ?? 1;
    return _buildItemGrantedEventResult(
      campaignId: campaignId,
      characterId: characterId,
      itemId: itemId,
      itemName: name,
      quantity: quantity,
      newRevision: baseRevisionValue + 1,
    );
  }

  @override
  Future<CampaignEventResult> addCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required String requestId,
    required String type,
    required String name,
    int? durationRounds,
    int? baseRevision,
  }) async {
    addConditionCalls.add({
      'campaignId': campaignId,
      'characterId': characterId,
      'requestId': requestId,
      'type': type,
      'name': name,
      'durationRounds': durationRounds,
      'baseRevision': baseRevision,
    });
    final exception = nextAddConditionException;
    if (exception != null) {
      nextAddConditionException = null;
      throw exception;
    }
    return CampaignEventResult(
      character: {
        'id': characterId,
        'campaignId': campaignId,
        'characterType': 'player',
        'status': 'active',
        'lifecycle': 'persistent',
        'sheet': <String, Object?>{
          'name': 'Arannis',
          'conditions': <Map<String, Object?>>[
            {
              'id': 'condition-1',
              'type': type,
              'name': name,
              'duration': durationRounds == null
                  ? null
                  : {
                      'unit': 'round',
                      'total': durationRounds,
                      'remaining': durationRounds,
                    },
            },
          ],
        },
        'revision': (baseRevision ?? 1) + 1,
      },
      event: CampaignEvent(
        id: 'event-${DateTime.now().microsecondsSinceEpoch}',
        campaignId: campaignId,
        senderId: 'dm-1',
        campaignCharacterId: characterId,
        displayName: 'DM',
        kind: 'system',
        content: 'Arannis 获得状态：$name',
        eventData: <String, Object?>{
          'eventType': CampaignEventTypes.characterConditionAdded,
          'characterId': characterId,
          'conditionType': type,
          'conditionName': name,
          'durationRounds': durationRounds,
        },
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// 构造 character.hp_changed 事件返回. 内存实现不做 clamp, 由服务端负责.
  CampaignEventResult _buildHpEventResult({
    required String campaignId,
    required String characterId,
    required int delta,
    required int newRevision,
    String? reason,
  }) {
    final previousHp = 20;
    final newHp = previousHp + delta;
    return CampaignEventResult(
      character: {
        'id': characterId,
        'campaignId': campaignId,
        'characterType': 'player',
        'status': 'active',
        'lifecycle': 'persistent',
        'sheet': <String, Object?>{
          'name': 'Arannis',
          'currentHp': newHp,
          'maxHp': 20,
        },
        'revision': newRevision,
      },
      event: CampaignEvent(
        id: 'event-${DateTime.now().microsecondsSinceEpoch}',
        campaignId: campaignId,
        senderId: 'dm-1',
        campaignCharacterId: characterId,
        displayName: 'DM',
        kind: 'system',
        content: 'Arannis $delta HP ($previousHp → $newHp)',
        eventData: <String, Object?>{
          'eventType': CampaignEventTypes.characterHpChanged,
          'characterId': characterId,
          'delta': delta,
          'previousHp': previousHp,
          'newHp': newHp,
          'reason': reason,
        },
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// 构造 character.item_granted 事件返回.
  CampaignEventResult _buildItemGrantedEventResult({
    required String campaignId,
    required String characterId,
    required String itemId,
    required String itemName,
    required int quantity,
    required int newRevision,
  }) {
    return CampaignEventResult(
      character: {
        'id': characterId,
        'campaignId': campaignId,
        'characterType': 'player',
        'status': 'active',
        'lifecycle': 'persistent',
        'sheet': <String, Object?>{
          'name': 'Arannis',
          'inventory': <Map<String, Object?>>[
            {'itemId': itemId, 'name': itemName, 'quantity': quantity},
          ],
        },
        'revision': newRevision,
      },
      event: CampaignEvent(
        id: 'event-${DateTime.now().microsecondsSinceEpoch}',
        campaignId: campaignId,
        senderId: 'dm-1',
        campaignCharacterId: characterId,
        displayName: 'DM',
        kind: 'system',
        content: '给 Arannis $itemName ×$quantity',
        eventData: <String, Object?>{
          'eventType': CampaignEventTypes.characterItemGranted,
          'characterId': characterId,
          'itemId': itemId,
          'itemName': itemName,
          'quantity': quantity,
        },
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }
}
