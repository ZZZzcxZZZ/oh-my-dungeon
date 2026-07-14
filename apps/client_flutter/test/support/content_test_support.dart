import 'dart:async';
import 'dart:typed_data';

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
    });

class MemoryContentFilePicker implements ContentFilePicker {
  MemoryContentFilePicker({this.result});

  PickedContentFile? result;

  @override
  Future<PickedContentFile?> pick() async => result;
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

    _packages[packageId] = manifest;
    _enabled[packageId] = true;

    for (final entry in entries) {
      _entries[entry.id] = entry;
      for (final block in entry.body) {
        if (block is EntryLinkBlock) {
          _links.add(ContentLink(
            sourceId: entry.id,
            targetId: block.targetId,
            linkText: block.text,
          ));
        }
      }
    }

    _assets[packageId] = Map.from(assets);
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

  @override
  Future<ContentDeletionImpact> deletionImpact(String packageId) async {
    final entryKeys = _entries.keys
        .where((key) => key.startsWith('$packageId:'))
        .toList();
    final favoriteCount =
        entryKeys.where((key) => _favorites.contains(key)).length;
    final noteCount =
        entryKeys.where((key) => _notes.containsKey(key)).length;
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
  Future<void> setFavorite(String entryKey, bool favorite) async {
    if (favorite) {
      _favorites.add(entryKey);
    } else {
      _favorites.remove(entryKey);
    }
  }

  @override
  Future<bool> isFavorite(String entryKey) async => _favorites.contains(entryKey);

  @override
  Future<void> saveNote(String entryKey, String markdown) async {
    _notes[entryKey] = markdown;
  }
}
