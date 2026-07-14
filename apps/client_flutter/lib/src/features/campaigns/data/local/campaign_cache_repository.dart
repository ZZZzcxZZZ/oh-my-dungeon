import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/campaign_actor.dart';
import '../../domain/campaign_change.dart';

/// 战役协作数据本地缓存接口。UI 只读本地，远端变更通过 [applyPage] 合并。
abstract interface class CampaignCacheRepository {
  Stream<List<CampaignActor>> watchActors(String campaignId);
  Future<CampaignActor?> getActor(String campaignId, String actorId);
  Stream<List<CampaignContentEntrySummary>> watchContentEntries(String campaignId);
  Future<CampaignContentEntrySummary?> getContentEntry(
    String campaignId,
    String entryId,
  );
  Future<String> cursorFor(String campaignId);
  Future<void> applyPage(String campaignId, CampaignChangePage page);
  Future<void> clearCampaign(String campaignId);
}

/// 基于 Drift 的实现。applyPage 在事务内原子写入，不触发 Outbox 入队。
class DriftCampaignCacheRepository implements CampaignCacheRepository {
  DriftCampaignCacheRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<CampaignActor>> watchActors(String campaignId) {
    final db = _database;
    return (db.select(db.campaignActorsCache)
          ..where((t) => t.campaignId.equals(campaignId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toActor).toList(growable: false));
  }

  @override
  Future<CampaignActor?> getActor(String campaignId, String actorId) async {
    final db = _database;
    final row = await (db.select(db.campaignActorsCache)
          ..where((t) => t.id.equals(actorId) & t.campaignId.equals(campaignId)))
        .getSingleOrNull();
    return row == null ? null : _toActor(row);
  }

  @override
  Stream<List<CampaignContentEntrySummary>> watchContentEntries(
    String campaignId,
  ) {
    final db = _database;
    return (db.select(db.campaignContentCache)
          ..where((t) => t.campaignId.equals(campaignId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toEntry).toList(growable: false));
  }

  @override
  Future<CampaignContentEntrySummary?> getContentEntry(
    String campaignId,
    String entryId,
  ) async {
    final db = _database;
    final row = await (db.select(db.campaignContentCache)
          ..where(
              (t) => t.id.equals(entryId) & t.campaignId.equals(campaignId)))
        .getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  @override
  Future<String> cursorFor(String campaignId) async {
    final db = _database;
    final row = await (db.select(db.campaignSyncCursors)
          ..where((t) => t.campaignId.equals(campaignId)))
        .getSingleOrNull();
    return row?.cursor ?? '0';
  }

  @override
  Future<void> applyPage(String campaignId, CampaignChangePage page) async {
    final db = _database;
    await db.transaction(() async {
      for (final change in page.items) {
        if (change.entityType == 'actor') {
          if (change.operation == 'upsert' && change.entity != null) {
            final actor = CampaignActor.fromJson(change.entity!);
            await _upsertActor(actor);
          } else if (change.operation == 'delete') {
            await (db.delete(db.campaignActorsCache)
                  ..where((t) => t.id.equals(change.entityId)))
                .go();
          }
        } else if (change.entityType == 'content') {
          if (change.operation == 'upsert' && change.entity != null) {
            final entry = CampaignContentEntrySummary.fromJson(change.entity!);
            await _upsertEntry(entry);
          } else if (change.operation == 'delete') {
            await (db.delete(db.campaignContentCache)
                  ..where((t) => t.id.equals(change.entityId)))
                .go();
          }
        }
      }
      await _saveCursor(campaignId, page.nextCursor);
    });
  }

  @override
  Future<void> clearCampaign(String campaignId) async {
    final db = _database;
    await db.transaction(() async {
      await (db.delete(db.campaignActorsCache)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();
      await (db.delete(db.campaignContentCache)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();
      await (db.delete(db.campaignSyncCursors)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();
    });
  }

  Future<void> _upsertActor(CampaignActor actor) async {
    final db = _database;
    await db.into(db.campaignActorsCache).insertOnConflictUpdate(
          CampaignActorsCacheCompanion.insert(
            id: actor.id,
            campaignId: actor.campaignId,
            ownerUserId: Value(actor.ownerUserId),
            sourceCharacterId: Value(actor.sourceCharacterId),
            actorType: actor.actorType,
            status: actor.status,
            sheetJson: jsonEncode(actor.sheet),
            revision: actor.revision,
            updatedBy: actor.updatedBy,
            createdAt: _parseDate(actor.createdAt),
            updatedAt: _parseDate(actor.updatedAt),
          ),
        );
  }

  Future<void> _upsertEntry(CampaignContentEntrySummary entry) async {
    final db = _database;
    await db.into(db.campaignContentCache).insertOnConflictUpdate(
          CampaignContentCacheCompanion.insert(
            id: entry.id,
            campaignId: entry.campaignId,
            type: entry.type,
            slug: entry.slug,
            name: entry.name,
            entryJson: Value(jsonEncode(entry.entry)),
            revision: entry.revision,
            createdBy: entry.createdBy,
            updatedBy: entry.updatedBy,
            createdAt: _parseDate(entry.createdAt),
            updatedAt: _parseDate(entry.updatedAt),
            deletedAt: Value(entry.deletedAt == null
                ? null
                : _parseDate(entry.deletedAt!)),
          ),
        );
  }

  Future<void> _saveCursor(String campaignId, String cursor) async {
    final db = _database;
    await db.into(db.campaignSyncCursors).insertOnConflictUpdate(
          CampaignSyncCursorsCompanion.insert(
            campaignId: campaignId,
            cursor: Value(cursor),
            updatedAt: DateTime.now(),
          ),
        );
  }

  CampaignActor _toActor(CampaignActorsCacheRow row) {
    return CampaignActor(
      id: row.id,
      campaignId: row.campaignId,
      ownerUserId: row.ownerUserId,
      sourceCharacterId: row.sourceCharacterId,
      actorType: row.actorType,
      status: row.status,
      sheet: _decodeJson(row.sheetJson),
      revision: row.revision,
      updatedBy: row.updatedBy,
      createdAt: row.createdAt.toIso8601String(),
      updatedAt: row.updatedAt.toIso8601String(),
    );
  }

  CampaignContentEntrySummary _toEntry(CampaignContentCacheRow row) {
    return CampaignContentEntrySummary(
      id: row.id,
      campaignId: row.campaignId,
      type: row.type,
      slug: row.slug,
      name: row.name,
      entry: _decodeJson(row.entryJson),
      revision: row.revision,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      createdAt: row.createdAt.toIso8601String(),
      updatedAt: row.updatedAt.toIso8601String(),
      deletedAt: row.deletedAt?.toIso8601String(),
    );
  }

  Map<String, Object?> _decodeJson(String raw) {
    if (raw.isEmpty) return const <String, Object?>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    return const <String, Object?>{};
  }

  DateTime _parseDate(String value) {
    if (value.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// No-op 实现作为无数据库可用时的回退。
class EmptyCampaignCacheRepository implements CampaignCacheRepository {
  @override
  Stream<List<CampaignActor>> watchActors(String campaignId) =>
      Stream.value(const []);
  @override
  Future<CampaignActor?> getActor(String campaignId, String actorId) async =>
      null;
  @override
  Stream<List<CampaignContentEntrySummary>> watchContentEntries(
          String campaignId) =>
      Stream.value(const []);
  @override
  Future<CampaignContentEntrySummary?> getContentEntry(
          String campaignId, String entryId) async =>
      null;
  @override
  Future<String> cursorFor(String campaignId) async => '0';
  @override
  Future<void> applyPage(String campaignId, CampaignChangePage page) async {}
  @override
  Future<void> clearCampaign(String campaignId) async {}
}
