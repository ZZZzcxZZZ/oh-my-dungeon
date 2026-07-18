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

    final importer = ContentPackageImporter(_repository);
    final report = await importer.previewJson(bundle);
    if (!report.valid) {
      return false;
    }

    final installed = await _repository.watchPackages().first;
    final current = installed.where((item) => item.id == report.packageId);
    if (current.isNotEmpty && current.first.contentHash == report.contentHash) {
      return false;
    }

    await importer.importReport(report);
    return true;
  }

  static Future<String> _loadAssetBundle() => rootBundle.loadString(assetPath);
}
