import 'package:flutter/foundation.dart';

import '../data/local/content_repository.dart';
import '../domain/content_entry.dart';
import '../domain/content_package_manifest.dart';

/// Task 2.2: facet 可选值及其命中条目数, 用于筛选面板 chip 标签展示计数.
class FacetOption {
  const FacetOption({required this.value, required this.count});

  final String value;
  final int count;
}

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
    final withCounts = await facetOptionsWithCounts(type: type, fields: fields);
    return {
      for (final entry in withCounts.entries)
        entry.key: entry.value.map((option) => option.value).toList(),
    };
  }

  /// Task 2.2: 返回每个 facet 字段的可选值及其命中条目数, 用于筛选面板
  /// chip 标签展示计数 (如「塑能 (2)」). 计数按"每条目至多贡献一次"统计:
  /// 若一条目的 classes 字段含多个职业, 该条目对每个职业各 +1,
  /// 但对同一职业不重复计数. 排序沿用 [facetOptions] 的 Unicode 序.
  Future<Map<String, List<FacetOption>>> facetOptionsWithCounts({
    required String type,
    required Iterable<String> fields,
  }) async {
    final fieldList = fields.toList();
    final entries = await repository.search(ContentQuery(type: type));
    final counts = <String, Map<String, int>>{
      for (final field in fieldList) field: <String, int>{},
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
        Set<String> entryValues;
        if (field == _parentClassField && type == 'subclass') {
          final parentClassId = _parentClassIdOf(entry);
          if (parentClassId == null) continue;
          final name = classIdToName?[parentClassId] ?? parentClassId;
          entryValues = {name};
        } else {
          final raw = entry.structured[field];
          if (raw is Iterable) {
            entryValues = raw.map((value) => '$value').toSet();
          } else if (raw != null) {
            entryValues = {'$raw'};
          } else {
            continue;
          }
        }
        final fieldCounts = counts[field]!;
        for (final value in entryValues) {
          fieldCounts[value] = (fieldCounts[value] ?? 0) + 1;
        }
      }
    }

    return {
      for (final field in fieldList)
        field: (counts[field]!.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => FacetOption(value: e.key, count: e.value))
            .toList(),
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
