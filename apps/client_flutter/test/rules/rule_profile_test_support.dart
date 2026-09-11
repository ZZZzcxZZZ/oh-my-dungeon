// 规则档案相关测试的共享辅助：从仓库路径读内置档案。
//
// 走生产同一条 `RuleProfileStore.loadBuiltin`，只把资产读取换成 `File`：
// `flutter test` 的工作目录是包根，而 `rootBundle` 需要 widget binding，
// 纯 Dart 测试里不可用。
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/rules/data/rule_profile_store.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';

/// 从仓库路径读取并解析内置档案。
Future<RuleProfile> loadBuiltinProfileForTest() => RuleProfileStore.loadBuiltin(
  readAsset: (path) async =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
);
