import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_package_manifest.dart';

class ContentQuery {
  const ContentQuery({
    this.text,
    this.type,
    this.favoritesOnly = false,
    this.packageId,
  });

  final String? text;
  final String? type;
  final bool favoritesOnly;
  final String? packageId;
}

class ContentLink {
  final String sourceId;
  final String targetId;
  final String linkText;
  const ContentLink({
    required this.sourceId,
    required this.targetId,
    required this.linkText,
  });
}

class ContentDeletionImpact {
  final int entryCount;
  final int favoriteCount;
  final int noteCount;
  const ContentDeletionImpact({
    required this.entryCount,
    required this.favoriteCount,
    required this.noteCount,
  });
}

abstract interface class ContentRepository {
  Stream<List<ContentPackageManifest>> watchPackages();
  Future<List<ContentEntry>> search(ContentQuery query);
  Future<ContentEntry?> getByKey(String entryKey);
  Future<List<ContentLink>> outgoingLinks(String entryKey);
  Future<List<ContentLink>> incomingLinks(String entryKey);
  Future<Uint8List?> readAsset(String packageId, String relativePath);
  Future<void> replacePackage({
    required ContentPackageManifest manifest,
    required List<ContentEntry> entries,
    required String contentHash,
    Map<String, Uint8List> assets = const {},
  });
  Future<void> setPackageEnabled(String packageId, bool enabled);
  Future<bool> isPackageEnabled(String packageId);
  Future<ContentDeletionImpact> deletionImpact(String packageId);
  Future<void> deletePackage(String packageId);
  Future<void> setFavorite(String entryKey, bool favorite);
  Future<bool> isFavorite(String entryKey);
  Future<void> saveNote(String entryKey, String markdown);
}

class DriftContentRepository implements ContentRepository {
  DriftContentRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<ContentPackageManifest>> watchPackages() {
    final db = _database;
    return (db.select(db.localContentPackages)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch()
        .map((rows) => rows.map(_mapPackage).toList());
  }

  @override
  Future<List<ContentEntry>> search(ContentQuery query) async {
    final db = _database;
    final entries = db.localContentEntries;
    final packages = db.localContentPackages;
    final favorites = db.contentFavorites;

    final stmt = db.select(entries).join([
      innerJoin(packages, packages.id.equalsExp(entries.packageId)),
    ]);

    Expression<bool> predicate = packages.enabled.equals(true);

    if (query.text != null && query.text!.isNotEmpty) {
      final pattern = '%${query.text}%';
      predicate = predicate &
          (entries.name.like(pattern) |
              entries.aliasesJson.like(pattern) |
              entries.summary.like(pattern) |
              entries.tagsJson.like(pattern) |
              entries.sourceLabel.like(pattern));
    }

    if (query.type != null) {
      predicate = predicate & entries.type.equals(query.type!);
    }

    if (query.packageId != null) {
      predicate = predicate & entries.packageId.equals(query.packageId!);
    }

    stmt.where(predicate);

    if (query.favoritesOnly) {
      stmt.join([
        innerJoin(
          favorites,
          favorites.entryKey.equalsExp(entries.entryKey),
        ),
      ]);
    }

    final rows = await stmt.get();
    return rows.map((row) => _mapEntry(row.readTable(entries))).toList();
  }

  @override
  Future<ContentEntry?> getByKey(String entryKey) async {
    final db = _database;
    final row = await (db.select(db.localContentEntries)
          ..where((t) => t.entryKey.equals(entryKey)))
        .getSingleOrNull();
    return row == null ? null : _mapEntry(row);
  }

  @override
  Future<List<ContentLink>> outgoingLinks(String entryKey) async {
    final db = _database;
    final rows = await (db.select(db.contentLinks)
          ..where((t) => t.sourceId.equals(entryKey))
          ..orderBy([(t) => OrderingTerm.asc(t.targetId)]))
        .get();
    return rows
        .map((row) => ContentLink(
              sourceId: row.sourceId,
              targetId: row.targetId,
              linkText: row.linkText,
            ))
        .toList();
  }

  @override
  Future<List<ContentLink>> incomingLinks(String entryKey) async {
    final db = _database;
    final rows = await (db.select(db.contentLinks)
          ..where((t) => t.targetId.equals(entryKey))
          ..orderBy([(t) => OrderingTerm.asc(t.sourceId)]))
        .get();
    return rows
        .map((row) => ContentLink(
              sourceId: row.sourceId,
              targetId: row.targetId,
              linkText: row.linkText,
            ))
        .toList();
  }

  @override
  Future<Uint8List?> readAsset(String packageId, String relativePath) async {
    final db = _database;
    final row = await (db.select(db.localContentAssets)
          ..where((t) =>
              t.packageId.equals(packageId) &
              t.relativePath.equals(relativePath)))
        .getSingleOrNull();
    return row?.bytes;
  }

  @override
  Future<void> replacePackage({
    required ContentPackageManifest manifest,
    required List<ContentEntry> entries,
    required String contentHash,
    Map<String, Uint8List> assets = const {},
  }) async {
    final db = _database;
    final packageId = manifest.id;

    await db.transaction(() async {
      final prefix = '$packageId:%';
      await (db.delete(db.contentLinks)
            ..where((t) => t.sourceId.like(prefix) | t.targetId.like(prefix)))
          .go();
      await (db.delete(db.localContentEntries)
            ..where((t) => t.packageId.equals(packageId)))
          .go();
      await (db.delete(db.localContentAssets)
            ..where((t) => t.packageId.equals(packageId)))
          .go();
      await (db.delete(db.localContentPackages)
            ..where((t) => t.id.equals(packageId)))
          .go();

      await db.into(db.localContentPackages).insert(
            LocalContentPackagesCompanion.insert(
              id: packageId,
              formatVersion: manifest.formatVersion,
              name: manifest.name,
              version: manifest.version,
              locale: manifest.locale,
              system: manifest.system,
              entryCount: manifest.entryCount,
              contentHash: contentHash,
              enabled: const Value(true),
              installedAt: DateTime.now(),
            ),
          );

      var linkIndex = 0;
      for (final entry in entries) {
        await db.into(db.localContentEntries).insert(
              LocalContentEntriesCompanion.insert(
                entryKey: entry.id,
                packageId: packageId,
                type: entry.type,
                slug: entry.slug,
                name: entry.name,
                aliasesJson: Value(jsonEncode(entry.aliases)),
                summary: Value(entry.summary),
                bodyJson: Value(
                  jsonEncode(entry.body.map((b) => b.toJson()).toList()),
                ),
                structuredJson: Value(jsonEncode(entry.structured)),
                rulesJson: Value(jsonEncode(entry.rules?.toJson() ?? const {})),
                tagsJson: Value(jsonEncode(entry.tags)),
                sourceLabel: Value(entry.source.label),
                revision: entry.revision,
              ),
            );

        for (final block in entry.body) {
          if (block is EntryLinkBlock) {
            await db.into(db.contentLinks).insert(
                  ContentLinksCompanion.insert(
                    id: '${entry.id}#${linkIndex++}',
                    sourceId: entry.id,
                    targetId: block.targetId,
                    linkText: Value(block.text),
                  ),
                );
          }
        }
      }

      for (final entry in assets.entries) {
        await db.into(db.localContentAssets).insert(
              LocalContentAssetsCompanion.insert(
                packageId: packageId,
                relativePath: entry.key,
                bytes: entry.value,
                mediaType: const Value(''),
                contentHash: const Value(''),
              ),
            );
      }

      await _enqueueVaultOperation(
        entityType: 'installedPackageManifest',
        entityId: packageId,
        payloadJson: jsonEncode({
          'id': manifest.id,
          'version': manifest.version,
          'locale': manifest.locale,
          'system': manifest.system,
          'contentHash': contentHash,
        }),
      );
    });
  }

  @override
  Future<void> setPackageEnabled(String packageId, bool enabled) async {
    final db = _database;
    await (db.update(db.localContentPackages)
          ..where((t) => t.id.equals(packageId)))
        .write(LocalContentPackagesCompanion(enabled: Value(enabled)));
  }

  @override
  Future<bool> isPackageEnabled(String packageId) async {
    final db = _database;
    final row = await (db.select(db.localContentPackages)
          ..where((t) => t.id.equals(packageId)))
        .getSingleOrNull();
    return row?.enabled ?? false;
  }

  @override
  Future<ContentDeletionImpact> deletionImpact(String packageId) async {
    final db = _database;
    final entries = db.localContentEntries;
    final favorites = db.contentFavorites;
    final notes = db.contentNotes;

    final entryKeys = await (db.selectOnly(entries)
          ..addColumns([entries.entryKey])
          ..where(entries.packageId.equals(packageId)))
        .map((row) => row.read(entries.entryKey)!)
        .get();

    if (entryKeys.isEmpty) {
      return const ContentDeletionImpact(
        entryCount: 0,
        favoriteCount: 0,
        noteCount: 0,
      );
    }

    final favCountExpr = favorites.entryKey.count();
    final favoriteCount = await (db.selectOnly(favorites)
          ..addColumns([favCountExpr])
          ..where(favorites.entryKey.isIn(entryKeys)))
        .map((row) => row.read(favCountExpr) ?? 0)
        .getSingle();

    final noteCountExpr = notes.entryKey.count();
    final noteCount = await (db.selectOnly(notes)
          ..addColumns([noteCountExpr])
          ..where(notes.entryKey.isIn(entryKeys)))
        .map((row) => row.read(noteCountExpr) ?? 0)
        .getSingle();

    return ContentDeletionImpact(
      entryCount: entryKeys.length,
      favoriteCount: favoriteCount,
      noteCount: noteCount,
    );
  }

  @override
  Future<void> deletePackage(String packageId) async {
    final db = _database;
    final entries = db.localContentEntries;

    await db.transaction(() async {
      final entryKeys = await (db.selectOnly(entries)
            ..addColumns([entries.entryKey])
            ..where(entries.packageId.equals(packageId)))
          .map((row) => row.read(entries.entryKey)!)
          .get();

      if (entryKeys.isNotEmpty) {
        await (db.delete(db.contentLinks)
              ..where(
                  (t) => t.sourceId.isIn(entryKeys) | t.targetId.isIn(entryKeys)))
            .go();
        await (db.delete(db.contentFavorites)
              ..where((t) => t.entryKey.isIn(entryKeys)))
            .go();
        await (db.delete(db.contentNotes)
              ..where((t) => t.entryKey.isIn(entryKeys)))
            .go();
        await (db.delete(db.contentReadHistory)
              ..where((t) => t.entryKey.isIn(entryKeys)))
            .go();
      }

      await (db.delete(db.localContentEntries)
            ..where((t) => t.packageId.equals(packageId)))
          .go();
      await (db.delete(db.localContentAssets)
            ..where((t) => t.packageId.equals(packageId)))
          .go();
      await (db.delete(db.localContentPackages)
            ..where((t) => t.id.equals(packageId)))
          .go();
    });
  }

  @override
  Future<void> setFavorite(String entryKey, bool favorite) async {
    final db = _database;
    await db.transaction(() async {
      if (favorite) {
        await db.into(db.contentFavorites).insertOnConflictUpdate(
              ContentFavoritesCompanion.insert(
                entryKey: entryKey,
                createdAt: DateTime.now(),
              ),
            );
      } else {
        await (db.delete(db.contentFavorites)
              ..where((t) => t.entryKey.equals(entryKey)))
            .go();
      }
      await _enqueueVaultOperation(
        entityType: 'favorite',
        entityId: entryKey,
        payloadJson: jsonEncode({'entryKey': entryKey, 'favorite': favorite}),
      );
    });
  }

  @override
  Future<bool> isFavorite(String entryKey) async {
    final db = _database;
    final row = await (db.select(db.contentFavorites)
          ..where((t) => t.entryKey.equals(entryKey)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> saveNote(String entryKey, String markdown) async {
    final db = _database;
    await db.transaction(() async {
      await db.into(db.contentNotes).insertOnConflictUpdate(
            ContentNotesCompanion.insert(
              entryKey: entryKey,
              markdown: markdown,
              updatedAt: DateTime.now(),
            ),
          );
      await _enqueueVaultOperation(
        entityType: 'note',
        entityId: entryKey,
        payloadJson: jsonEncode({'entryKey': entryKey, 'markdown': markdown}),
      );
    });
  }

  Future<void> _enqueueVaultOperation({
    required String entityType,
    required String entityId,
    required String payloadJson,
  }) async {
    final db = _database;
    final revision = await (db.select(db.vaultEntityRevisions)
          ..where((row) =>
              row.entityType.equals(entityType) & row.entityId.equals(entityId)))
        .getSingleOrNull();
    await (db.delete(db.syncOutbox)
          ..where((row) =>
              row.scope.equals('vault') &
              row.entityType.equals(entityType) &
              row.entityId.equals(entityId)))
        .go();
    final now = DateTime.now();
    await db.into(db.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            id: 'vault:$entityType:$entityId:${now.microsecondsSinceEpoch}',
            scope: 'vault',
            entityType: entityType,
            entityId: entityId,
            baseRevision: Value(revision?.revision ?? 0),
            payloadJson: payloadJson,
            createdAt: now,
          ),
        );
  }

  ContentPackageManifest _mapPackage(LocalContentPackageRow row) {
    return ContentPackageManifest(
      formatVersion: row.formatVersion,
      id: row.id,
      name: row.name,
      version: row.version,
      locale: row.locale,
      system: row.system,
      entryCount: row.entryCount,
    );
  }

  ContentEntry _mapEntry(LocalContentEntryRow row) {
    final json = <String, Object?>{
      'id': row.entryKey,
      'type': row.type,
      'slug': row.slug,
      'name': row.name,
      'body': jsonDecode(row.bodyJson) as List<Object?>,
      'revision': row.revision,
      'aliases': jsonDecode(row.aliasesJson) as List<Object?>,
      'summary': row.summary,
      'structured': jsonDecode(row.structuredJson),
      'tags': jsonDecode(row.tagsJson) as List<Object?>,
    };
    final rules = jsonDecode(row.rulesJson);
    if (rules is Map && rules.isNotEmpty) {
      json['rules'] = rules;
    }
    if (row.sourceLabel.isNotEmpty) {
      json['source'] = {'label': row.sourceLabel};
    }
    return ContentEntry.fromJson(json);
  }
}

/// No-op [ContentRepository] used as a fallback when no database is available
/// (e.g. tests that inject in-memory stores).
class EmptyContentRepository implements ContentRepository {
  @override
  Stream<List<ContentPackageManifest>> watchPackages() =>
      Stream.value(const []);
  @override
  Future<List<ContentEntry>> search(ContentQuery query) async => const [];
  @override
  Future<ContentEntry?> getByKey(String entryKey) async => null;
  @override
  Future<List<ContentLink>> outgoingLinks(String entryKey) async => const [];
  @override
  Future<List<ContentLink>> incomingLinks(String entryKey) async => const [];
  @override
  Future<Uint8List?> readAsset(String packageId, String relativePath) async =>
      null;
  @override
  Future<void> replacePackage({
    required ContentPackageManifest manifest,
    required List<ContentEntry> entries,
    required String contentHash,
    Map<String, Uint8List> assets = const {},
  }) async {}
  @override
  Future<void> setPackageEnabled(String packageId, bool enabled) async {}

  @override
  Future<bool> isPackageEnabled(String packageId) async => false;

  @override
  Future<ContentDeletionImpact> deletionImpact(String packageId) async =>
      const ContentDeletionImpact(
        entryCount: 0,
        favoriteCount: 0,
        noteCount: 0,
      );
  @override
  Future<void> deletePackage(String packageId) async {}
  @override
  Future<void> setFavorite(String entryKey, bool favorite) async {}
  @override
  Future<bool> isFavorite(String entryKey) async => false;
  @override
  Future<void> saveNote(String entryKey, String markdown) async {}
}
