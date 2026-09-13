// S3 决策 D1 / D4 / D6：优先级排序、`replace` 截断与冲突表排序的**唯一**实现。
import 'package:meta/meta.dart';

import 'class_rule_set.dart';
import 'rule_override_conflict.dart';
import 'rule_override_declaration.dart';

/// 优先级排序与 `replace` 截断的**唯一**实现（契约 S3）。
///
/// 顺序（从高到低）：
/// 1. `tier` 降序（内置档案 tier 0 永远最后）；
/// 2. 同 tier：`replace` 先于 `patch`（[ClassMergeMode] 的 `index` **降序**）。
///    `replace` 必须最先落，才能真的独占（D4）；否则同 tier 的 `patch` 会先消费
///    掉列，`replace` 的截断就截不到东西；
/// 3. 同 tier 同 mode：[characterEntryId] 命中的那条优先（角色自己的职业条目）；
/// 4. 其余同 tier：`originId` 升序。
///
/// 第 4 条就是 D6 的**确定性回退**：同 tier 多来源抢同一列时，`originId` 升序的
/// **首位**胜出（`originId` 的前缀就是 packageId，同一对齐键下后缀相同 ⇒ 等价于
/// 按包 id 字典序取**最小者**；`_pickColumn` 取首个声明者），因此同样输入永远得到
/// 同样结果，与 Map 迭代序无关。
abstract final class RuleOverrideOrder {
  static List<RuleOverrideDeclaration> ordered(
    Iterable<RuleOverrideDeclaration> declarations, {
    String? characterEntryId,
  }) {
    final sorted = [...declarations]
      ..sort((a, b) {
        final byTier = b.tier.compareTo(a.tier);
        if (byTier != 0) return byTier;
        final byMode = b.rules.mode.index.compareTo(a.rules.mode.index);
        if (byMode != 0) return byMode;
        if (characterEntryId != null) {
          final aOwn = a.entryId == characterEntryId ? 0 : 1;
          final bOwn = b.entryId == characterEntryId ? 0 : 1;
          if (aOwn != bOwn) return aOwn - bOwn;
        }
        return a.originId.compareTo(b.originId);
      });
    return List<RuleOverrideDeclaration>.unmodifiable(sorted);
  }

  /// `replace` 截断（D4）：在**已排序**的链上，第一条 `mode: replace` 之后的
  /// 声明全部丢弃——更低 tier（含内置档案）不再提供任何列 / 等级。
  ///
  /// 调用方**必须**先把内置档案合入链、并让用户的 pin 逐列生效，再做**一次**
  /// 统一截断：[effective] 只是"排序 + 截断"的完整语义入口，不是解析器的调用路径。
  /// pin 不是"截断前重排整条链"——它按列在截断**之后**生效（被同 tier `replace`
  /// 丢弃的声明因此要作为 pin 的候选保留在 `_PinContext.fallbacks` 里）。
  /// 截断逻辑本身仍只有这一处实现。
  static List<RuleOverrideDeclaration> truncate(
    Iterable<RuleOverrideDeclaration> orderedDeclarations,
  ) {
    final result = <RuleOverrideDeclaration>[];
    for (final declaration in orderedDeclarations) {
      result.add(declaration);
      if (declaration.rules.mode == ClassMergeMode.replace) break;
    }
    return List<RuleOverrideDeclaration>.unmodifiable(result);
  }

  /// `replace` 截断（D4）：排序后取 [truncate]。
  ///
  /// **保留理由**：lib 内的合并链不用它（解析器要先合入内置档案再统一 [truncate]，
  /// 用户的 pin 在截断**之后**按列生效），但"排序 + 截断"是 D4 的完整语义，
  /// `truncate` 单独无法表达"排在最前的 replace 独占"，因此保留这个纯函数入口，
  /// 仅供测试直接验证 D4（[visibleForTesting]）。
  /// 生产路径不得改走它——内置档案必须在截断前合入，否则 replace 截不到档案。
  @visibleForTesting
  static List<RuleOverrideDeclaration> effective(
    Iterable<RuleOverrideDeclaration> declarations, {
    String? characterEntryId,
  }) => truncate(ordered(declarations, characterEntryId: characterEntryId));

  /// 冲突来源 id 的展示顺序（**唯一排序点**）：按 originId 升序，去重。
  ///
  /// 冲突的 `originIds` 因此恒升序——同一个冲突每次派生写出的 JSON 完全一致，
  /// `effectiveOriginId`（排序首位胜出者）也能直接与它对照阅读。
  static List<String> orderedOriginIds(Iterable<String> originIds) {
    final sorted = originIds.toSet().toList()..sort();
    return List<String>.unmodifiable(sorted);
  }

  /// 某个来源是否被用户的"关闭覆盖"关掉（决策 D6）：**三向匹配**，与 originId
  /// 传的是条目 id 还是包 id 无关。
  ///
  /// - `originId` 精确命中禁用集合；
  /// - `originId` 所属的包 id 命中禁用集合（关掉整个包）；
  /// - 禁用集合里某个**条目 id** 的包 id 等于 `originId`（`originId` 本身是包 id）。
  ///
  /// **唯一实现**：解析器（剔除来源、pin 豁免 disabled）与
  /// `CharacterRuleOverrides.isDisabled` 都调这里，绝不各自内联一份两向 / 三向匹配
  /// ——`disabled={'errata:class/druid'}` 时用包 id `'errata'` 查询必须同样为 true，
  /// 否则同一条用户选择会在两处得到不同解释。
  static bool isDisabled(Set<String> disabledOriginIds, String originId) {
    if (disabledOriginIds.contains(originId)) return true;
    final packageId = RuleOverrideDeclaration.packageIdOf(originId);
    if (packageId.isNotEmpty && disabledOriginIds.contains(packageId)) {
      return true;
    }
    return disabledOriginIds.any(
      (value) => RuleOverrideDeclaration.packageIdOf(value) == originId,
    );
  }

  /// 冲突表的去重 + 排序（**唯一排序点**，任务 13 门禁要求解析器内没有 `.sort(`）：
  /// 同一列只保留首条（先到者优先），整体按字段路径升序。
  static List<RuleOverrideConflict> orderedConflicts(
    Iterable<RuleOverrideConflict> conflicts,
  ) {
    final byField = <String, RuleOverrideConflict>{};
    for (final conflict in conflicts) {
      byField.putIfAbsent(conflict.field, () => conflict);
    }
    final fields = byField.keys.toList()..sort();
    return List<RuleOverrideConflict>.unmodifiable(<RuleOverrideConflict>[
      for (final field in fields) byField[field]!,
    ]);
  }
}
