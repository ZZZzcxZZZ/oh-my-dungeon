// 内置规则档案的读取入口（契约 §3.6 解析链的起点、§4.4 失败处理）。
//
// 档案是**发布资产**，不是用户数据：读取或解析失败都是不可恢复的装配错误，
// 因此这里 fail-fast 抛 `StateError`，由启动路径决定如何呈现（当前是直接崩，
// 便于在 CI 与本地立刻暴露，而不是悄悄降级成"没有规则的规则工具"）。
//
// 本层只做三件事：读资产 → 调 `RuleProfileResolver.resolveBuiltin` → 把 error
// 包装成 `StateError`。**不含任何形状判断或展开逻辑**：原型 `slots` 的模板压缩
// 编码（§3.1）只有一个展开点，在解析器里。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/rule_profile.dart';
import '../domain/rule_profile_resolver.dart';

abstract final class RuleProfileStore {
  /// 内置档案的资产路径（`pubspec.yaml` 已登记）。
  static const assetPath = 'assets/rules/dnd5e-2024.rules.json';

  /// 读内置档案并解析。`readAsset` 可注入：测试用它读仓库文件，避开
  /// `rootBundle` 对 widget binding 的依赖。
  static Future<RuleProfile> loadBuiltin({
    Future<Map<String, Object?>> Function(String path)? readAsset,
  }) async {
    final reader = readAsset ?? _readRootBundle;
    final raw = await reader(assetPath);
    final result = RuleProfileResolver.resolveBuiltin(raw);
    final profile = result.profile;
    if (profile == null) {
      throw StateError('内置规则档案非法（$assetPath）：\n${result.errors.join('\n')}');
    }
    return profile;
  }

  static Future<Map<String, Object?>> _readRootBundle(String path) async {
    final text = await rootBundle.loadString(path);
    return Map<String, Object?>.from(jsonDecode(text) as Map);
  }
}
