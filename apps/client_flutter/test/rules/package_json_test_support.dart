// 合成资料包 JSON 的共享辅助（既有写法，`import_rule_diagnostics_test.dart` 顶部
// 的两个函数原样移到这里：任务 11 的导入来源测试用同一份，不再抄第二份）。
//
// 追加的两个可选参数只扩展构造能力，不改既有语义：
// - `packageJson(priority:)` 放进包级 JSON；
// - `classEntry(classRules:)` 塞进 `structured['classRules']`（`structured` 缺省时新建）。
import 'dart:convert';

/// 构造一个单 class 条目的包文档；`structured` 缺省即"未声明 classRules"。
String packageJson({
  required Map<String, Object?> entry,
  num formatVersion = 3,
  String id = 'diag-pack',
  String name = 'Diag pack',
  Object? globalAbilities,
  Object? globalSkills,
  Object? priority,
}) => jsonEncode({
  'formatVersion': formatVersion,
  'id': id,
  'name': name,
  'version': '1.0.0',
  'locale': 'zh-CN',
  'system': 'dnd5e-2024',
  'entryCount': 1,
  'priority': ?priority,
  'abilities': ?globalAbilities,
  'skills': ?globalSkills,
  'entries': [entry],
});

Map<String, Object?> classEntry({
  String slug = 'homebrew-sage',
  Map<String, Object?>? structured,
  Map<String, Object?>? classRules,
  Map<String, Object?>? rules,
  // 条目 id 前缀必须与包 id 一致（导入器按 `$packageId:` 校验），否则报告会多一条
  // id 前缀 error。默认值保持既有测试的 `diag-pack`。
  String packageId = 'diag-pack',
}) => {
  'id': '$packageId:class/$slug',
  'type': 'class',
  'slug': slug,
  'name': 'Diag class',
  'body': <Object?>[],
  'revision': 1,
  'structured': ?(classRules == null
      ? structured
      : <String, Object?>{...?structured, 'classRules': classRules}),
  'rules': ?rules,
};
