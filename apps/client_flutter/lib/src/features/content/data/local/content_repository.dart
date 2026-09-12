import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_package_manifest.dart';
import '../../domain/content_schema_registry.dart';

class ContentQuery {
  const ContentQuery({
    this.text,
    this.type,
    this.favoritesOnly = false,
    this.packageId,
    this.facets = const <String, Set<String>>{},
  });

  final String? text;
  final String? type;
  final bool favoritesOnly;
  final String? packageId;
  final Map<String, Set<String>> facets;
}

bool contentEntryMatchesFacets(
  ContentEntry entry,
  Map<String, Set<String>> facets,
) {
  for (final facet in facets.entries) {
    if (facet.value.isEmpty) continue;
    final raw = entry.structured[facet.key];
    final values = normalizedContentFacetValues(entry, facet.key, raw);
    if (!values.any(facet.value.contains)) return false;
  }
  return true;
}

Set<String> normalizedContentFacetValues(
  ContentEntry entry,
  String field,
  Object? raw,
) {
  if (raw == null) {
    final schema = ContentSchemaRegistry.defaults.schemaFor(entry.type);
    for (final definition in schema.fields) {
      if (definition.key != field) continue;
      for (final alias in definition.aliases) {
        final legacyValue = entry.structured[alias];
        if (legacyValue != null) {
          raw = legacyValue;
          break;
        }
      }
    }
  }
  return ContentSchemaRegistry.defaults.normalizeFacetValues(
    entry.type,
    field,
    raw,
    entry: entry,
  );
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
  Future<void> upsertPackageEntry({
    required ContentPackageManifest manifest,
    required ContentEntry entry,
  });
  Future<void> deletePackageEntry(String entryKey);
  Future<void> setPackageEnabled(String packageId, bool enabled);
  Future<bool> isPackageEnabled(String packageId);

  /// 每个已安装包的规则覆盖优先级（S3 决策 D2）。键 = packageId，缺省 0。
  /// 只读投影，供 `RuleOverrideIndex` 构建使用；UI 不直接查库。
  Future<Map<String, int>> packagePriorities();
  Future<ContentDeletionImpact> deletionImpact(String packageId);
  Future<void> deletePackage(String packageId);

  /// Spec §资料包: 一键清除所有本地资料包及其条目、收藏、笔记和资源。
  /// 用于旧版数据污染时重置；返回受影响的条目数。
  Future<int> clearAllPackages();
  Future<void> setFavorite(String entryKey, bool favorite);
  Future<bool> isFavorite(String entryKey);
  Future<void> saveNote(String entryKey, String markdown);

  /// Spec §资料库 GUI 增强: 编辑条目. 用相同 id 覆盖可变字段
  /// (name / summary / body / aliases / tags / structured / relations /
  /// rules / source / revision). 收藏、笔记、读历史以 entryKey 为键, 因此
  /// 保留. 如果条目不存在则抛 [StateError].
  Future<void> updateEntry(ContentEntry entry);

  /// Spec §资料库 GUI 增强: 复制条目. 在同一资料包内创建一个新条目,
  /// id 形如 `{packageId}:{type}/{slug}-copy`, 名称由 [newName] 提供.
  /// 源条目不存在时返回 null. 副本不带收藏 / 笔记 / 读历史.
  Future<ContentEntry?> duplicateEntry(
    String entryKey, {
    required String newName,
  });
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
      predicate =
          predicate &
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
        innerJoin(favorites, favorites.entryKey.equalsExp(entries.entryKey)),
      ]);
    }

    final rows = await stmt.get();
    return rows
        .map((row) => _mapEntry(row.readTable(entries)))
        .where((entry) => contentEntryMatchesFacets(entry, query.facets))
        .toList();
  }

  @override
  Future<ContentEntry?> getByKey(String entryKey) async {
    final db = _database;
    final row = await (db.select(
      db.localContentEntries,
    )..where((t) => t.entryKey.equals(entryKey))).getSingleOrNull();
    return row == null ? null : _mapEntry(row);
  }

  @override
  Future<List<ContentLink>> outgoingLinks(String entryKey) async {
    final db = _database;
    final rows =
        await (db.select(db.contentLinks)
              ..where((t) => t.sourceId.equals(entryKey))
              ..orderBy([(t) => OrderingTerm.asc(t.targetId)]))
            .get();
    return rows
        .map(
          (row) => ContentLink(
            sourceId: row.sourceId,
            targetId: row.targetId,
            linkText: row.linkText,
          ),
        )
        .toList();
  }

  @override
  Future<List<ContentLink>> incomingLinks(String entryKey) async {
    final db = _database;
    final rows =
        await (db.select(db.contentLinks)
              ..where((t) => t.targetId.equals(entryKey))
              ..orderBy([(t) => OrderingTerm.asc(t.sourceId)]))
            .get();
    return rows
        .map(
          (row) => ContentLink(
            sourceId: row.sourceId,
            targetId: row.targetId,
            linkText: row.linkText,
          ),
        )
        .toList();
  }

  @override
  Future<Uint8List?> readAsset(String packageId, String relativePath) async {
    final db = _database;
    final row =
        await (db.select(db.localContentAssets)..where(
              (t) =>
                  t.packageId.equals(packageId) &
                  t.relativePath.equals(relativePath),
            ))
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
      await (db.delete(
        db.contentLinks,
      )..where((t) => t.sourceId.like(prefix) | t.targetId.like(prefix))).go();
      await (db.delete(
        db.localContentEntries,
      )..where((t) => t.packageId.equals(packageId))).go();
      await (db.delete(
        db.localContentAssets,
      )..where((t) => t.packageId.equals(packageId))).go();
      await (db.delete(
        db.localContentPackages,
      )..where((t) => t.id.equals(packageId))).go();

      await db
          .into(db.localContentPackages)
          .insert(
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
              priority: Value(manifest.priority),
              installedAt: DateTime.now(),
            ),
          );

      var linkIndex = 0;
      for (final entry in entries) {
        await db
            .into(db.localContentEntries)
            .insert(
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
                relationsJson: Value(
                  jsonEncode(
                    entry.relations
                        .map((relation) => relation.toJson())
                        .toList(),
                  ),
                ),
                tagsJson: Value(jsonEncode(entry.tags)),
                sourceLabel: Value(entry.source.label),
                revision: entry.revision,
              ),
            );

        for (final block in entry.body) {
          if (block is EntryLinkBlock) {
            await db
                .into(db.contentLinks)
                .insert(
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
        await db
            .into(db.localContentAssets)
            .insert(
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
  Future<void> upsertPackageEntry({
    required ContentPackageManifest manifest,
    required ContentEntry entry,
  }) async {
    final packageId = manifest.id;
    if (!entry.id.startsWith('$packageId:')) {
      throw ArgumentError('Entry ${entry.id} does not belong to $packageId');
    }
    final db = _database;
    await db.transaction(() async {
      final existingPackage = await (db.select(
        db.localContentPackages,
      )..where((row) => row.id.equals(packageId))).getSingleOrNull();
      if (existingPackage == null) {
        await db
            .into(db.localContentPackages)
            .insert(
              LocalContentPackagesCompanion.insert(
                id: packageId,
                formatVersion: manifest.formatVersion,
                name: manifest.name,
                version: manifest.version,
                locale: manifest.locale,
                system: manifest.system,
                entryCount: 0,
                contentHash: manifest.contentHash,
                priority: Value(manifest.priority),
                installedAt: DateTime.now(),
              ),
            );
      }

      await (db.delete(
        db.contentLinks,
      )..where((link) => link.sourceId.equals(entry.id))).go();
      await db
          .into(db.localContentEntries)
          .insertOnConflictUpdate(
            LocalContentEntriesCompanion.insert(
              entryKey: entry.id,
              packageId: packageId,
              type: entry.type,
              slug: entry.slug,
              name: entry.name,
              aliasesJson: Value(jsonEncode(entry.aliases)),
              summary: Value(entry.summary),
              bodyJson: Value(
                jsonEncode(entry.body.map((block) => block.toJson()).toList()),
              ),
              structuredJson: Value(jsonEncode(entry.structured)),
              rulesJson: Value(jsonEncode(entry.rules?.toJson() ?? const {})),
              relationsJson: Value(
                jsonEncode(
                  entry.relations.map((relation) => relation.toJson()).toList(),
                ),
              ),
              tagsJson: Value(jsonEncode(entry.tags)),
              sourceLabel: Value(entry.source.label),
              revision: entry.revision,
            ),
          );

      var linkIndex = 0;
      for (final block in entry.body.whereType<EntryLinkBlock>()) {
        await db
            .into(db.contentLinks)
            .insert(
              ContentLinksCompanion.insert(
                id: '${entry.id}#${linkIndex++}',
                sourceId: entry.id,
                targetId: block.targetId,
                linkText: Value(block.text),
              ),
            );
      }
      await _refreshPackageEntryCount(packageId);
    });
  }

  @override
  Future<void> deletePackageEntry(String entryKey) async {
    final db = _database;
    await db.transaction(() async {
      final row = await (db.select(
        db.localContentEntries,
      )..where((entry) => entry.entryKey.equals(entryKey))).getSingleOrNull();
      if (row == null) return;
      await (db.delete(db.contentLinks)..where(
            (link) =>
                link.sourceId.equals(entryKey) | link.targetId.equals(entryKey),
          ))
          .go();
      await (db.delete(
        db.contentFavorites,
      )..where((item) => item.entryKey.equals(entryKey))).go();
      await (db.delete(
        db.contentNotes,
      )..where((item) => item.entryKey.equals(entryKey))).go();
      await (db.delete(
        db.contentReadHistory,
      )..where((item) => item.entryKey.equals(entryKey))).go();
      await (db.delete(
        db.localContentEntries,
      )..where((entry) => entry.entryKey.equals(entryKey))).go();
      await _refreshPackageEntryCount(row.packageId);
    });
  }

  Future<void> _refreshPackageEntryCount(String packageId) async {
    final countExpression = _database.localContentEntries.entryKey.count();
    final count =
        await (_database.selectOnly(_database.localContentEntries)
              ..addColumns([countExpression])
              ..where(
                _database.localContentEntries.packageId.equals(packageId),
              ))
            .map((row) => row.read(countExpression) ?? 0)
            .getSingle();
    await (_database.update(
      _database.localContentPackages,
    )..where((row) => row.id.equals(packageId))).write(
      LocalContentPackagesCompanion(
        entryCount: Value(count),
        contentHash: Value('local-${DateTime.now().microsecondsSinceEpoch}'),
      ),
    );
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
    final row = await (db.select(
      db.localContentPackages,
    )..where((t) => t.id.equals(packageId))).getSingleOrNull();
    return row?.enabled ?? false;
  }

  @override
  Future<Map<String, int>> packagePriorities() async {
    final db = _database;
    final rows = await db.select(db.localContentPackages).get();
    return {for (final row in rows) row.id: row.priority};
  }

  @override
  Future<ContentDeletionImpact> deletionImpact(String packageId) async {
    final db = _database;
    final entries = db.localContentEntries;
    final favorites = db.contentFavorites;
    final notes = db.contentNotes;

    final entryKeys =
        await (db.selectOnly(entries)
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
    final favoriteCount =
        await (db.selectOnly(favorites)
              ..addColumns([favCountExpr])
              ..where(favorites.entryKey.isIn(entryKeys)))
            .map((row) => row.read(favCountExpr) ?? 0)
            .getSingle();

    final noteCountExpr = notes.entryKey.count();
    final noteCount =
        await (db.selectOnly(notes)
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
      final entryKeys =
          await (db.selectOnly(entries)
                ..addColumns([entries.entryKey])
                ..where(entries.packageId.equals(packageId)))
              .map((row) => row.read(entries.entryKey)!)
              .get();

      if (entryKeys.isNotEmpty) {
        await (db.delete(db.contentLinks)..where(
              (t) => t.sourceId.isIn(entryKeys) | t.targetId.isIn(entryKeys),
            ))
            .go();
        await (db.delete(
          db.contentFavorites,
        )..where((t) => t.entryKey.isIn(entryKeys))).go();
        await (db.delete(
          db.contentNotes,
        )..where((t) => t.entryKey.isIn(entryKeys))).go();
        await (db.delete(
          db.contentReadHistory,
        )..where((t) => t.entryKey.isIn(entryKeys))).go();
      }

      await (db.delete(
        db.localContentEntries,
      )..where((t) => t.packageId.equals(packageId))).go();
      await (db.delete(
        db.localContentAssets,
      )..where((t) => t.packageId.equals(packageId))).go();
      await (db.delete(
        db.localContentPackages,
      )..where((t) => t.id.equals(packageId))).go();
    });
  }

  @override
  Future<int> clearAllPackages() async {
    final db = _database;
    return db.transaction(() async {
      final entryCount =
          await (db.selectOnly(db.localContentEntries)
                ..addColumns([db.localContentEntries.entryKey.count()]))
              .map(
                (row) => row.read(db.localContentEntries.entryKey.count()) ?? 0,
              )
              .getSingle();
      // Order matters: child tables (links/favorites/notes/history/assets)
      // reference entries/packages, so clear them first.
      await db.delete(db.contentLinks).go();
      await db.delete(db.contentFavorites).go();
      await db.delete(db.contentNotes).go();
      await db.delete(db.contentReadHistory).go();
      await db.delete(db.localContentAssets).go();
      await db.delete(db.localContentEntries).go();
      await db.delete(db.localContentPackages).go();
      return entryCount;
    });
  }

  @override
  Future<void> setFavorite(String entryKey, bool favorite) async {
    final db = _database;
    await db.transaction(() async {
      if (favorite) {
        await db
            .into(db.contentFavorites)
            .insertOnConflictUpdate(
              ContentFavoritesCompanion.insert(
                entryKey: entryKey,
                createdAt: DateTime.now(),
              ),
            );
      } else {
        await (db.delete(
          db.contentFavorites,
        )..where((t) => t.entryKey.equals(entryKey))).go();
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
    final row = await (db.select(
      db.contentFavorites,
    )..where((t) => t.entryKey.equals(entryKey))).getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> saveNote(String entryKey, String markdown) async {
    final db = _database;
    await db.transaction(() async {
      await db
          .into(db.contentNotes)
          .insertOnConflictUpdate(
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

  @override
  Future<void> updateEntry(ContentEntry entry) async {
    final db = _database;
    final entries = db.localContentEntries;
    final existing = await (db.select(
      entries,
    )..where((t) => t.entryKey.equals(entry.id))).getSingleOrNull();
    if (existing == null) {
      throw StateError(
        'Cannot update entry ${entry.id}: not present in local repository',
      );
    }
    await db.transaction(() async {
      // 重新写一遍 links, 因为 body 可能变更导致链接集合变化.
      await (db.delete(
        db.contentLinks,
      )..where((t) => t.sourceId.equals(entry.id))).go();
      await (db.update(
        entries,
      )..where((t) => t.entryKey.equals(entry.id))).write(
        LocalContentEntriesCompanion(
          name: Value(entry.name),
          aliasesJson: Value(jsonEncode(entry.aliases)),
          summary: Value(entry.summary),
          bodyJson: Value(
            jsonEncode(entry.body.map((b) => b.toJson()).toList()),
          ),
          structuredJson: Value(jsonEncode(entry.structured)),
          rulesJson: Value(jsonEncode(entry.rules?.toJson() ?? const {})),
          relationsJson: Value(
            jsonEncode(entry.relations.map((r) => r.toJson()).toList()),
          ),
          tagsJson: Value(jsonEncode(entry.tags)),
          sourceLabel: Value(entry.source.label),
          revision: Value(entry.revision),
        ),
      );
      var linkIndex = 0;
      for (final block in entry.body) {
        if (block is EntryLinkBlock) {
          await db
              .into(db.contentLinks)
              .insert(
                ContentLinksCompanion.insert(
                  id: '${entry.id}#${linkIndex++}',
                  sourceId: entry.id,
                  targetId: block.targetId,
                  linkText: Value(block.text),
                ),
              );
        }
      }
      // Imported package entries, including local edits, stay on this device.
      // Campaign sharing has its own explicit content sync path; sending the
      // full entry through Vault would upload private package bodies.
    });
  }

  @override
  Future<ContentEntry?> duplicateEntry(
    String entryKey, {
    required String newName,
  }) async {
    final db = _database;
    final entries = db.localContentEntries;
    final source = await (db.select(
      entries,
    )..where((t) => t.entryKey.equals(entryKey))).getSingleOrNull();
    if (source == null) return null;
    final newSlug = '${source.slug}-copy';
    final newKey = '${source.packageId}:${source.type}/$newSlug';
    if (await (db.select(
          entries,
        )..where((t) => t.entryKey.equals(newKey))).getSingleOrNull() !=
        null) {
      // 已存在 -copy, 试 -copy-2, -copy-3 ...
      var counter = 2;
      var candidate = '${source.packageId}:${source.type}/$newSlug-$counter';
      while (await (db.select(
            entries,
          )..where((t) => t.entryKey.equals(candidate))).getSingleOrNull() !=
          null) {
        counter += 1;
        candidate = '${source.packageId}:${source.type}/$newSlug-$counter';
      }
      return _insertDuplicate(
        source: source,
        newEntryKey: candidate,
        newSlug: '$newSlug-$counter',
        newName: newName,
      );
    }
    return _insertDuplicate(
      source: source,
      newEntryKey: newKey,
      newSlug: newSlug,
      newName: newName,
    );
  }

  Future<ContentEntry?> _insertDuplicate({
    required LocalContentEntryRow source,
    required String newEntryKey,
    required String newSlug,
    required String newName,
  }) async {
    final db = _database;
    final newEntry = ContentEntry.fromJson({
      'id': newEntryKey,
      'type': source.type,
      'slug': newSlug,
      'name': newName,
      'body': jsonDecode(source.bodyJson) as List<Object?>,
      'revision': source.revision,
      'aliases': jsonDecode(source.aliasesJson) as List<Object?>,
      'summary': source.summary,
      'structured': jsonDecode(source.structuredJson),
      'rules': jsonDecode(source.rulesJson),
      'relations': jsonDecode(source.relationsJson),
      'tags': jsonDecode(source.tagsJson) as List<Object?>,
      if (source.sourceLabel.isNotEmpty)
        'source': {'label': source.sourceLabel},
    });
    await db.transaction(() async {
      await db
          .into(db.localContentEntries)
          .insert(
            LocalContentEntriesCompanion.insert(
              entryKey: newEntryKey,
              packageId: source.packageId,
              type: source.type,
              slug: newSlug,
              name: newName,
              aliasesJson: Value(source.aliasesJson),
              summary: Value(source.summary),
              bodyJson: Value(source.bodyJson),
              structuredJson: Value(source.structuredJson),
              rulesJson: Value(source.rulesJson),
              relationsJson: Value(source.relationsJson),
              tagsJson: Value(source.tagsJson),
              sourceLabel: Value(source.sourceLabel),
              revision: source.revision,
            ),
          );
      // 复制 outgoing links (指向其他条目); incoming links 不复制 (它们由
      // 其他条目持有, 不属于本条目).
      final outgoing = await (db.select(
        db.contentLinks,
      )..where((t) => t.sourceId.equals(source.entryKey))).get();
      var linkIndex = 0;
      for (final link in outgoing) {
        await db
            .into(db.contentLinks)
            .insert(
              ContentLinksCompanion.insert(
                id: '$newEntryKey#${linkIndex++}',
                sourceId: newEntryKey,
                targetId: link.targetId,
                linkText: Value(link.linkText),
              ),
            );
      }
      // A duplicate is another local package entry. It is shared only when a
      // DM explicitly publishes it to a campaign.
    });
    return newEntry;
  }

  Future<void> _enqueueVaultOperation({
    required String entityType,
    required String entityId,
    required String payloadJson,
  }) async {
    final db = _database;
    final revision =
        await (db.select(db.vaultEntityRevisions)..where(
              (row) =>
                  row.entityType.equals(entityType) &
                  row.entityId.equals(entityId),
            ))
            .getSingleOrNull();
    await (db.delete(db.syncOutbox)..where(
          (row) =>
              row.scope.equals('vault') &
              row.entityType.equals(entityType) &
              row.entityId.equals(entityId),
        ))
        .go();
    final now = DateTime.now();
    await db
        .into(db.syncOutbox)
        .insert(
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
      priority: row.priority,
      contentHash: row.contentHash,
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
      'relations': jsonDecode(row.relationsJson),
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
  Future<void> upsertPackageEntry({
    required ContentPackageManifest manifest,
    required ContentEntry entry,
  }) async {}
  @override
  Future<void> deletePackageEntry(String entryKey) async {}
  @override
  Future<void> setPackageEnabled(String packageId, bool enabled) async {}

  @override
  Future<bool> isPackageEnabled(String packageId) async => false;

  @override
  Future<Map<String, int>> packagePriorities() async => const {};

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
  Future<int> clearAllPackages() async => 0;
  @override
  Future<void> setFavorite(String entryKey, bool favorite) async {}
  @override
  Future<bool> isFavorite(String entryKey) async => false;
  @override
  Future<void> saveNote(String entryKey, String markdown) async {}
  @override
  Future<void> updateEntry(ContentEntry entry) async {
    throw StateError(
      'Cannot update entry ${entry.id}: local repository is unavailable',
    );
  }

  @override
  Future<ContentEntry?> duplicateEntry(
    String entryKey, {
    required String newName,
  }) async => null;
}
