// 角色页的「规则来源」组件（契约 §3.7、S3 任务 9）。
//
// 设计契约：只用 colorScheme 角色；覆盖用 `tertiary`（信息级，不是 error），
// 内置档案用 `onSurfaceVariant` 次级文字；图标控件带 Tooltip；圆角走
// `Card.outlined`；对话框宽度取 `DialogSizes.narrow`；不新增 DESIGN token，
// 也不出现任何硬编码颜色。
import 'package:flutter/material.dart';

import '../../../../core/presentation/dialog_sizes.dart';
import '../../domain/recorded_rule_choices.dart';
import '../../../rules/domain/rule_field_path.dart';
import '../../../rules/domain/rule_override_conflict.dart';
import '../../../rules/domain/rule_override_declaration.dart';
import '../../../rules/domain/rule_profile.dart';

/// 来源 id → 展示名的**唯一**读取口径：条目 id 优先，退回它所属包 id，最后原样
/// 返回 id（绝不猜成"内置档案"）。
String ruleOriginLabel(String originId, Map<String, String> originLabels) =>
    originLabels[originId] ??
    originLabels[RuleOverrideDeclaration.packageIdOf(originId)] ??
    originId;

/// 单个字段 / 列的来源徽标（内置档案 vs 覆盖它的包）。
class RuleSourceChip extends StatelessWidget {
  const RuleSourceChip({
    required this.field,
    required this.source,
    required this.originLabels,
    this.entryOriginId,
    this.resourceName,
    this.onDisableOverride,
    super.key,
  });

  /// `RuleFieldPath` 的列级路径（唯一实现，不手拼）。
  final String field;

  /// null = 来源未知（不猜成内置档案）。
  final RuleFieldSource? source;

  /// 来源 id → 展示名。缺省时退回 originId。
  final Map<String, String> originLabels;

  /// 角色**自己那条**职业条目的 originId。来源是它时**不显示**关闭按钮：解析器
  /// 有意无条件包含自身条目、并忽略对 `entryId` 的 disabled（自身条目不是"覆盖"），
  /// 因此那个按钮点了没有任何效果（C）。
  final String? entryOriginId;

  /// 资源列的展示名（`resources.<id>.<列>` 的 `<id>` 部分）。缺省时退回资源 id。
  final String? resourceName;

  /// 非空且该列确实是外部来源的覆盖时，显示"关闭该来源的覆盖"入口。
  final Future<void> Function(String originId)? onDisableOverride;

  bool get _isOverride => (source?.tier ?? 0) > 0;

  /// 来源是角色自身条目时按"非覆盖"渲染（图标 / 文案 / 按钮一致，不给出点了
  /// 没反应的控件）。
  bool get _isOwnEntry =>
      source != null && entryOriginId != null && source!.originId == entryOriginId;

  bool get _showsOverride => _isOverride && !_isOwnEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = source;
    final label = current == null
        ? '来源未知'
        : ruleOriginLabel(current.originId, originLabels);
    final color = _showsOverride
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _showsOverride ? '该列被内容包覆盖' : '该列来自内置规则档案',
          child: Icon(
            _showsOverride ? Icons.extension_outlined : Icons.rule_outlined,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${RuleFieldPath.labelFor(field, resourceName: resourceName)}：$label',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 按钮按**列**显示，但语义是"关掉整条来源"：`disable(originId)` 会连带
        // 关掉该来源在别的列上的覆盖。文案与 Tooltip 必须说清这一点（C）。
        if (_showsOverride && current != null && onDisableOverride != null)
          Tooltip(
            message: '会关闭该来源在所有列上的覆盖',
            child: TextButton(
              onPressed: () => onDisableOverride!(current.originId),
              child: const Text('关闭该来源的覆盖'),
            ),
          ),
      ],
    );
  }
}

/// 冲突提示条：同 tier 多来源抢同一列（决策 D6）。
class RuleOverrideConflictBanner extends StatelessWidget {
  const RuleOverrideConflictBanner({
    required this.conflicts,
    required this.originLabels,
    required this.onResolve,
    super.key,
  });

  final List<RuleOverrideConflict> conflicts;
  final Map<String, String> originLabels;

  /// 用户在对话框里选完之后回调（列表里的 `effectiveOriginId` 已被替换）。
  /// null = 只读（不显示"处理"按钮，避免点了没反应）。
  final Future<void> Function(List<RuleOverrideConflict> conflicts)? onResolve;

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.call_split, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${conflicts.length} 处规则覆盖冲突：多个内容包以相同优先级声明了同一列',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (onResolve != null)
                TextButton(
                  onPressed: () => _openResolveDialog(context),
                  child: const Text('处理'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openResolveDialog(BuildContext context) async {
    final result = await showDialog<List<RuleOverrideConflict>>(
      context: context,
      builder: (context) => RuleOverrideConflictDialog(
        conflicts: conflicts,
        originLabels: originLabels,
      ),
    );
    if (result != null) await onResolve?.call(result);
  }
}

/// 冲突选择对话框：每个冲突一段，用一个 `RadioListTile` 列表列出竞争来源，
/// 默认选中当前的 `effectiveOriginId`。
class RuleOverrideConflictDialog extends StatefulWidget {
  const RuleOverrideConflictDialog({
    required this.conflicts,
    required this.originLabels,
    super.key,
  });

  final List<RuleOverrideConflict> conflicts;
  final Map<String, String> originLabels;

  @override
  State<RuleOverrideConflictDialog> createState() =>
      _RuleOverrideConflictDialogState();
}

class _RuleOverrideConflictDialogState
    extends State<RuleOverrideConflictDialog> {
  late final Map<String, String> _selection;

  @override
  void initState() {
    super.initState();
    _selection = <String, String>{
      for (final conflict in widget.conflicts)
        conflict.field: conflict.effectiveOriginId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('覆盖冲突'),
      content: SizedBox(
        width: DialogSizes.narrow,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final conflict in widget.conflicts) ...[
                Text(
                  RuleFieldPath.labelFor(conflict.field),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                RadioGroup<String>(
                  groupValue: _selection[conflict.field],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selection[conflict.field] = value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final originId in conflict.originIds)
                        RadioListTile<String>(
                          key: Key(
                            'conflict-choice-${conflict.field}-$originId',
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: originId,
                          title: Text(
                            ruleOriginLabel(originId, widget.originLabels),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          // 只回传**选择发生变化**的项（I）：对话框默认把每一项选中为
          // `effectiveOriginId`，全量回传会把用户没动过的列也静默 pin 上
          // （pin 豁免 disabled 且抑制后续冲突提示），而且没有撤销入口。
          onPressed: () => Navigator.of(context).pop(<RuleOverrideConflict>[
            for (final conflict in widget.conflicts)
              if (_selection[conflict.field] != conflict.effectiveOriginId)
                RuleOverrideConflict(
                  field: conflict.field,
                  tier: conflict.tier,
                  originIds: conflict.originIds,
                  effectiveOriginId: _selection[conflict.field]!,
                ),
          ]),
          child: const Text('保存选择'),
        ),
      ],
    );
  }
}

/// 「规则来源」集中管理卡（角色资料页）：列出全部列级来源，可逐条关闭覆盖，
/// 并列出**已关闭的来源**（`CharacterRuleOverrides.disabledOriginIds`）供用户恢复。
class RuleSourceListCard extends StatelessWidget {
  const RuleSourceListCard({
    required this.sources,
    required this.originLabels,
    this.entryOriginId,
    this.disabledOriginIds = const <String>{},
    this.resourceNames = const <String, String>{},
    this.onDisableOverride,
    this.onEnableOverride,
    super.key,
  });

  final Map<String, RuleFieldSource> sources;
  final Map<String, String> originLabels;

  /// 角色自身条目的 originId（自身条目不是覆盖，见 [RuleSourceChip.entryOriginId]）。
  final String? entryOriginId;

  /// 用户已关闭的来源（条目 id 或包 id）。列表非空时渲染「已关闭的来源」区，
  /// 否则关闭后**没有恢复入口**（C）。
  final Set<String> disabledOriginIds;

  /// 资源 id → 资源展示名：把"资源列标签显示裸 id"补齐（K）。缺省时
  /// [RuleFieldPath.labelFor] 自己退回资源 id。
  final Map<String, String> resourceNames;

  final Future<void> Function(String originId)? onDisableOverride;

  /// 恢复一条被关闭的来源（`CharacterRuleOverrides.enable` 的 UI 入口）。
  final Future<void> Function(String originId)? onEnableOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = sources.keys.toList()..sort();
    final disabled = disabledOriginIds.toList()..sort();
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('规则来源', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '每个数值列最终取自哪里；关闭某条来源的覆盖后回退到更低优先级的'
              '声明（可能回到内置档案）。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (fields.isEmpty)
              Text('当前职业规则没有列级来源，数值全部来自职业声明。',
                  style: theme.textTheme.bodyMedium)
            else
              for (final field in fields)
                RuleSourceChip(
                  field: field,
                  source: sources[field],
                  originLabels: originLabels,
                  entryOriginId: entryOriginId,
                  resourceName: _resourceNameOf(field),
                  onDisableOverride: onDisableOverride,
                ),
            if (disabled.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('已关闭的来源', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '这些来源在所有列上的覆盖都已关闭；恢复后按优先级重新生效。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final originId in disabled)
                Row(
                  key: Key('disabled-origin-$originId'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        ruleOriginLabel(originId, originLabels),
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onEnableOverride != null)
                      // 与邻居"关闭该来源的覆盖"一致都带 Tooltip：说明恢复的作用域
                      // 是**整条来源**（它在所有列上的覆盖会一起回来）。
                      Tooltip(
                        message: '会恢复该来源在所有列上的覆盖',
                        child: TextButton(
                          onPressed: () => onEnableOverride!(originId),
                          child: const Text('恢复'),
                        ),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 资源列路径 → 资源展示名。只经 [RuleFieldPath.parseResource]（路径解析的
  /// **唯一**实现），不手拼前缀、不 split。
  String? _resourceNameOf(String field) {
    final parsed = RuleFieldPath.parseResource(field);
    return parsed == null ? null : resourceNames[parsed.id];
  }
}

/// 「规则选择」卡：角色创建 / 升级时**选定**的规则选择（含不产生数值的记录型选项）。
///
/// 与 [RuleSourceListCard]（每个数值列取自哪里）互补：这一张回答"我选了什么"，
/// 数据来自角色落库的 `data['choices']`（读取实现唯一：`recordedRuleChoices`）。
class RuleChoiceListCard extends StatelessWidget {
  const RuleChoiceListCard({required this.choices, super.key});

  final List<RecordedRuleChoice> choices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('规则选择', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '创建与升级时选定的规则选择；含只记录、不产生数值的选项。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (choices.isEmpty)
              Text('当前角色没有记录规则选择。', style: theme.textTheme.bodyMedium)
            else
              for (final choice in choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          choice.summary,
                          key: Key(
                            'recorded-choice-${choice.sourceEntryId}'
                            '#${choice.choiceId}',
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
