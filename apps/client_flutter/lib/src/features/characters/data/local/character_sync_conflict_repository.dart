import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

/// 角色 vs 战役 Actor 双向同步冲突的领域视图。
///
/// `localValueJson` / `remoteValueJson` 是 sheet 或子字段的 JSON 字符串；
/// UI 负责解码并对比展示。`resolvedAt` 为 null 表示未解决。
class CharacterSyncConflict {
  const CharacterSyncConflict({
    required this.id,
    required this.characterId,
    required this.campaignActorId,
    required this.fieldPath,
    required this.localValueJson,
    required this.remoteValueJson,
    required this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String characterId;
  final String campaignActorId;
  final String fieldPath;
  final String localValueJson;
  final String remoteValueJson;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool get isResolved => resolvedAt != null;
}

/// 角色 vs Actor 冲突读取/解决接口。
abstract interface class CharacterSyncConflictRepository {
  /// 监听某角色的未解决冲突。已解决的冲突不会出现在列表中。
  Stream<List<CharacterSyncConflict>> watchUnresolved(String characterId);

  /// 监听所有未解决冲突（用于全局 banner 计数）。
  Stream<List<CharacterSyncConflict>> watchAllUnresolved();

  /// 标记冲突已解决。
  Future<void> markResolved(String conflictId);

  /// 删除某角色的所有冲突（如角色被删除时清理）。
  Future<void> clearForCharacter(String characterId);
}

/// Drift 实现：基于 `CharacterSyncConflicts` 表，`resolvedAt IS NULL` 为未解决。
class DriftCharacterSyncConflictRepository
    implements CharacterSyncConflictRepository {
  DriftCharacterSyncConflictRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<CharacterSyncConflict>> watchUnresolved(String characterId) {
    final db = _database;
    return (db.select(db.characterSyncConflicts)
          ..where(
            (t) => t.characterId.equals(characterId) & t.resolvedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Stream<List<CharacterSyncConflict>> watchAllUnresolved() {
    final db = _database;
    return (db.select(db.characterSyncConflicts)
          ..where((t) => t.resolvedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<void> markResolved(String conflictId) async {
    final db = _database;
    await (db.update(db.characterSyncConflicts)
          ..where((t) => t.id.equals(conflictId)))
        .write(
      CharacterSyncConflictsCompanion(resolvedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> clearForCharacter(String characterId) async {
    final db = _database;
    await (db.delete(db.characterSyncConflicts)
          ..where((t) => t.characterId.equals(characterId)))
        .go();
  }

  CharacterSyncConflict _toDomain(CharacterSyncConflictRow row) {
    return CharacterSyncConflict(
      id: row.id,
      characterId: row.characterId,
      campaignActorId: row.campaignActorId,
      fieldPath: row.fieldPath,
      localValueJson: row.localValueJson,
      remoteValueJson: row.remoteValueJson,
      createdAt: row.createdAt,
      resolvedAt: row.resolvedAt,
    );
  }
}
