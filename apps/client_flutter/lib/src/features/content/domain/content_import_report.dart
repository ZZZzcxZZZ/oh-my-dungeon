import 'dart:typed_data';

import '../../rules/domain/rule_profile.dart';
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

  /// 规则覆盖优先级（S3 决策 D2）：0..1000，缺省 0。
  ///
  /// 具名可选参数 + 默认值：`ContentImportReport` 是公开类型，新增字段不能破坏
  /// 既有构造点（批量导入向导里的异常兜底报告等）。
  final int priority;

  /// 不阻断导入的诊断（规则契约里的 warning 级诊断）。
  ///
  /// 可选具名参数 + 默认空列表：`ContentImportReport` 是公开类型，新增字段
  /// 不能破坏既有构造点（批量导入向导里的异常兜底报告等）。
  final List<ContentValidationError> warnings;
  final Map<String, Uint8List> assets;
  final String contentHash;

  /// 每个 `class` 条目的列 → 来源（契约 §3.7）：键是条目 id，值是**该条目 + 内置
  /// 档案**合并后每个列级路径的来源，按字段路径升序。
  ///
  /// 来源只由生产解析链 `RuleProfileResolver.resolveClassRules` 产出（不另写合并
  /// 逻辑）；导入预览阶段"只看这个包 + 内置档案"，不接跨包索引——冲突是运行期
  /// 概念，导入单个包时看不到别的包。
  ///
  /// 具名可选参数 + 默认空 Map：`ContentImportReport` 是公开类型，新增字段不能
  /// 破坏既有构造点（批量导入向导里的异常兜底报告等）。
  final Map<String, List<RuleFieldSource>> classRuleSources;
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
    this.priority = 0,
    this.warnings = const [],
    this.classRuleSources = const {},
    required this.assets,
    required this.contentHash,
  });
}
