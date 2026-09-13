// S3 决策 D1 / D4 / D6：优先级排序与 `replace` 截断的**唯一**实现。
import 'class_rule_set.dart';
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
  /// [effective] 是"排序 + 截断"的完整入口；本方法只在调用方需要**先做排序后的
  /// 调整再截断**时使用（解析器要先应用用户 pin，再追加内置档案统一截断）。
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
  static List<RuleOverrideDeclaration> effective(
    Iterable<RuleOverrideDeclaration> declarations, {
    String? characterEntryId,
  }) => truncate(
    ordered(declarations, characterEntryId: characterEntryId),
  );
}
