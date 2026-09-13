import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'local_backup_models.dart';
import 'local_data_archive_service.dart';

/// Drift-backed implementation of [LocalDataArchiveService].
///
/// The archive is an `.ohmydungeon-backup` ZIP containing:
/// - `manifest.json` — format version, counts, total size, and SHA-256
/// - `database.json` — personal data (no tokens, no campaign cache)
/// - `assets/<packageId>/<relativePath>` — binary content assets
///
/// Tables excluded by design:
/// - [SyncOutbox], [SyncCursors], [MigrationMarkers] — transient sync state
/// - [CampaignCharactersCache], [CampaignCharacterBacklinks], [CampaignContentCache],
///   [CampaignSyncCursors], [CharacterSyncConflicts] — remote cache, re-fetched
class DriftLocalDataArchiveService implements LocalDataArchiveService {
  DriftLocalDataArchiveService(this._database, {this.clientVersion = '0.1.0'});

  final AppDatabase _database;
  final String clientVersion;

  @override
  Future<Uint8List> exportArchive() async {
    final db = _database;

    final serverProfiles = await db.select(db.serverProfiles).get();
    final packages = await db.select(db.localContentPackages).get();
    final entries = await db.select(db.localContentEntries).get();
    final assets = await db.select(db.localContentAssets).get();
    final links = await db.select(db.contentLinks).get();
    final favorites = await db.select(db.contentFavorites).get();
    final notes = await db.select(db.contentNotes).get();
    final readHistory = await db.select(db.contentReadHistory).get();
    final characters = await db.select(db.characters).get();
    final characterRefs = await db.select(db.characterContentRefs).get();

    final databaseJson = <String, Object?>{
      'serverProfiles': serverProfiles.map((r) => r.toJson()).toList(),
      'localContentPackages': packages.map((r) => r.toJson()).toList(),
      'localContentEntries': entries.map((r) => r.toJson()).toList(),
      'localContentAssets': assets.map((r) => r.toJson()).toList(),
      'contentLinks': links.map((r) => r.toJson()).toList(),
      'contentFavorites': favorites.map((r) => r.toJson()).toList(),
      'contentNotes': notes.map((r) => r.toJson()).toList(),
      'contentReadHistory': readHistory.map((r) => r.toJson()).toList(),
      'characters': characters.map((r) => r.toJson()).toList(),
      'characterContentRefs': characterRefs.map((r) => r.toJson()).toList(),
    };

    final databaseBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(databaseJson)),
    );
    final sha256Hash = sha256.convert(databaseBytes).toString();

    final archive = Archive();
    archive.addFile(ArchiveFile.bytes('database.json', databaseBytes));

    for (final asset in assets) {
      final path = 'assets/${asset.packageId}/${asset.relativePath}';
      archive.addFile(ArchiveFile.bytes(path, asset.bytes));
    }

    final totalSize = archive.files.fold<int>(0, (sum, f) => sum + f.size);

    final manifest = LocalBackupManifest(
      formatVersion: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      clientVersion: clientVersion,
      serverProfileCount: serverProfiles.length,
      packageCount: packages.length,
      entryCount: entries.length,
      assetCount: assets.length,
      characterCount: characters.length,
      totalSize: totalSize,
      sha256: sha256Hash,
    );
    final manifestBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest.toJson())),
    );
    archive.addFile(ArchiveFile.bytes('manifest.json', manifestBytes));

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  @override
  Future<ArchivePreview> previewArchive(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifestFile = archive.findFile('manifest.json');
      final databaseFile = archive.findFile('database.json');

      if (manifestFile == null || databaseFile == null) {
        return ArchivePreview(
          valid: false,
          manifest: null,
          bytes: bytes,
          error: 'Missing manifest.json or database.json',
        );
      }

      final manifestJson =
          jsonDecode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, Object?>;
      final manifest = LocalBackupManifest.fromJson(manifestJson);

      final databaseBytes = utf8.encode(
        utf8.decode(databaseFile.content as List<int>),
      );
      final actualHash = sha256.convert(databaseBytes).toString();

      if (actualHash != manifest.sha256) {
        return ArchivePreview(
          valid: false,
          manifest: manifest,
          bytes: bytes,
          error:
              'SHA-256 mismatch: expected ${manifest.sha256}, got $actualHash',
        );
      }

      return ArchivePreview(valid: true, manifest: manifest, bytes: bytes);
    } catch (e) {
      return ArchivePreview(
        valid: false,
        manifest: null,
        bytes: bytes,
        error: 'Invalid archive: $e',
      );
    }
  }

  @override
  Future<void> restoreArchive(ArchivePreview preview) async {
    if (!preview.valid || preview.manifest == null) {
      throw StateError(
        'Cannot restore an invalid archive: ${preview.error ?? 'unknown error'}',
      );
    }

    final archive = ZipDecoder().decodeBytes(preview.bytes);
    final databaseFile = archive.findFile('database.json')!;
    final databaseJson =
        jsonDecode(utf8.decode(databaseFile.content as List<int>))
            as Map<String, Object?>;

    final db = _database;
    await db.transaction(() async {
      // Clear personal data tables before restoring.
      await db.delete(db.serverProfiles).go();
      await db.delete(db.localContentPackages).go();
      await db.delete(db.localContentEntries).go();
      await db.delete(db.localContentAssets).go();
      await db.delete(db.contentLinks).go();
      await db.delete(db.contentFavorites).go();
      await db.delete(db.contentNotes).go();
      await db.delete(db.contentReadHistory).go();
      await db.delete(db.characterContentRefs).go();
      await db.delete(db.characters).go();

      // Restore ServerProfiles.
      for (final rowJson
          in (databaseJson['serverProfiles'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.serverProfiles)
            .insert(ServerProfileRow.fromJson(rowJson).toCompanion(true));
      }
      // Restore LocalContentPackages.
      for (final rawRow in databaseJson['localContentPackages'] as List) {
        await db
            .into(db.localContentPackages)
            .insert(
              LocalContentPackageRow.fromJson(
                _withArchiveColumnDefaults('localContentPackages', rawRow),
              ).toCompanion(true),
            );
      }
      // Restore LocalContentEntries.
      for (final rawRow in databaseJson['localContentEntries'] as List) {
        await db
            .into(db.localContentEntries)
            .insert(
              LocalContentEntryRow.fromJson(
                _withArchiveColumnDefaults('localContentEntries', rawRow),
              ).toCompanion(true),
            );
      }
      // Restore LocalContentAssets (metadata only — bytes restored below).
      for (final rowJson
          in (databaseJson['localContentAssets'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.localContentAssets)
            .insert(LocalContentAssetRow.fromJson(rowJson).toCompanion(true));
      }
      // Restore ContentLinks.
      for (final rowJson
          in (databaseJson['contentLinks'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.contentLinks)
            .insert(ContentLinkRow.fromJson(rowJson).toCompanion(true));
      }
      // Restore ContentFavorites.
      for (final rowJson
          in (databaseJson['contentFavorites'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.contentFavorites)
            .insert(ContentFavoriteRow.fromJson(rowJson).toCompanion(true));
      }
      // Restore ContentNotes.
      for (final rowJson
          in (databaseJson['contentNotes'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.contentNotes)
            .insert(ContentNoteRow.fromJson(rowJson).toCompanion(true));
      }
      // Restore ContentReadHistory.
      for (final rowJson
          in (databaseJson['contentReadHistory'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.contentReadHistory)
            .insert(ContentReadHistoryRow.fromJson(rowJson).toCompanion(true));
      }
      // Restore Characters.
      for (final rawRow in databaseJson['characters'] as List) {
        await db
            .into(db.characters)
            .insert(
              CharacterRow.fromJson(
                _withArchiveColumnDefaults('characters', rawRow),
              ).toCompanion(true),
            );
      }
      // Restore CharacterContentRefs.
      for (final rowJson
          in (databaseJson['characterContentRefs'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.characterContentRefs)
            .insert(CharacterContentRefRow.fromJson(rowJson).toCompanion(true));
      }
    });

    // Restore binary asset bytes from the archive's assets/ entries.
    // This replaces any bytes already loaded from database.json metadata.
    for (final file in archive.files) {
      if (!file.name.startsWith('assets/')) continue;
      final parts = file.name.substring('assets/'.length).split('/');
      if (parts.length < 2) continue;
      final packageId = parts.first;
      final relativePath = parts.skip(1).join('/');
      final bytes = Uint8List.fromList(file.content as List<int>);
      await (db.update(db.localContentAssets)..where(
            (t) =>
                t.packageId.equals(packageId) &
                t.relativePath.equals(relativePath),
          ))
          .write(LocalContentAssetsCompanion(bytes: Value(bytes)));
    }
  }
}

/// 归档兼容：把"归档早于某列引入"时**缺失的非空列**补上建表默认值。
///
/// 生成的 `fromJson` 对非空列执行 `serializer.fromJson<T>(json[key])`（硬转），
/// 缺失键或显式 `null` 都会抛 `TypeError`，让整个 restore 事务回滚——升级后旧
/// 备份将无法恢复。
///
/// **唯一映射**（表名 → `{列名: 默认值}`）：新增兼容列只在这里加一行，不在
/// restore 的每个循环里各打一次补丁。已覆盖：
/// - `local_content_packages.priority`（v14 引入，默认 0 ⇒ tier 仍为 100，数值不变）；
/// - `local_content_entries.rulesJson`（v6 引入，默认 `{}`）；
/// - `local_content_entries.relationsJson`（v7 引入，默认 `[]`）；
/// - `characters.markdownDirty`（v11 引入，默认 false）。
///
/// **不把这些列改可空**：列可空会让 `packagePriorities()` / tier 计算 / 查询到处
/// 处理 null，而迁移已经保证库内该列非空；可空等于把这个不变量扩散到整个读取链。
const _archiveColumnDefaults = <String, Map<String, Object?>>{
  'localContentPackages': <String, Object?>{'priority': 0},
  'localContentEntries': <String, Object?>{
    'rulesJson': '{}',
    'relationsJson': '[]',
  },
  'characters': <String, Object?>{'markdownDirty': false},
};

/// 按表补缺失非空列的默认值（**唯一实现**）。
///
/// - 缺失键**或显式 `null`** 都补默认值（`{"priority": null}` 也来自旧归档的
///   字段裁剪，不能让它继续抛）；
/// - 非 Map 行**不降级成 `{}`**：那会掩盖归档损坏并把错误推迟到更难定位的地方，
///   这里直接抛出带表名的错误（restore 事务因此回滚，用户看到的是明确原因）。
Map<String, Object?> _withArchiveColumnDefaults(String table, Object? raw) {
  if (raw is! Map) {
    throw FormatException('归档表 $table 的行必须是对象，实际为 ${raw.runtimeType}');
  }
  final row = Map<String, Object?>.from(raw);
  final defaults = _archiveColumnDefaults[table];
  if (defaults == null) return row;
  for (final entry in defaults.entries) {
    if (!row.containsKey(entry.key) || row[entry.key] == null) {
      row[entry.key] = entry.value;
    }
  }
  return row;
}
