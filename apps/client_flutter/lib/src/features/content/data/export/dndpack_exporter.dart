import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../domain/content_import_report.dart';
import '../import/content_package_importer.dart';
import '../local/content_repository.dart';

/// 一次 `.dndpack` 导出的产物：文件名 + 字节 + **校验通过**的报告。
class DndPackExport {
  const DndPackExport({
    required this.fileName,
    required this.bytes,
    required this.report,
  });

  final String fileName;
  final Uint8List bytes;

  /// 由**真实导入器**（`previewDndPack`，与用户导入同一条校验链）产出的报告。
  /// `valid` 恒为 true——校验不通过时本类型不会被构造出来。
  final ContentImportReport report;
}

/// 导出被导入器拒收时抛出：把报告原样带出来，UI 才能显示到字段级。
class DndPackExportException implements Exception {
  const DndPackExportException(this.report);

  final ContentImportReport report;

  String get message => report.errors.isEmpty
      ? '导出的资料包没有通过校验'
      : report.errors.first.message;
}

/// `.dndpack` 导出的**唯一实现**（S4）。
///
/// 与导入侧共用同一份契约与同一条校验链：
/// - 产物 = `manifest.json`（`formatVersion: 3`、`entryCount` = 实际条数、不带
///   `contentHash`——哈希由导入方自算）+ `entries.json`（条目的 `toJson()`）；
/// - **先校验再返回**：把刚生成的字节喂给 [ContentPackageImporter.previewDndPack]，
///   有 error 就抛 [DndPackExportException]。这样"导出一个自己都导不回来的包"
///   在实现上不可能发生——比"导出后再让用户去试"可靠。
/// - 资产：只写仓库里**确实存在**的资产（`readAsset` 返回非空）。本地自制内容
///   目前没有图片通道，因此通常没有资产；将来接入时不改这里。
class DndPackExporter {
  const DndPackExporter({
    required this.repository,
    ContentPackageImporter? importer,
  }) : _importer = importer;

  final ContentRepository repository;

  /// 测试可注入（默认用同一个 repository 构造真实导入器）。
  final ContentPackageImporter? _importer;

  ContentPackageImporter get _validator =>
      _importer ?? ContentPackageImporter(repository);

  /// 构建某个包的 `.dndpack` 字节。
  ///
  /// [assetPaths] 是"条目里引用的、位于包内 `assets/` 下的相对路径"；调用方拿不到
  /// 引用清单时可以留空（导出的包不含图片，导入仍然合法）。
  Future<DndPackExport> build({
    required String packageId,
    Iterable<String> assetPaths = const <String>[],
  }) async {
    final packages = await repository.watchPackages().first;
    final manifest = packages.where((item) => item.id == packageId).firstOrNull;
    if (manifest == null) {
      throw StateError('资料包不存在：$packageId');
    }
    final entries = await repository.search(ContentQuery(packageId: packageId));
    if (entries.isEmpty) {
      throw StateError('资料包没有条目，无从导出：$packageId');
    }

    final manifestJson = <String, Object?>{
      ...manifest.toJson(),
      // 三个字段由导出侧重算，避免 manifest 行里的旧值把包写坏。
      'formatVersion': 3,
      'entryCount': entries.length,
    }..remove('contentHash');

    final archive = Archive();
    void addFile(String name, List<int> bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    const encoder = JsonEncoder.withIndent('  ');
    addFile(
      'manifest.json',
      utf8.encode(encoder.convert(manifestJson)),
    );
    addFile(
      'entries.json',
      utf8.encode(
        encoder.convert(<Object?>[
          for (final entry in entries) entry.toJson(),
        ]),
      ),
    );
    for (final path in assetPaths) {
      final bytes = await repository.readAsset(packageId, path);
      if (bytes == null || bytes.isEmpty) continue;
      addFile('assets/$path', bytes);
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded.isEmpty) {
      throw StateError('压缩失败：$packageId');
    }
    final bytes = Uint8List.fromList(encoded);

    final report = await _validator.previewDndPack(bytes);
    if (!report.valid) {
      throw DndPackExportException(report);
    }
    return DndPackExport(
      fileName: '${manifest.id}.dndpack',
      bytes: bytes,
      report: report,
    );
  }
}
