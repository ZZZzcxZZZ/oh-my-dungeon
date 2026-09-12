import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_file_picker.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';

ContentEntry testFighterEntry() => ContentEntry.fromJson({
  'id': 'example:class/fighter',
  'type': 'class',
  'slug': 'fighter',
  'name': '战士',
  'body': <Map<String, Object?>>[],
  'revision': 1,
  // 任务 11 起：命内置 slug 的职业条目必须显式声明 classRules，否则导入被拒。
  'structured': <String, Object?>{
    'classRules': <String, Object?>{'hitDie': 10},
  },
});

/// 构造一个 `.dndpack` 字节流（manifest.json + entries.json）。
Uint8List dndPackBytes({
  required Map<String, Object?> manifest,
  required List<Map<String, Object?>> entries,
  Map<String, List<int>> assets = const {},
}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest))),
    )
    ..addFile(
      ArchiveFile.bytes('entries.json', utf8.encode(jsonEncode(entries))),
    );
  for (final asset in assets.entries) {
    archive.addFile(ArchiveFile.bytes(asset.key, asset.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

class MemoryContentFilePicker implements ContentFilePicker {
  MemoryContentFilePicker({this.result, this.multipleResult});

  PickedContentFile? result;
  List<PickedContentFile>? multipleResult;

  @override
  Future<PickedContentFile?> pick() async => result;

  @override
  Future<List<PickedContentFile>> pickMultiple() async =>
      multipleResult ?? const [];
}

class MemoryContentRepository implements ContentRepository {
  MemoryContentRepository({List<ContentEntry> initialEntries = const []}) {
    for (final entry in initialEntries) {
      _entries[entry.id] = entry;
      final packageId = entry.id.split(':').first;
      _packages.putIfAbsent(
        packageId,
        () => ContentPackageManifest(
          formatVersion: 1,
          id: packageId,
          name: packageId,
          version: '1.0.0',
          locale: 'zh-CN',
          system: 'dnd5e-2024',
          entryCount: 1,
        ),
      );
      _enabled.putIfAbsent(packageId, () => true);
    }
  }

  final Map<String, ContentEntry> _entries = {};
  final Map<String, bool> _enabled = {};
  final Map<String, ContentPackageManifest> _packages = {};
  final Set<String> _favorites = {};
  final Map<String, String> _notes = {};
  final Map<String, Map<String, Uint8List>> _assets = {};
  final List<ContentLink> _links = [];
  final _controller =
      StreamController<List<ContentPackageManifest>>.broadcast();

  void _emit() {
    _controller.add(_packages.values.toList());
  }

  @override
  Stream<List<ContentPackageManifest>> watchPackages() {
    final controller =
        StreamController<List<ContentPackageManifest>>.broadcast();
    scheduleMicrotask(() => controller.add(_packages.values.toList()));
    _controller.stream.listen(controller.add);
    return controller.stream;
  }

  @override
  Future<List<ContentEntry>> search(ContentQuery query) async {
    final results = <ContentEntry>[];
    for (final entry in _entries.values) {
      final packageId = entry.id.split(':').first;
      final package = _packages[packageId];
      if (package == null) continue;
      final enabled = _enabled[packageId] ?? true;
      if (!enabled) continue;

      if (query.packageId != null && packageId != query.packageId) continue;
      if (query.type != null && entry.type != query.type) continue;
      if (query.favoritesOnly && !_favorites.contains(entry.id)) continue;
      if (!contentEntryMatchesFacets(entry, query.facets)) continue;

      if (query.text != null && query.text!.isNotEmpty) {
        final needle = query.text!.toLowerCase();
        final hay = [
          entry.name,
          entry.summary,
          entry.source.label,
          ...entry.aliases,
          ...entry.tags,
        ].join('\n').toLowerCase();
        if (!hay.contains(needle)) continue;
      }

      results.add(entry);
    }
    return results;
  }

  @override
  Future<ContentEntry?> getByKey(String entryKey) async {
    return _entries[entryKey];
  }

  @override
  Future<List<ContentLink>> outgoingLinks(String entryKey) async {
    return _links.where((link) => link.sourceId == entryKey).toList();
  }

  @override
  Future<List<ContentLink>> incomingLinks(String entryKey) async {
    return _links.where((link) => link.targetId == entryKey).toList();
  }

  @override
  Future<Uint8List?> readAsset(String packageId, String relativePath) async {
    return _assets[packageId]?[relativePath];
  }

  @override
  Future<void> replacePackage({
    required ContentPackageManifest manifest,
    required List<ContentEntry> entries,
    required String contentHash,
    Map<String, Uint8List> assets = const {},
  }) async {
    final packageId = manifest.id;
    _links.removeWhere(
      (link) =>
          link.sourceId.startsWith('$packageId:') ||
          link.targetId.startsWith('$packageId:'),
    );
    _entries.removeWhere((key, _) => key.startsWith('$packageId:'));
    _assets.remove(packageId);
    _packages.remove(packageId);

    _packages[packageId] = manifest.copyWith(contentHash: contentHash);
    _enabled[packageId] = true;

    for (final entry in entries) {
      _entries[entry.id] = entry;
      for (final block in entry.body) {
        if (block is EntryLinkBlock) {
          _links.add(
            ContentLink(
              sourceId: entry.id,
              targetId: block.targetId,
              linkText: block.text,
            ),
          );
        }
      }
    }

    _assets[packageId] = Map.from(assets);
    _emit();
  }

  @override
  Future<void> upsertPackageEntry({
    required ContentPackageManifest manifest,
    required ContentEntry entry,
  }) async {
    _packages[manifest.id] = ContentPackageManifest(
      formatVersion: manifest.formatVersion,
      id: manifest.id,
      name: manifest.name,
      version: manifest.version,
      locale: manifest.locale,
      system: manifest.system,
      entryCount: 0,
      priority: manifest.priority,
      contentHash: manifest.contentHash,
    );
    _enabled[manifest.id] = true;
    _entries[entry.id] = entry;
    final count = _entries.keys
        .where((key) => key.startsWith('${manifest.id}:'))
        .length;
    _packages[manifest.id] = ContentPackageManifest(
      formatVersion: manifest.formatVersion,
      id: manifest.id,
      name: manifest.name,
      version: manifest.version,
      locale: manifest.locale,
      system: manifest.system,
      entryCount: count,
      priority: manifest.priority,
      contentHash: 'local-$count',
    );
    _emit();
  }

  @override
  Future<void> deletePackageEntry(String entryKey) async {
    final packageId = entryKey.split(':').first;
    _entries.remove(entryKey);
    _favorites.remove(entryKey);
    _notes.remove(entryKey);
    _links.removeWhere(
      (link) => link.sourceId == entryKey || link.targetId == entryKey,
    );
    final package = _packages[packageId];
    if (package != null) {
      final count = _entries.keys
          .where((key) => key.startsWith('$packageId:'))
          .length;
      _packages[packageId] = ContentPackageManifest(
        formatVersion: package.formatVersion,
        id: package.id,
        name: package.name,
        version: package.version,
        locale: package.locale,
        system: package.system,
        entryCount: count,
        priority: package.priority,
        contentHash: 'local-$count',
      );
    }
    _emit();
  }

  @override
  Future<void> setPackageEnabled(String packageId, bool enabled) async {
    _enabled[packageId] = enabled;
    _emit();
  }

  @override
  Future<bool> isPackageEnabled(String packageId) async =>
      _enabled[packageId] ?? false;

  /// 测试替身：从内存 manifest 投影（与真实仓库的 `packagePriorities()` 同义），
  /// 不另存一份 priority。
  @override
  Future<Map<String, int>> packagePriorities() async => {
    for (final package in _packages.values) package.id: package.priority,
  };

  @override
  Future<ContentDeletionImpact> deletionImpact(String packageId) async {
    final entryKeys = _entries.keys
        .where((key) => key.startsWith('$packageId:'))
        .toList();
    final favoriteCount = entryKeys
        .where((key) => _favorites.contains(key))
        .length;
    final noteCount = entryKeys.where((key) => _notes.containsKey(key)).length;
    return ContentDeletionImpact(
      entryCount: entryKeys.length,
      favoriteCount: favoriteCount,
      noteCount: noteCount,
    );
  }

  @override
  Future<void> deletePackage(String packageId) async {
    final entryKeys = _entries.keys
        .where((key) => key.startsWith('$packageId:'))
        .toList();
    for (final key in entryKeys) {
      _entries.remove(key);
      _favorites.remove(key);
      _notes.remove(key);
    }
    _links.removeWhere(
      (link) =>
          link.sourceId.startsWith('$packageId:') ||
          link.targetId.startsWith('$packageId:'),
    );
    _assets.remove(packageId);
    _packages.remove(packageId);
    _enabled.remove(packageId);
    _emit();
  }

  @override
  Future<int> clearAllPackages() async {
    final count = _entries.length;
    _entries.clear();
    _favorites.clear();
    _notes.clear();
    _links.clear();
    _assets.clear();
    _packages.clear();
    _enabled.clear();
    _emit();
    return count;
  }

  @override
  Future<void> setFavorite(String entryKey, bool favorite) async {
    if (favorite) {
      _favorites.add(entryKey);
    } else {
      _favorites.remove(entryKey);
    }
  }

  @override
  Future<bool> isFavorite(String entryKey) async =>
      _favorites.contains(entryKey);

  @override
  Future<void> saveNote(String entryKey, String markdown) async {
    _notes[entryKey] = markdown;
  }

  @override
  Future<void> updateEntry(ContentEntry entry) async {
    if (!_entries.containsKey(entry.id)) {
      throw StateError(
        'Cannot update entry ${entry.id}: not present in local repository',
      );
    }
    _entries[entry.id] = entry;
    // 重建 outgoing links (body 可能变更).
    _links.removeWhere((link) => link.sourceId == entry.id);
    for (final block in entry.body) {
      if (block is EntryLinkBlock) {
        _links.add(
          ContentLink(
            sourceId: entry.id,
            targetId: block.targetId,
            linkText: block.text,
          ),
        );
      }
    }
  }

  @override
  Future<ContentEntry?> duplicateEntry(
    String entryKey, {
    required String newName,
  }) async {
    final source = _entries[entryKey];
    if (source == null) return null;
    final packageId = source.id.split(':').first;
    final baseSlug = '${source.slug}-copy';
    var newSlug = baseSlug;
    var newKey = '$packageId:${source.type}/$newSlug';
    var counter = 2;
    while (_entries.containsKey(newKey)) {
      newSlug = '$baseSlug-$counter';
      newKey = '$packageId:${source.type}/$newSlug';
      counter += 1;
    }
    final json = source.toJson();
    json['id'] = newKey;
    json['slug'] = newSlug;
    json['name'] = newName;
    final duplicate = ContentEntry.fromJson(json);
    _entries[newKey] = duplicate;
    for (final block in source.body) {
      if (block is EntryLinkBlock) {
        _links.add(
          ContentLink(
            sourceId: newKey,
            targetId: block.targetId,
            linkText: block.text,
          ),
        );
      }
    }
    return duplicate;
  }
}
