import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../characters/data/character_repository.dart';
import '../../domain/campaign_actor.dart';

/// 把远端 Actor 变更回写到本地角色。运行时字段（HP、临时生命、状态）始终覆盖，
/// 构建字段（属性、豁免、技能等）仅在本地未偏离 lastPublished 时覆盖，否则记录冲突。
class CampaignActorBacklinkService {
  CampaignActorBacklinkService({
    required this.characterRepository,
    required this.database,
  });

  final CharacterRepository characterRepository;
  final AppDatabase database;

  Future<void> applyActorToCharacter(CampaignActor actor) async {
    if (actor.sourceCharacterId == null) return;
    final characterId = actor.sourceCharacterId!;
    final character = await characterRepository.getById(characterId);
    if (character == null) return; // 不得删除本地角色

    final sheet = actor.sheet;
    final backlink = await _loadBacklink(actor.id);
    final lastPublished = backlink?.lastPublishedLocalRevision ?? 0;
    final localRevision = await _readCharacterRevision(characterId);

    // 运行时字段：HP、最大 HP、AC、速度始终覆盖。
    var updated = character.copyWith(
      currentHp: _readInt(sheet, 'currentHp', character.currentHp),
      maxHp: _readInt(sheet, 'maxHp', character.maxHp),
      armorClass: _readInt(sheet, 'armorClass', character.armorClass),
      speed: _readInt(sheet, 'speed', character.speed),
    );

    // 运行时字段：临时生命、状态写入 data.runtime。
    updated = updated.copyWith(data: _mergeRuntime(updated.data, sheet));

    // 构建字段：仅当本地未偏离 lastPublished 时覆盖，否则记录冲突。
    final buildDiverged = lastPublished != 0 && localRevision != lastPublished;
    if (buildDiverged) {
      await _recordConflict(
        characterId: characterId,
        actorId: actor.id,
        localSheet: updated.toJson(),
        remoteSheet: sheet,
      );
    } else {
      updated = updated.copyWith(
        abilities: sheet['abilities'] ?? updated.abilities,
        saves: sheet['saves'] ?? updated.saves,
        skills: sheet['skills'] ?? updated.skills,
        inventory: sheet['inventory'] ?? updated.inventory,
        currency: sheet['currency'] ?? updated.currency,
      );
    }

    await characterRepository.save(updated);
    await _saveBacklink(
      actor.id,
      characterId,
      localRevision,
      actor.revision,
    );
  }

  Future<CampaignActorBacklinkRow?> _loadBacklink(String actorId) async {
    final db = database;
    return (db.select(db.campaignActorBacklinks)
          ..where((t) => t.campaignActorId.equals(actorId)))
        .getSingleOrNull();
  }

  Future<int> _readCharacterRevision(String characterId) async {
    final db = database;
    final row = await (db.select(db.characters)
          ..where((t) => t.id.equals(characterId)))
        .getSingleOrNull();
    return row?.revision ?? 1;
  }

  Future<void> _saveBacklink(
    String actorId,
    String characterId,
    int localRevision,
    int actorRevision,
  ) async {
    final db = database;
    await db.into(db.campaignActorBacklinks).insertOnConflictUpdate(
          CampaignActorBacklinksCompanion.insert(
            campaignActorId: actorId,
            sourceCharacterId: characterId,
            lastPublishedLocalRevision: Value(localRevision),
            lastAppliedActorRevision: Value(actorRevision),
          ),
        );
  }

  Future<void> _recordConflict({
    required String characterId,
    required String actorId,
    required Map<String, Object?> localSheet,
    required Map<String, Object?> remoteSheet,
  }) async {
    final db = database;
    final id =
        'conflict:$characterId:$actorId:${DateTime.now().microsecondsSinceEpoch}';
    await db.into(db.characterSyncConflicts).insert(
          CharacterSyncConflictsCompanion.insert(
            id: id,
            characterId: characterId,
            campaignActorId: actorId,
            fieldPath: 'build',
            localValueJson: Value(jsonEncode(localSheet)),
            remoteValueJson: Value(jsonEncode(remoteSheet)),
            createdAt: DateTime.now(),
          ),
        );
  }

  Object? _mergeRuntime(Object? data, Map<String, Object?> sheet) {
    final dataMap = data is Map
        ? Map<String, Object?>.from(data)
        : <String, Object?>{};
    final runtime = dataMap['runtime'] is Map
        ? Map<String, Object?>.from(dataMap['runtime'] as Map)
        : <String, Object?>{};
    if (sheet['temporaryHp'] is num) {
      runtime['temporaryHp'] = (sheet['temporaryHp'] as num).toInt();
    }
    if (sheet['conditions'] is List) {
      runtime['conditions'] = List<Object?>.from(sheet['conditions'] as List);
    }
    if (sheet['deathSaves'] is Map) {
      runtime['deathSaves'] = Map<String, Object?>.from(
        sheet['deathSaves'] as Map,
      );
    }
    if (sheet['spellSlotsUsed'] is Map) {
      runtime['spellSlotsUsed'] = Map<String, Object?>.from(
        sheet['spellSlotsUsed'] as Map,
      );
    }
    if (sheet['classResourcesUsed'] is Map) {
      runtime['classResourcesUsed'] = Map<String, Object?>.from(
        sheet['classResourcesUsed'] as Map,
      );
    }
    dataMap['runtime'] = runtime;
    return dataMap;
  }

  int _readInt(Map<String, Object?> sheet, String key, int fallback) {
    final value = sheet[key];
    if (value is num) return value.toInt();
    return fallback;
  }
}
