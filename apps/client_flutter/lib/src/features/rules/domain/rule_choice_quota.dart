import 'rule_profile.dart';

/// 声明了 `countsToward` 但**档案没有容量列**的池：无上限（决策 D3）。
///
/// 与 [RuleChoiceQuota.limitsFor] 的键空间**一起**必须覆盖契约的合法池名单
/// （`kCountsTowardPools`，测试锁定）：新增池名时要么在这里显式声明"不限"，要么让
/// [RuleChoiceQuota.limitsFor] 给出数值。不允许出现"加了池名却漏加额度来源、于是
/// 静默落到不限"的第三态。
const kUnlimitedCountsTowardPools = <String>{'spellbook'};

/// `countsToward` 的额度语义（契约 §3.10.2，决策 D3）。
///
/// 池上限的**唯一来源**是 [limitsFor]：`prepared` 与 `known` 共用职业 `prepared`
/// 表，`spellbook` **不出现**（`classRules` 没有法术书容量列，见决策 D1/D3）
/// ——它在 [kUnlimitedCountsTowardPools] 里被显式标注为无限池。本文件只做算术，
/// 不查内容仓库、不读 `Dnd5eRules`：调用方把已解析的 [ResolvedClassRules] 与等级
/// 传进来。
abstract final class RuleChoiceQuota {
  /// 该职业在该等级可用的**池上限表**；未声明（`preparedLimit` 为 null，例如
  /// `mode: "none"` 的非施法者）返回空表。
  ///
  /// 这是"池上限从哪来"的唯一实现点：引擎的 `evaluate(poolLimits:)`、编辑器与
  /// 升级规划器都必须调它，不得各自读 [ResolvedClassRules.preparedLimit] 再拼表。
  static Map<String, int> limitsFor({
    required ResolvedClassRules rules,
    required int level,
  }) {
    final prepared = rules.preparedLimit(level);
    final cantrips = rules.cantripLimit(level);
    return <String, int>{
      if (prepared != null) ...<String, int>{'prepared': prepared, 'known': prepared},
      // 戏法数量来自职业 `cantrips` 列（决策 D8）：列未声明时不进表 → 该池不额
      // 外约束（选择自身的 `maximum` 仍然生效），绝不凭空编造一个数。
      'cantrips': ?cantrips,
    };
  }

  /// 某个选择在池已被占用 [usedByOthers] 之后的**有效上限**：
  /// `maximum` 与池剩余额度取小，剩余为负时取 0（不是负数）。
  ///
  /// - `countsToward == null` → 不占池，只受 `maximum`；
  /// - 未知池名（只可能来自程序化构造绕过解析层）按"不占池"处理：解析层与导入器
  ///   已把非法取值挡在门外，运行期不再制造第二种失败模式。
  static int effectiveMaximum({
    required String? countsToward,
    required int maximum,
    required Map<String, int> poolLimits,
    required int usedByOthers,
  }) {
    if (countsToward == null) return maximum;
    final limit = poolLimits[countsToward];
    if (limit == null) return maximum;
    final remaining = limit - usedByOthers;
    if (remaining <= 0) return 0;
    return remaining < maximum ? remaining : maximum;
  }
}
