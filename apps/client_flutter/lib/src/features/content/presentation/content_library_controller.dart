import 'package:flutter/foundation.dart';

import '../data/local/content_repository.dart';
import '../domain/content_entry.dart';
import '../domain/content_package_manifest.dart';

class ContentLibraryController extends ChangeNotifier {
  ContentLibraryController({required this.repository});

  final ContentRepository repository;

  List<ContentEntry> results = [];
  bool isLoading = false;
  String? error;

  String? _lastText;
  String? _lastType;
  bool _lastFavoritesOnly = false;
  String? _lastPackageId;
  Map<String, Set<String>> _lastFacets = const <String, Set<String>>{};

  /// Spec §Wave 2 Task 2.1: subclass 的 `parentClass` facet 以
  /// `subclassOf` 关系为唯一数据源, 不依赖 `structured.parentClass`
  /// (资料包导入器从不写入该字段). 控制器在 search/facetOptions 时把
  /// `subclassOf` 的 targetId 解析为父职业条目的 name, 使 UI 展示
  /// 友好名称而不是裸 entryKey.
  static const _parentClassField = 'parentClass';

  Future<void> search({
    String? text,
    String? type,
    bool favoritesOnly = false,
    String? packageId,
    Map<String, Set<String>> facets = const <String, Set<String>>{},
  }) async {
    _lastText = text;
    _lastType = type;
    _lastFavoritesOnly = favoritesOnly;
    _lastPackageId = packageId;
    _lastFacets = facets;
    isLoading = true;
    notifyListeners();
    try {
      // 把 parentClass 从 structured facets 中拆出, 由控制器解析关系.
      final structuredFacets = Map<String, Set<String>>.of(facets);
      final Set<String>? parentClassSelection =
          type == 'subclass'
          ? structuredFacets.remove(_parentClassField)
          : null;

      var entries = await repository.search(
        ContentQuery(
          text: text,
          type: type,
          favoritesOnly: favoritesOnly,
          packageId: packageId,
          facets: structuredFacets,
        ),
      );

      if (parentClassSelection != null && parentClassSelection.isNotEmpty) {
        final classIdToName = await _resolveClassIdToName();
        entries = entries
            .where(
              (subclass) => _subclassMatchesParentClass(
                subclass,
                parentClassSelection,
                classIdToName,
              ),
            )
            .toList();
      }

      results = entries;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => search(
    text: _lastText,
    type: _lastType,
    favoritesOnly: _lastFavoritesOnly,
    packageId: _lastPackageId,
    facets: _lastFacets,
  );

  Future<Map<String, List<String>>> facetOptions({
    required String type,
    required Iterable<String> fields,
  }) async {
    final fieldList = fields.toList();
    final entries = await repository.search(ContentQuery(type: type));
    final values = <String, Set<String>>{
      for (final field in fieldList) field: <String>{},
    };

    // Task 2.1: parentClass 字段仅在 subclass 类型下走 subclassOf 关系解析.
    final resolveParentClass =
        type == 'subclass' && fieldList.contains(_parentClassField);
    Map<String, String>? classIdToName;
    if (resolveParentClass) {
      classIdToName = await _resolveClassIdToName();
    }

    for (final entry in entries) {
      for (final field in fieldList) {
        if (field == _parentClassField && type == 'subclass') {
          final parentClassId = _parentClassIdOf(entry);
          if (parentClassId == null) continue;
          final name = classIdToName?[parentClassId] ?? parentClassId;
          values[field]!.add(name);
          continue;
        }
        final raw = entry.structured[field];
        if (raw is Iterable) {
          values[field]!.addAll(raw.map((value) => '$value'));
        } else if (raw != null) {
          values[field]!.add('$raw');
        }
      }
    }
    return {
      for (final entry in values.entries)
        entry.key: entry.value.toList()..sort(),
    };
  }

  Future<Map<String, String>> _resolveClassIdToName() async {
    final classEntries = await repository.search(
      const ContentQuery(type: 'class'),
    );
    return {for (final entry in classEntries) entry.id: entry.name};
  }

  String? _parentClassIdOf(ContentEntry subclass) {
    for (final relation in subclass.relations) {
      if (relation.type == 'subclassOf') return relation.targetId;
    }
    return null;
  }

  bool _subclassMatchesParentClass(
    ContentEntry subclass,
    Set<String> selectedNames,
    Map<String, String> classIdToName,
  ) {
    final parentClassId = _parentClassIdOf(subclass);
    if (parentClassId == null) return false;
    final name = classIdToName[parentClassId] ?? parentClassId;
    return selectedNames.contains(name);
  }

  Future<void> toggleFavorite(String entryKey) async {
    final isFav = await isFavorite(entryKey);
    await repository.setFavorite(entryKey, !isFav);
    notifyListeners();
  }

  Future<bool> isFavorite(String entryKey) => repository.isFavorite(entryKey);

  Future<ContentEntry?> getByKey(String entryKey) =>
      repository.getByKey(entryKey);

  Future<List<ContentLink>> outgoingLinks(String entryKey) =>
      repository.outgoingLinks(entryKey);

  Future<List<ContentLink>> incomingLinks(String entryKey) =>
      repository.incomingLinks(entryKey);

  Stream<List<ContentPackageManifest>> watchPackages() =>
      repository.watchPackages();
}
