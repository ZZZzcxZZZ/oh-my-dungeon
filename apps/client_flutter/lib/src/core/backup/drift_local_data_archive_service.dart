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
      for (final rowJson
          in (databaseJson['localContentPackages'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.localContentPackages)
            .insert(LocalContentPackageRow.fromJson(rowJson).toCompanion(true));
      }
      // Restore LocalContentEntries.
      for (final rowJson
          in (databaseJson['localContentEntries'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.localContentEntries)
            .insert(LocalContentEntryRow.fromJson(rowJson).toCompanion(true));
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
      for (final rowJson
          in (databaseJson['characters'] as List)
              .cast<Map<String, Object?>>()) {
        await db
            .into(db.characters)
            .insert(CharacterRow.fromJson(rowJson).toCompanion(true));
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
