import '../../content/domain/content_entry.dart';
import 'character_build.dart';
import 'character_rule_definition.dart';
import 'rule_choice_quota.dart';
import 'rule_choice_semantics.dart';

class ResolvedRuleGrant {
  const ResolvedRuleGrant({
    required this.id,
    required this.kind,
    required this.label,
    required this.sourceEntryId,
    required this.sourceEntryName,
    required this.sourceLevel,
    this.target,
    this.entryId,
    this.value,
    this.formula,
    this.data = const <String, Object?>{},
  });

  final String id;
  final RuleGrantKind kind;
  final String label;
  final String sourceEntryId;
  final String sourceEntryName;
  final int? sourceLevel;
  final String? target;
  final String? entryId;
  final num? value;
  final String? formula;
  final Map<String, Object?> data;
}

/// 一个选择进入 `pendingChoices` 的**原因**（契约 §3.10.3-5、§3.10.3-7）。
///
/// 这是"为什么没生效"的**唯一枚举**：引擎只在这里给出原因，UI 据此显示可操作
/// 文案。任一原因都**不**静默丢弃选中值：`PendingRuleChoice.selected` /
/// `invalidSelected` 仍然带着原值。
enum RuleChoicePendingReason {
  /// 已选数量不足 `minimum`。
  belowMinimum,

  /// 已选数量超出该选择**自身**（或有效）的 `maximum`。
  aboveMaximum,

  /// 选中值不在候选集里（内联选项与条目候选都算候选）。
  notACandidate,

  /// `repeatable: false` 却对同一选项选了多次。
  notRepeatable,

  /// `requires` 不满足（能力门槛或引用的选择未满足）。
  requiresUnsatisfied,

  /// 超出**已声明**池额度的剩余可用量（决策 D8：先声明先占）。
  poolExceeded,
}

class PendingRuleChoice {
  const PendingRuleChoice({
    required this.key,
    required this.choiceId,
    required this.label,
    required this.optionType,
    required this.minimum,
    required this.maximum,
    required this.selected,
    required this.sourceEntryId,
    required this.sourceLevel,
    this.invalidSelected = const <String>[],
    this.reason,
  });

  final String key;
  final String choiceId;
  final String label;
  final String optionType;
  final int minimum;
  final int maximum;
  final List<String> selected;
  final String sourceEntryId;
  final int? sourceLevel;
  final List<String> invalidSelected;

  /// 进入 pending 的原因（[RuleChoicePendingReason]）。计划任务 3 起由引擎给出；
  /// 旧调用方（程序化构造、旧存档读取方）不传时为 `null`——"没给原因"与"某个具体
  /// 原因"必须可区分，不得用某个枚举值冒充缺省。
  final RuleChoicePendingReason? reason;

  int get remaining => (minimum - selected.length).clamp(0, minimum);
}

class ActiveRuleChoice {
  const ActiveRuleChoice({
    required this.key,
    required this.definition,
    required this.selected,
    required this.invalidSelected,
    required this.sourceEntryId,
    required this.sourceEntryName,
    required this.sourceLevel,
    this.repeatable = false,
    this.requiresSatisfied = true,
    this.group,
    this.help,
    this.pool,
    this.poolCap,
  });

  final String key;
  final RuleChoiceDefinition definition;
  final List<String> selected;
  final List<String> invalidSelected;
  final String sourceEntryId;
  final String sourceEntryName;
  final int? sourceLevel;

  /// 该选择是否允许同一选项重复选取（契约 §3.10.2）。
  final bool repeatable;

  /// `requires` 是否满足（契约 §3.10.3-5）。不满足时该选择**不生效**：
  /// 引擎不展开它的内联 grants、不把条目候选排进规则队列、不占 `countsToward`
  /// 额度；但选中值仍保留在 [selected] / [invalidSelected] 里（不静默丢弃），
  /// UI 据此显示"已选但未生效"及其原因。
  final bool requiresSatisfied;

  /// 选择面板的分组标题 / 帮助文案（契约 §3.10.2；纯呈现）。
  final String? group;
  final String? help;

  /// 计入的数量池与本次可用上限（契约 §3.10.2；`null` = 不占池）。
  final String? pool;
  final int? poolCap;

  bool get isValid =>
      invalidSelected.isEmpty &&
      selected.length >= definition.minimum &&
      selected.length <= definition.maximum &&
      requiresSatisfied;
}

class CharacterGrantLedger {
  const CharacterGrantLedger({
    required this.grants,
    required this.pendingChoices,
    required this.missingEntryIds,
    required this.resolvedChoiceEntryIds,
    required this.resolvedChoices,
    required this.activeChoices,
  });

  final List<ResolvedRuleGrant> grants;
  final List<PendingRuleChoice> pendingChoices;
  final List<String> missingEntryIds;
  final List<String> resolvedChoiceEntryIds;
  final Map<String, List<String>> resolvedChoices;
  final List<ActiveRuleChoice> activeChoices;

  Iterable<ResolvedRuleGrant> grantsOfKind(RuleGrantKind kind) {
    return grants.where((grant) => grant.kind == kind);
  }
}

/// 一条"生效单元"的唯一键：`<条目 id>#<定义 id>`。
///
/// `progression[].levels` 声明的是"**同一批效果在多个等级重复生效**"（契约 §3.5）：
/// `levels: [4, 8, 12, 16]` 的属性提升到 16 级要累计 +4，而不是只 +1。因此每个已达
/// 等级都是**独立**的生效单元，键必须带上 [sourceLevel]；只有步骤级之外的条目级定义
/// （`rules.grants` / `rules.choices`，与等级无关）才不带等级。
///
/// 这是键格式的**唯一**实现点：引擎与编辑器（升级预览 diff、选择列表）都必须经过它，
/// 否则两侧对"本等级新增了什么"的判断会不一致。
String ruleUnitKey(String entryId, String definitionId, int? sourceLevel) {
  return sourceLevel == null
      ? '$entryId#$definitionId'
      : '$entryId#$definitionId#$sourceLevel';
}

/// 内联选项授予的**生效单元键**：`<选择键>#<选项 id>#<第几次>#<第几条 grant>`。
///
/// `repeatable: true` 时同一选项的每一次选取都是独立生效单元（选两次"力量 +1"
/// 要累计 +2），因此第几次（从 0 起）必须进键；非 repeatable 时下标恒为 0。
/// 一个内联选项还可以声明**多条** `grants`（`options[].grants` 是数组），它们同属
/// 一次选取，只用"第几次"会让第二条起互相覆盖、静默丢数据；因此把 **grants 的
/// 声明下标**也并入键。用下标而**不是** `grant.id`：`grant.id` 没有唯一性校验，
/// 同一个 id 可以在一个选项里出现两次（两条都得落账）。
///
/// 内联选项的 grants 由 `RuleChoiceSemantics.grantsForSelection`（**唯一实现点**）
/// 展开，本函数只负责给出落账用的键。
///
/// 这是该键格式的**唯一实现点**：内联 grants 的 `resolvedGrants` 落库与后续升级
/// diff 都必须经过它。**当前接线状态**：仅 `CharacterRulesEngine._recordInlineGrants`
/// 调用（计划任务 3 起，键的拼装只允许那一处）；编辑器 diff / 属性逆运算的接线在
/// 任务 6+，它们此刻仍在用 `ruleUnitKey` 比对"条目级"生效单元。
String ruleChoiceGrantKey(
  String choiceKey,
  String optionId,
  int occurrence,
  int grantIndex,
) => '$choiceKey#$optionId#$occurrence#$grantIndex';

/// `kind: action` 的**动作身份**键：`<条目 id>#<定义 id>`，**不带等级**。
///
/// 动作没有随等级变化的语义（同一个动作不会因为步骤覆盖 3 个等级就变成 3 个动作），
/// 而多等级步骤（§3.5）会把同一份动作定义逐级展开成 N 个生效单元。需要"每个动作只
/// 出现一次"的消费方（`data['actions']`、编辑器「自动获得」预览）都必须经过这里，
/// 否则两处会各自拼键、去重口径不一致。
String ruleActionKey(String entryId, String definitionId) =>
    '$entryId#$definitionId';

class CharacterRulesEngine {
  const CharacterRulesEngine({required this.entries});

  final Map<String, ContentEntry> entries;

  /// [poolLimits] **必填**：默认值会让"漏传"静默变成"不限"，而额度只有
  /// [RuleChoiceQuota.limitsFor] 一处来源，调用方必须显式给出（无池就传空表）。
  CharacterGrantLedger evaluate(
    CharacterBuild build, {
    required Map<String, int> poolLimits,
  }) {
    final grants = <String, ResolvedRuleGrant>{};
    final pendingChoices = <PendingRuleChoice>[];
    final missingEntryIds = <String>[];
    final resolvedChoiceEntryIds = <String>{};
    final resolvedChoices = <String, List<String>>{};
    final activeChoices = <ActiveRuleChoice>[];
    // `countsToward` 池是**角色级**共享的：池占用必须在整次求值内跨条目、跨等级
    // 累加（决策 D8 的"先声明先占"要求确定遍历顺序，本 map 就是那个顺序的状态）。
    // 顺序语义（FCFS，D8）：**条目内**按 `rules.choices` / 各步骤 `choices` 的
    // **声明顺序**；**跨条目**按 `build.selections` 的**迭代顺序**（队列按它播种，
    // 新发现的条目追加在后）。`build.selections` 随存档持久化，因此同一存档的
    // 争用结果可复现。
    final poolUsage = <String, int>{};
    final queue = build.selections.values.toList(growable: true);
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final entryId = queue.removeAt(0);
      if (!visited.add(entryId)) continue;
      final entry = entries[entryId];
      if (entry == null) {
        missingEntryIds.add(entryId);
        continue;
      }
      final rules = entry.rules;
      if (rules == null) continue;

      _resolveEntryChoices(
        build: build,
        entry: entry,
        rules: rules,
        pending: pendingChoices,
        queue: queue,
        resolvedChoiceEntryIds: resolvedChoiceEntryIds,
        resolvedChoices: resolvedChoices,
        activeChoices: activeChoices,
        target: grants,
        poolLimits: poolLimits,
        poolUsage: poolUsage,
      );

      for (final step in rules.progression) {
        // 一个步骤可覆盖多个等级（`levels`）：按每个已达等级分别展开，
        // `sourceLevel` 因此始终是"这一步在哪个等级生效"的单值。
        for (final stepLevel in step.levels) {
          if (stepLevel > build.level) continue;
          _resolveGrants(
            entry: entry,
            sourceLevel: stepLevel,
            definitions: step.grants,
            target: grants,
          );
          _resolveChoices(
            build: build,
            entry: entry,
            sourceLevel: stepLevel,
            definitions: step.choices,
            pending: pendingChoices,
            queue: queue,
            resolvedChoiceEntryIds: resolvedChoiceEntryIds,
            resolvedChoices: resolvedChoices,
            activeChoices: activeChoices,
            target: grants,
            poolLimits: poolLimits,
            poolUsage: poolUsage,
          );
        }
      }
    }

    return CharacterGrantLedger(
      grants: grants.values.toList(growable: false),
      pendingChoices: pendingChoices,
      missingEntryIds: missingEntryIds,
      resolvedChoiceEntryIds: resolvedChoiceEntryIds.toList(growable: false),
      resolvedChoices: resolvedChoices,
      activeChoices: activeChoices,
    );
  }

  /// 条目级选择（`rules.choices`）与条目级授予（`rules.grants`）。
  ///
  /// 条目级 `grants` 与 `choices` 的**相对顺序**沿用旧引擎的"先授予、后选择"
  /// （`evaluate` 里两个调用点的顺序不变），选择之间则严格按声明顺序处理。
  void _resolveEntryChoices({
    required CharacterBuild build,
    required ContentEntry entry,
    required CharacterRuleDefinition rules,
    required List<PendingRuleChoice> pending,
    required List<String> queue,
    required Set<String> resolvedChoiceEntryIds,
    required Map<String, List<String>> resolvedChoices,
    required List<ActiveRuleChoice> activeChoices,
    required Map<String, ResolvedRuleGrant> target,
    required Map<String, int> poolLimits,
    required Map<String, int> poolUsage,
  }) {
    _resolveGrants(
      entry: entry,
      sourceLevel: null,
      definitions: rules.grants,
      target: target,
    );
    _resolveChoices(
      build: build,
      entry: entry,
      sourceLevel: null,
      definitions: rules.choices,
      pending: pending,
      queue: queue,
      resolvedChoiceEntryIds: resolvedChoiceEntryIds,
      resolvedChoices: resolvedChoices,
      activeChoices: activeChoices,
      target: target,
      poolLimits: poolLimits,
      poolUsage: poolUsage,
    );
  }

  void _resolveGrants({
    required ContentEntry entry,
    required int? sourceLevel,
    required List<RuleGrantDefinition> definitions,
    required Map<String, ResolvedRuleGrant> target,
  }) {
    for (final definition in definitions) {
      // 键带生效等级：同一份定义在多个已达等级各生效一次（§3.5），
      // 后一个等级不能覆盖前一个等级的结算结果。
      final key = ruleUnitKey(entry.id, definition.id, sourceLevel);
      target[key] = ResolvedRuleGrant(
        id: definition.id,
        kind: definition.kind,
        label: definition.label,
        sourceEntryId: entry.id,
        sourceEntryName: entry.name,
        sourceLevel: sourceLevel,
        target: definition.target,
        entryId: definition.entryId,
        value: definition.value,
        formula: definition.formula,
        data: definition.data,
      );
    }
  }

  void _resolveChoices({
    required CharacterBuild build,
    required ContentEntry entry,
    required int? sourceLevel,
    required List<RuleChoiceDefinition> definitions,
    required List<PendingRuleChoice> pending,
    required List<String> queue,
    required Set<String> resolvedChoiceEntryIds,
    required Map<String, List<String>> resolvedChoices,
    required List<ActiveRuleChoice> activeChoices,
    required Map<String, ResolvedRuleGrant> target,
    required Map<String, int> poolLimits,
    required Map<String, int> poolUsage,
  }) {
    for (final definition in definitions) {
      // 选择与授予共用同一种多等级语义（§3.5）：每个已达等级都是一次独立的
      // 选择实例（16 级的 4 次属性提升各选一次），键同样带上生效等级。
      final key = ruleUnitKey(entry.id, definition.id, sourceLevel);
      // 兼容等级限定键之前写入的旧存档：只有不带等级的键时沿用它。
      final requested =
          build.choices[key] ??
          (sourceLevel == null
              ? const <String>[]
              : build.choices[ruleUnitKey(entry.id, definition.id, null)] ??
                    const <String>[]);
      // `countsToward` 的额度只有 `RuleChoiceQuota.effectiveMaximum` 一处
      // （唯一实现点）：与 `definition.maximum` 取小、池占满取 0（决策 D8：
      // 先声明先占——`poolUsage` 由调用方按确定遍历顺序累加）。
      final countsToward = definition.countsToward;
      final poolCap = countsToward == null
          ? null
          : RuleChoiceQuota.effectiveMaximum(
              countsToward: countsToward,
              maximum: definition.maximum,
              poolLimits: poolLimits,
              usedByOthers: poolUsage[countsToward] ?? 0,
            );
      // 选中值规范化只有 `RuleChoiceSemantics.normalizeSelection` 一处
      // （唯一实现点）：候选成员过滤、`repeatable`、`maximum` 超额都在那里判。
      final normalized = RuleChoiceSemantics.normalizeSelection(
        definition,
        requested,
        entries: entries,
        sourceEntryId: entry.id,
        effectiveMaximum: poolCap ?? definition.maximum,
      );
      final selection = normalized.selected;
      // `requires` 判定只有 `RuleChoiceSemantics.requiresSatisfied` 一处（唯一实现
      // 点）：能力门槛读 `build.abilities`（**基础属性**，决策 D4），选择引用读
      // `build.choices` 的选中值。不满足时选中值**不丢弃**（§3.10.3-5），但该选择
      // **真的不生效**：不展开内联 grants、不把条目候选排进队列、不占
      // `countsToward` 额度——只保留在 `resolvedChoices` / pending 供 UI 显示
      // "已选但未生效"。
      final requiresSatisfied = RuleChoiceSemantics.requiresSatisfied(
        definition.requires,
        sourceEntryId: entry.id,
        selectedByKey: build.choices,
        abilities: build.abilities,
        entries: entries,
      );
      // 内联选项的 grants 进同一本账：展开只有
      // `RuleChoiceSemantics.grantsForSelection` 一处（唯一实现点），键的拼装只有
      // `ruleChoiceGrantKey` 一处（在 `_recordInlineGrants` 内）。前置不满足 =
      // 不生效，直接跳过。
      if (requiresSatisfied) {
        _recordInlineGrants(
          definition: definition,
          choiceKey: key,
          selection: selection,
          entry: entry,
          sourceLevel: sourceLevel,
          target: target,
        );
      }
      activeChoices.add(
        ActiveRuleChoice(
          key: key,
          definition: definition,
          selected: selection,
          invalidSelected: normalized.invalidSelected,
          sourceEntryId: entry.id,
          sourceEntryName: entry.name,
          sourceLevel: sourceLevel,
          repeatable: definition.repeatable,
          requiresSatisfied: requiresSatisfied,
          group: definition.group,
          help: definition.help,
          pool: countsToward,
          poolCap: poolCap,
        ),
      );
      if (!requiresSatisfied ||
          selection.length < definition.minimum ||
          normalized.invalidSelected.isNotEmpty) {
        pending.add(
          PendingRuleChoice(
            key: key,
            choiceId: definition.id,
            label: definition.label,
            optionType: definition.optionType,
            minimum: definition.minimum,
            maximum: definition.maximum,
            selected: selection,
            sourceEntryId: entry.id,
            sourceLevel: sourceLevel,
            invalidSelected: normalized.invalidSelected,
            reason: _pendingReason(
              requiresSatisfied: requiresSatisfied,
              selected: selection,
              violations: normalized.violations,
              minimum: definition.minimum,
              countsToward: countsToward,
              poolLimits: poolLimits,
            ),
          ),
        );
      }
      // 本选择占用的额度累加进池：后续选择按声明顺序看到更小的剩余额度。
      // 前置不满足的选择**不占额度**（真的不生效）。
      if (requiresSatisfied && countsToward != null) {
        poolUsage[countsToward] =
            (poolUsage[countsToward] ?? 0) + selection.length;
      }
      resolvedChoices[key] = selection;
      // 只把**条目**候选排进队列：内联 id 不是条目，入队只会污染 missingEntryIds。
      // `resolvedChoiceEntryIds`（内容引用）同样只收条目 id。前置不满足时
      // 整个跳过：该选择引用的条目**也不授予**它的 grants / progression。
      if (requiresSatisfied) {
        final entryBacked = selection
            .where(entries.containsKey)
            .toList(growable: false);
        resolvedChoiceEntryIds.addAll(entryBacked);
        queue.addAll(entryBacked);
      }
    }
  }

  /// 内联选项 grants 的展开与落账（`_resolveChoices` 的唯一抽取点）。
  ///
  /// 每次出现（第几次选取）与每条 grant（声明下标）合起来才是唯一生效单元，
  /// 键的拼装只允许 [ruleChoiceGrantKey] 一处、且只在这里调用。
  void _recordInlineGrants({
    required RuleChoiceDefinition definition,
    required String choiceKey,
    required List<String> selection,
    required ContentEntry entry,
    required int? sourceLevel,
    required Map<String, ResolvedRuleGrant> target,
  }) {
    final occurrences = <String, int>{};
    for (final optionId in selection) {
      final occurrence = occurrences.update(
        optionId,
        (count) => count + 1,
        ifAbsent: () => 0,
      );
      final optionGrants = RuleChoiceSemantics.grantsForSelection(
        definition,
        <String>[optionId],
        entries: entries,
        sourceEntryId: entry.id,
      );
      for (var grantIndex = 0; grantIndex < optionGrants.length; grantIndex++) {
        final grant = optionGrants[grantIndex];
        target[ruleChoiceGrantKey(choiceKey, optionId, occurrence, grantIndex)] =
            ResolvedRuleGrant(
              id: grant.id,
              kind: grant.kind,
              label: grant.label,
              sourceEntryId: entry.id,
              sourceEntryName: entry.name,
              sourceLevel: sourceLevel,
              target: grant.target,
              entryId: grant.entryId,
              value: grant.value,
              formula: grant.formula,
              data: grant.data,
            );
      }
    }
  }

  /// `pending` 的原因，按计划任务 3/5 的优先级：
  /// `requiresUnsatisfied` > `notACandidate` > `notRepeatable` > `poolExceeded` /
  /// `aboveMaximum` > `belowMinimum`。
  ///
  /// `aboveMaximum` 与 `poolExceeded` 的分工：该选择**声明了** `countsToward`
  /// **且该池声明了额度**（`poolLimits` 含这个池名）时才记 `poolExceeded`——这个
  /// 超额是"计入数量池"带来的；否则记 `aboveMaximum`。池**没有声明上限**（决策 D3：
  /// 例如 `spellbook`）记 `aboveMaximum`：`poolCap` 此时就是自身 `maximum`，
  /// 超额与"入池"无关，归因不能冒充池额度。"有没有上限"由
  /// [RuleChoiceQuota.effectiveMaximum] 决定，`ActiveRuleChoice.poolCap` 会显示
  /// 有效上限，两条信息互不冒充。
  ///
  /// 只有"确实进了 pending"的选择才调它：选中数够、无违规时返回 null 表示"原因
  /// 不在此枚举"，绝不拿 [RuleChoicePendingReason.belowMinimum] 冒充。
  static RuleChoicePendingReason? _pendingReason({
    required bool requiresSatisfied,
    required List<String> selected,
    required Set<RuleChoiceViolation> violations,
    required int minimum,
    required String? countsToward,
    required Map<String, int> poolLimits,
  }) {
    if (!requiresSatisfied) return RuleChoicePendingReason.requiresUnsatisfied;
    if (violations.contains(RuleChoiceViolation.notACandidate)) {
      return RuleChoicePendingReason.notACandidate;
    }
    if (violations.contains(RuleChoiceViolation.notRepeatable)) {
      return RuleChoicePendingReason.notRepeatable;
    }
    if (violations.contains(RuleChoiceViolation.aboveMaximum)) {
      // 只有**声明了额度**的池才让超额归因于池（无上限池的超额是自己 maximum）。
      final countsTowardLimitedPool =
          countsToward != null && poolLimits.containsKey(countsToward);
      return countsTowardLimitedPool
          ? RuleChoicePendingReason.poolExceeded
          : RuleChoicePendingReason.aboveMaximum;
    }
    if (selected.length < minimum) {
      return RuleChoicePendingReason.belowMinimum;
    }
    return null;
  }
}
