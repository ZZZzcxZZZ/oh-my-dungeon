// 内置规则档案的读取入口（契约 §3.6 解析链的起点、§4.4 失败处理）。
//
// 档案是**发布资产**，不是用户数据：读取或解析失败都是不可恢复的装配错误，
// 因此这里 fail-fast 抛 `StateError`，由启动路径决定如何呈现（当前是直接崩，
// 便于在 CI 与本地立刻暴露，而不是悄悄降级成"没有规则的规则工具"）。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/rule_profile.dart';
import '../domain/rule_profile_resolver.dart';
import '../domain/rule_values.dart';

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
    final result = RuleProfileResolver.resolveBuiltin(_normalizeArchive(raw));
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

  /// 把 §3.1 的**档案写法**无损展开成解析器认得的 `Table<{环阶:数量}>` 写法
  /// （即 §3.3 解析链里的 `expand(archetype)`）。
  ///
  /// 档案把原型的法术位写成"每级计数数组"，例如 `full-caster.slots[3] = [4,2]`
  /// 表示 3 级时 1 环 4 个、2 环 2 个；`pact` 的行只写计数，环阶由同级的
  /// `slotLevel[L]` 给出（5 级邪术师 = `[2]` + `slotLevel[5] = 3` → `{"3": 2}`，
  /// 与 §3.3 要求的 `{"<环阶>": count}` 及旧 `pactSlotMaximums` 形状一致）。
  /// 解析器的 `SlotTable.tryParse` 只认 `{环阶:数量}` 映射，因此在这一层展开。
  ///
  /// **只做形态转换，不做兜底**：数值非法、行形状与原型不符时原样交回解析器，
  /// 由它按 §4.4 报 `invalidTable` 并让 `profile == null`——绝不产出"看起来
  /// 合理"的假表。对已经是 `{环阶:数量}` 写法的档案是恒等变换（幂等）。
  static Map<String, Object?> _normalizeArchive(Map<String, Object?> raw) {
    final progressions = raw['progressions'];
    if (progressions is! Map) return raw; // 类型错误交给解析器报 invalidTable
    return {
      ...raw,
      'progressions': {
        for (final entry in progressions.entries)
          '${entry.key}': _normalizeProgression(entry.value),
      },
    };
  }

  static Object? _normalizeProgression(Object? raw) {
    if (raw is! Map) return raw; // 类型错误交给解析器报 invalidTable
    final progression = Map<String, Object?>.from(raw);
    final rows = progression['slots'];
    if (rows is! List) return progression;
    // 已是 `{环阶:数量}` 写法（含空表 `{}`）→ 不碰。
    if (rows.any((row) => row is! List)) return progression;
    // `slotLevel` 只有 pact 原型会写（§3.3），它的存在即"行内是单一环阶的计数"。
    final slotLevels = IntTable.tryParse(progression['slotLevel']);
    final expanded = <Object?>[
      for (var index = 0; index < rows.length; index++)
        _expandSlotRow(rows[index] as List, index + 1, slotLevels),
    ];
    progression['slots'] = expanded;
    return progression;
  }

  /// 展开一行计数数组；任何非法形状一律原样返回（让解析器报错，不静默猜测）。
  static Object? _expandSlotRow(List<Object?> row, int level, IntTable? slots) {
    if (slots != null) {
      // pact：行内只有一个计数，环阶取同级 `slotLevel`。
      if (row.length != 1) return row;
      final slotLevel = slots.at(level);
      final count = _slotCount(row.single);
      if (slotLevel == null ||
          slotLevel < 1 ||
          slotLevel > 9 ||
          count == null) {
        return row;
      }
      return <String, Object?>{'$slotLevel': count};
    }
    // 其余原型：计数数组的下标 +1 就是环阶（`[4,2]` → 1 环 4、2 环 2）。
    // 空行是"该等级没有法术位"的占位（如 third-caster 的 1–2 级），展开成显式空表。
    if (row.isEmpty) return <String, Object?>{};
    final expanded = <String, Object?>{};
    for (var index = 0; index < row.length; index++) {
      final count = _slotCount(row[index]);
      if (count == null || index + 1 > 9) return row;
      expanded['${index + 1}'] = count;
    }
    return expanded;
  }

  /// 与 `SlotTable` 同一口径：接受非负数字，其余判非法。
  static int? _slotCount(Object? raw) {
    if (raw is! num) return null;
    final count = raw.toInt();
    return count < 0 ? null : count;
  }
}
