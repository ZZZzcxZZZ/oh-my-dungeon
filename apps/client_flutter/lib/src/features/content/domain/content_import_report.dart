import 'dart:typed_data';

import 'content_entry.dart';

class ContentValidationError {
  final String path;
  final String message;
  const ContentValidationError({required this.path, required this.message});
}

class ContentImportReport {
  final bool valid;
  final int formatVersion;
  final String packageId;
  final String packageName;
  final String version;
  final String locale;
  final String system;
  final int entryCount;
  final List<ContentEntry> entries;
  final List<ContentValidationError> errors;

  /// 不阻断导入的诊断（规则契约里的 warning 级诊断）。
  ///
  /// 可选具名参数 + 默认空列表：`ContentImportReport` 是公开类型，新增字段
  /// 不能破坏既有构造点（批量导入向导里的异常兜底报告等）。
  final List<ContentValidationError> warnings;
  final Map<String, Uint8List> assets;
  final String contentHash;
  const ContentImportReport({
    required this.valid,
    required this.formatVersion,
    required this.packageId,
    required this.packageName,
    required this.version,
    required this.locale,
    required this.system,
    required this.entryCount,
    required this.entries,
    required this.errors,
    this.warnings = const [],
    required this.assets,
    required this.contentHash,
  });
}
