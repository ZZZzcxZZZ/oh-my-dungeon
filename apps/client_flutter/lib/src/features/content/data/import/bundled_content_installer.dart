import 'dart:convert';

import 'package:flutter/services.dart';

import '../local/content_repository.dart';
import 'content_package_importer.dart';

class BundledContentInstaller {
  BundledContentInstaller({
    required ContentRepository repository,
    Future<String> Function()? loadBundle,
  }) : _repository = repository,
       _loadBundle = loadBundle ?? _loadAssetBundle;

  static const assetPath = 'assets/bundled_content.json';

  final ContentRepository _repository;
  final Future<String> Function() _loadBundle;

  Future<bool> installIfAvailable() async {
    final bundle = (await _loadBundle()).trim();
    if (bundle == '{}' || bundle.isEmpty) {
      return false;
    }

    final packageJson = _packageJsonDocuments(bundle);
    if (packageJson == null || packageJson.isEmpty) return false;

    final importer = ContentPackageImporter(_repository);
    final reports = await Future.wait(packageJson.map(importer.previewJson));
    if (reports.any((report) => !report.valid)) return false;
    final installed = await _repository.watchPackages().first;
    final installedHashes = {
      for (final item in installed) item.id: item.contentHash,
    };
    var changed = false;
    for (final report in reports) {
      if (installedHashes[report.packageId] == report.contentHash) continue;
      await importer.importReport(report);
      changed = true;
    }
    return changed;
  }

  static Future<String> _loadAssetBundle() => rootBundle.loadString(assetPath);
}

List<String>? _packageJsonDocuments(String source) {
  Object? root;
  try {
    root = jsonDecode(source);
  } on FormatException {
    return null;
  }
  if (root is! Map) return null;
  final packages = root['packages'];
  if (packages == null) return [source];
  if (packages is! List || packages.any((item) => item is! Map)) return null;
  return packages.map(jsonEncode).toList(growable: false);
}
