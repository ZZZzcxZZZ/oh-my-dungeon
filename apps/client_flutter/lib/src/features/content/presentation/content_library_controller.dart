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
      results = await repository.search(
        ContentQuery(
          text: text,
          type: type,
          favoritesOnly: favoritesOnly,
          packageId: packageId,
          facets: facets,
        ),
      );
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
    final entries = await repository.search(ContentQuery(type: type));
    final values = <String, Set<String>>{
      for (final field in fields) field: <String>{},
    };
    for (final entry in entries) {
      for (final field in fields) {
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
