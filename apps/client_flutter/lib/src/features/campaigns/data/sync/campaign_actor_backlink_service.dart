import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../characters/data/character_repository.dart';
import '../../../characters/data/local/character_sync_conflict_repository.dart';
import '../../../characters/domain/character.dart';
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

  Future<void> applyActorToCharacter(CampaignActor actor) {
    return _applyActorToCharacter(actor, acceptRemoteBuild: false);
  }

  /// Applies the actor produced by a successful local publish and establishes
  /// it as the new sync baseline. This must not conflict with the edit that
  /// initiated the publish.
  Future<void> applyPublishedActorToCharacter(CampaignActor actor) {
    return _applyActorToCharacter(actor, acceptRemoteBuild: true);
  }

  Future<void> _applyActorToCharacter(
    CampaignActor actor, {
    required bool acceptRemoteBuild,
  }) async {
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
    final buildDiverged =
        !acceptRemoteBuild &&
        lastPublished != 0 &&
        localRevision != lastPublished;
    if (buildDiverged) {
      await _recordConflict(
        characterId: characterId,
        actorId: actor.id,
        localSheet: updated.toJson(),
        remoteSheet: {...sheet, 'revision': actor.revision},
      );
    } else {
      updated = _mergeRemoteBuild(updated, sheet);
    }

    await characterRepository.save(updated);
    final appliedLocalRevision = await _readCharacterRevision(characterId);
    await _saveBacklink(
      actor.id,
      characterId,
      buildDiverged ? lastPublished : appliedLocalRevision,
      actor.revision,
    );
  }

  /// Resolves a recorded conflict from the snapshot captured when it occurred.
  /// Pulling the campaign cursor again is insufficient because that change may
  /// already have been consumed.
  Future<bool> resolveConflictWithRemote(CharacterSyncConflict conflict) async {
    try {
      final character = await characterRepository.getById(conflict.characterId);
      if (character == null) return false;
      final decoded = jsonDecode(conflict.remoteValueJson);
      if (decoded is! Map) return false;
      final remote = Map<String, Object?>.from(decoded);
      final merged = <String, Object?>{
        ...character.toJson(),
        ...remote,
        'id': character.id,
        'ownerUserId': character.ownerUserId,
      };
      final updated = CharacterSheet.fromJson(merged);
      await characterRepository.save(updated);
      final localRevision = await _readCharacterRevision(character.id);
      final actorRevision = remote['revision'] is num
          ? (remote['revision'] as num).toInt()
          : (await _loadBacklink(
                  conflict.campaignActorId,
                ))?.lastAppliedActorRevision ??
                0;
      await _saveBacklink(
        conflict.campaignActorId,
        character.id,
        localRevision,
        actorRevision,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CampaignActorBacklinkRow?> _loadBacklink(String actorId) async {
    final db = database;
    return (db.select(
      db.campaignActorBacklinks,
    )..where((t) => t.campaignActorId.equals(actorId))).getSingleOrNull();
  }

  Future<int> _readCharacterRevision(String characterId) async {
    final db = database;
    final row = await (db.select(
      db.characters,
    )..where((t) => t.id.equals(characterId))).getSingleOrNull();
    return row?.revision ?? 1;
  }

  Future<void> _saveBacklink(
    String actorId,
    String characterId,
    int localRevision,
    int actorRevision,
  ) async {
    final db = database;
    await db
        .into(db.campaignActorBacklinks)
        .insertOnConflictUpdate(
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
    await db
        .into(db.characterSyncConflicts)
        .insert(
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

  CharacterSheet _mergeRemoteBuild(
    CharacterSheet runtimeUpdated,
    Map<String, Object?> sheet,
  ) {
    final merged = <String, Object?>{
      ...runtimeUpdated.toJson(),
      ...sheet,
      'id': runtimeUpdated.id,
      'ownerUserId': runtimeUpdated.ownerUserId,
    };
    final remote = CharacterSheet.fromJson(merged);
    return remote.copyWith(
      currentHp: runtimeUpdated.currentHp,
      maxHp: runtimeUpdated.maxHp,
      armorClass: runtimeUpdated.armorClass,
      speed: runtimeUpdated.speed,
      data: _mergeRuntime(remote.data, sheet),
    );
  }

  int _readInt(Map<String, Object?> sheet, String key, int fallback) {
    final value = sheet[key];
    if (value is num) return value.toInt();
    return fallback;
  }
}
