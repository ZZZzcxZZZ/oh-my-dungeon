import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../content/domain/content_entry.dart';
import '../../../rules/domain/character_rule_definition.dart';
import '../../../rules/domain/rule_choice_semantics.dart';
import '../../domain/dnd5e_rules.dart';

/// 规则选择面板的**唯一渲染组件**（计划任务 6a；契约 §3.10.2）。
///
/// 创建向导、编辑器升级队列、独立升级页三处都必须复用它，不得各自再写一套
/// chip 交互。候选枚举由调用方经 `RuleChoiceSemantics.candidatesFor` 传入
/// （本组件不出现 `entry.type` 过滤，也不自己调 `RuleChoiceResolver`）。
///
/// 呈现约定：
/// - 选择状态是有序 `List<String>`：顺序 = 用户点击顺序 = `build.choices` 落库顺序；
/// - `repeatable` 允许同一 id 出现多次，chip 标签显示 `名称 ×N`，取消只移除**第一次**
///   出现的那次；
/// - `blockedReason != null`（选择级 `requires` 不满足）时**不渲染候选**，只显示
///   原因；已有选中值以"已选但未生效"列出（§3.10.3-5，不静默丢弃）；
/// - 颜色 / 圆角 / 字号只用 `Theme.of(context).colorScheme` / `textTheme` 与既有
///   `Card.outlined` / `FilterChip`（`DESIGN.md` 契约，不新增 token）。
class RuleChoiceSection extends StatelessWidget {
  const RuleChoiceSection({
    required this.definition,
    required this.candidates,
    required this.selected,
    required this.onChanged,
    this.sourceLabel,
    this.blockedReason,
    this.onOpenEntry,
    this.showTitle = true,
    this.requiresContext,
    super.key,
  });

  final RuleChoiceDefinition definition;
  final List<RuleChoiceCandidate> candidates;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? sourceLabel;

  /// 选择级 `requires` 不满足时的原因文案（`null` = 满足）。
  final String? blockedReason;

  /// 条目候选右侧"查看"按钮的回调（`null` = 不显示该按钮）。
  final ValueChanged<ContentEntry>? onOpenEntry;

  /// `false` = 调用方已提供标题（独立升级页的 `_UpgradeSection`）。
  final bool showTitle;

  /// 选项级 `requires`（`options[].requires`，决策 D6）判定所需的上下文；
  /// `null` = 不隐藏任何候选。
  final RuleChoiceRequiresContext? requiresContext;

  @override
  Widget build(BuildContext context) {
    final blocked = blockedReason != null;
    // 候选过滤的唯一实现点是 `visibleRuleChoiceCandidates`（选项级 `requires`）；
    // 选择级 `blockedReason` 不满足时整块候选都不画（值也不生效）。
    final visible = blocked
        ? const <RuleChoiceCandidate>[]
        : visibleRuleChoiceCandidates(candidates, requiresContext);
    // 已选但**选项级** `requires` 不满足的值：候选被隐藏，值却还在草稿里。
    // 不静默丢弃，也不让它冒充"生效"——列出来（决策 D6 / P2-1）。
    final hiddenSelected = <String>[
      for (final id in selected)
        if (!visible.any((candidate) => candidate.id == id)) id,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle) _title(context),
              if (sourceLabel != null) _sourceLine(context),
              if (definition.help != null) _help(context),
              const SizedBox(height: 12),
              if (blocked)
                _blockedNotice(context, selected)
              else
                ..._candidateArea(context, visible, hiddenSelected),
            ],
          ),
        ),
      ),
    );
  }

  /// 标题行：选择 `label` + 完成状态图标（`minimum`–`maximum` 与前置都满足才打勾）。
  Widget _title(BuildContext context) {
    final theme = Theme.of(context);
    final valid =
        blockedReason == null &&
        selected.length >= definition.minimum &&
        selected.length <= definition.maximum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              definition.label,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Icon(
            valid ? Icons.check_circle : Icons.pending_outlined,
            color: valid ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

  /// 来源与数量摘要（`来源条目 · 选择 2-2 项 · 已选 1`）。
  Widget _sourceLine(BuildContext context) {
    return Text(
      '$sourceLabel · 选择 ${definition.minimum}-${definition.maximum} 项'
      ' · 已选 ${selected.length}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  /// `help` 小字（`DESIGN.md` 的次要文字角色，无新 token）。
  Widget _help(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        definition.help!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 选择级 `requires` 不满足：只显示原因 + 已选值清单，不渲染候选。
  Widget _blockedNotice(BuildContext context, List<String> selectedValues) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.block_outlined,
              size: 18,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                blockedReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        if (selectedValues.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '已选但未生效：${_labelsFor(selectedValues, candidates)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// 候选区：空候选给出**区分过的**原因；否则按载体来源分组展示候选。
  List<Widget> _candidateArea(
    BuildContext context,
    List<RuleChoiceCandidate> visible,
    List<String> hiddenSelected,
  ) {
    final theme = Theme.of(context);
    if (visible.isEmpty) {
      return [
        Text(
          // 两种"空候选"必须区分（不误导）：资料库缺料 vs 选项级前置把候选全
          // 隐藏了。判定用 `candidates.isEmpty`——过滤的唯一实现点是
          // `visibleRuleChoiceCandidates`，这里不重新过滤。
          candidates.isEmpty
              ? '资料库中缺少 ${definition.optionType} 选项。'
              : '当前条件下没有可选的 ${definition.optionType} 选项'
                    '（候选的选项级 requires 均未满足）。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ];
    }
    final inline = visible
        .where((candidate) => candidate.isInline)
        .toList(growable: false);
    final entryBacked = visible
        .where((candidate) => !candidate.isInline)
        .toList(growable: false);
    return [
      // §3.10.3-2：内联选项与条目候选**合并展示并分组**。两者语义不同（内联自带
      // grants、条目进规则队列），同名时不再无法分辨；只有一种载体时不加分组小标
      // （避免给单组候选添噪音）。
      if (inline.isNotEmpty)
        ..._candidateGroup(
          context,
          inline,
          caption: entryBacked.isEmpty ? null : '选择自带',
        ),
      if (entryBacked.isNotEmpty)
        ..._candidateGroup(
          context,
          entryBacked,
          caption: inline.isEmpty ? null : '来自资料库',
        ),
      if (hiddenSelected.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          '已选但未生效：${_labelsFor(hiddenSelected, candidates)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    ];
  }

  /// 一组候选（可选分组小标 + chip 流）。
  List<Widget> _candidateGroup(
    BuildContext context,
    List<RuleChoiceCandidate> group, {
    required String? caption,
  }) {
    final theme = Theme.of(context);
    final counts = _countsById(selected);
    return [
      if (caption != null) ...[
        const SizedBox(height: 4),
        Text(
          caption,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final candidate in group)
            _candidateRow(context, candidate, counts),
        ],
      ),
    ];
  }

  /// 单个候选 chip（`repeatable` 时附带"减一次"图标）与可选的"查看"按钮。
  Widget _candidateRow(
    BuildContext context,
    RuleChoiceCandidate candidate,
    Map<String, int> counts,
  ) {
    final count = counts[candidate.id] ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChip(
          label: Text(_chipLabel(candidate, count)),
          selected: counts.containsKey(candidate.id),
          // `repeatable` 的 chip 是"加一次"按钮：`FilterChip` 在已选时回调
          // `false`，按普通 toggle 语义永远无法选到第二次（§3.10.2 允许同一 id
          // 选 N 次）。减一次由 chip 上的删除图标承担（`onDeleted`），移除的是
          // **第一次出现**的那次。
          onSelected: (_) => _onChipSelected(candidate),
          onDeleted: definition.repeatable && count > 0
              ? () => _removeOne(candidate.id)
              : null,
          deleteIcon: definition.repeatable && count > 0
              ? Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                  key: Key('rule-choice-remove-${candidate.id}'),
                )
              : null,
        ),
        if (candidate.entry != null && onOpenEntry != null)
          IconButton(
            key: Key('builder-open-entry-${candidate.id}'),
            tooltip: '查看 ${candidate.label}',
            onPressed: () => onOpenEntry!(candidate.entry!),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
      ],
    );
  }

  /// 选中 / 取消的唯一交互实现：算法本体是顶层函数
  /// [toggleRuleChoiceSelection]（技能选择器与共享组件共用，只有一处实现），
  /// 本方法只负责把 chip 的事件翻译成它的入参。
  ///
  /// 结果与当前选中值**逐项相同**时不回调：已达上限的追加是 no-op，不得
  /// 触发一次"看起来什么都没变"的重建（更不得静默丢值）。
  void _onChipSelected(RuleChoiceCandidate candidate) {
    final next = toggleRuleChoiceSelection(
      selected: selected,
      id: candidate.id,
      repeatable: definition.repeatable,
      maximum: definition.maximum,
    );
    if (listEquals(next, selected)) return;
    onChanged(next);
  }

  void _removeOne(String id) {
    final next = <String>[...selected];
    next.remove(id);
    onChanged(List<String>.unmodifiable(next));
  }

  static String _chipLabel(RuleChoiceCandidate candidate, int count) {
    return count > 1 ? '${candidate.label} ×$count' : candidate.label;
  }

  static Map<String, int> _countsById(List<String> selected) {
    final counts = <String, int>{};
    for (final id in selected) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  static String _labelsFor(
    List<String> selected,
    List<RuleChoiceCandidate> candidates,
  ) {
    final labels = {for (final candidate in candidates) candidate.id: candidate.label};
    return selected.map((id) => labels[id] ?? id).join('、');
  }
}

/// 选择声明里的 `builderStep` → 创建向导步骤索引的**唯一映射**。
///
/// `origin` 继承来源条目的步骤（背景条目声明 `origin` 就落在背景步骤），
/// `null` / 未知取值同样继承来源步骤。创建向导与结构守卫测试都读它：白名单
/// `RuleChoiceDefinition.allowedBuilderSteps` 放行的每一项都必须在这个映射的
/// 目标步骤真的渲染出选择区，否则就是"看不见却阻塞创建"（决策 D7）。
int ruleChoiceBuilderStep(String? declaredStep, {required int inheritedStep}) {
  return switch (declaredStep) {
    'class' => 0,
    'origin' => inheritedStep,
    'abilities' => 3,
    'proficiencies' => 4,
    'equipment' => 5,
    'spells' => 6,
    'details' => 7,
    _ => inheritedStep,
  };
}

/// 选项级 `requires`（`options[].requires`，决策 D6）不满足的候选**不出现**。
///
/// **唯一实现点**（候选过滤）：判定本体是
/// `RuleChoiceSemantics.candidateRequiresSatisfied`，本函数只做过滤。共享组件
/// [RuleChoiceSection] 与法术池（创建向导 `_spellChoicePoolSections`）都调它，
/// 不得各自再写一份过滤，否则两处口径分叉 = "界面上看得见、引擎判不在候选集"。
List<RuleChoiceCandidate> visibleRuleChoiceCandidates(
  List<RuleChoiceCandidate> candidates,
  RuleChoiceRequiresContext? context,
) {
  if (context == null) return candidates;
  return candidates
      .where(
        (candidate) => RuleChoiceSemantics.candidateRequiresSatisfied(
          candidate,
          sourceEntryId: context.sourceEntryId,
          selectedByKey: context.selectedByKey,
          abilities: context.abilities,
          entries: context.entries,
        ),
      )
      .toList(growable: false);
}

/// 选择 chip 的**唯一**选中 / 取消算法（契约 §3.10.2、§3.10.3-4）。
///
/// 创建向导「熟练」步骤的技能选择器与共享组件 [RuleChoiceSection] 都调它，
/// **不得**各自再写一份"加/减/替换"的判断。顺序 = 用户点击顺序 =
/// `build.choices` 落库顺序；返回**不可变副本**。
///
/// 语义：
/// - `repeatable == false` 且该 id 已在选中值里 → 移除**第一次出现**的那次
///   （顺序不变，其余重复项保留）；
/// - `repeatable == false` 且 `maximum <= 1` → 替换为当前 id（单选卡片点击另一个
///   候选即切换，不需要先取消）；
/// - 已选数量达到 `maximum` → 原样返回（不静默丢弃已选值）；
/// - 其余 → 追加到末尾。
///
/// `repeatable == true` 时"减一次"由 chip 上的删除图标承担（共享组件的
/// `onDeleted`），不走本函数——本函数只负责"加一次"。
List<String> toggleRuleChoiceSelection({
  required List<String> selected,
  required String id,
  required bool repeatable,
  required int maximum,
}) {
  final next = <String>[...selected];
  if (!repeatable && next.contains(id)) {
    next.remove(id);
    return List<String>.unmodifiable(next);
  }
  if (!repeatable && maximum <= 1) {
    return List<String>.unmodifiable(<String>[id]);
  }
  if (next.length >= maximum) return List<String>.unmodifiable(selected);
  next.add(id);
  return List<String>.unmodifiable(next);
}

/// 一组 `group` 相同的选择（`group == null` = 无标题组）。
class RuleChoiceGroup {
  const RuleChoiceGroup({this.title, required this.children});

  final String? title;
  final List<Widget> children;
}

/// 把一组选择按 `definition.group` 归组（决策 D7）：**组按首次声明顺序**，
/// 组内保持声明顺序；未声明 `group` 的选择归入一个无标题组并**排在最后**。
///
/// **唯一实现点**：三处选择界面都调它，不得各自写分组循环。
List<RuleChoiceGroup> groupRuleChoiceSections<T>(
  Iterable<T> choices, {
  required String? Function(T choice) groupOf,
  required Widget Function(T choice) buildChoice,
}) {
  final order = <String?>[];
  final grouped = <String?, List<Widget>>{};
  for (final choice in choices) {
    final title = groupOf(choice);
    final children = grouped.putIfAbsent(title, () {
      order.add(title);
      return <Widget>[];
    });
    children.add(buildChoice(choice));
  }
  final ordered = <String?>[
    ...order.where((title) => title != null),
  ];
  if (grouped.containsKey(null)) ordered.add(null);
  return [
    for (final title in ordered)
      RuleChoiceGroup(title: title, children: grouped[title]!),
  ];
}

/// `group` 标题的**唯一渲染点**（`DESIGN.md` 层级：`textTheme.titleSmall`，无新 token）。
///
/// 归组的唯一实现点是 [groupRuleChoiceSections]；标题样式的唯一实现点就是本组件：
/// 共享容器 [RuleChoiceGroupedSections] 与创建向导的两个专用渲染器（技能网格 /
/// 法术池，都经 [RuleChoiceGroupedSections]）全用它，不得各写第二份标题样式，
/// 否则 `group` 的呈现会在四种渲染路径上分叉。
class RuleChoiceGroupTitle extends StatelessWidget {
  const RuleChoiceGroupTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.titleSmall);
}

/// 分组容器的渲染：有 `group` 的组显示标题，无 `group` 的组不显示空标题。
///
/// 标题用 [RuleChoiceGroupTitle]（`DESIGN.md` 层级，无新 token）。
class RuleChoiceGroupedSections extends StatelessWidget {
  const RuleChoiceGroupedSections({required this.groups, super.key});

  final List<RuleChoiceGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          if (group.title case final String title) ...[
            RuleChoiceGroupTitle(title: title),
            const SizedBox(height: 4),
          ],
          ...group.children,
        ],
      ],
    );
  }
}

/// 选项级 `requires`（`options[].requires`，决策 D6）判定所需的上下文。
///
/// 三处选择界面构造它并交给 [RuleChoiceSection]；隐藏判定的本体只有
/// `RuleChoiceSemantics.candidateRequiresSatisfied` 一处。
class RuleChoiceRequiresContext {
  const RuleChoiceRequiresContext({
    required this.sourceEntryId,
    required this.selectedByKey,
    required this.abilities,
    required this.entries,
  });

  final String sourceEntryId;
  final Map<String, List<String>> selectedByKey;
  final Map<String, int> abilities;
  final Map<String, ContentEntry> entries;
}

/// 选择级 `requires` 中**第一条不满足项**的原因文案；全部满足时返回 `null`。
///
/// **唯一实现点**（呈现层）：判定仍走 `RuleChoiceSemantics.requiresSatisfied`
/// （逐条求值，AND 语义下"第一条不满足"就是阻塞原因）。三处选择界面共用，
/// 不得各自拼"需要魅力 13"这类文案。
String? ruleChoiceBlockedReason(
  List<RuleRequiresDefinition> requires, {
  required RuleChoiceRequiresContext context,
}) {
  for (final requirement in requires) {
    final satisfied = RuleChoiceSemantics.requiresSatisfied(
      <RuleRequiresDefinition>[requirement],
      sourceEntryId: context.sourceEntryId,
      selectedByKey: context.selectedByKey,
      abilities: context.abilities,
      entries: context.entries,
    );
    if (!satisfied) return ruleRequiresReason(requirement, context.abilities);
  }
  return null;
}

/// 一条 `requires` 的人类可读原因（属性门槛 / 选择引用）。
String ruleRequiresReason(
  RuleRequiresDefinition requirement,
  Map<String, int> abilities,
) {
  if (requirement.isAbilityForm) {
    final key = requirement.ability!;
    final name = Dnd5eRules.abilityLabels[key] ?? key;
    return '需要$name ${requirement.minimum}';
  }
  final option = requirement.option;
  if (option == null) return '需要先完成选择「${requirement.choice}」';
  return '需要先选择「$option」';
}
