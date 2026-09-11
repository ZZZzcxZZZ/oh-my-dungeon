// 测试环境的内置档案装配入口：`flutter test` 会自动加载本文件。
//
// 契约 §4.4：内置档案缺失或非法即 fail-fast。测试环境同理——装配失败就让
// 整个套件整体报错，而不是让每个测试文件各自写 `setUpAll` 去解析档案。
//
// 用 `File` 直接读仓库资产（`flutter test` 的工作目录是包根），不走
// `rootBundle`：纯 Dart 测试没有 widget binding 也能读，`readAsset` 注入
// 因此让整个装配路径在测试里可复现。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/rules/data/rule_profile_store.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await Dnd5eRules.configure(
    await RuleProfileStore.loadBuiltin(readAsset: _readRepoAsset),
  );
  await testMain();
}

Future<Map<String, Object?>> _readRepoAsset(String path) async {
  final text = await File(path).readAsString();
  return Map<String, Object?>.from(jsonDecode(text) as Map);
}
