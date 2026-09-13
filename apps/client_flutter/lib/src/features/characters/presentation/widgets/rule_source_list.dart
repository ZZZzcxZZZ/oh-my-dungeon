// 角色页的「规则来源」组件（契约 §3.7、S3 任务 9）。
//
// 设计契约：只用 colorScheme 角色；覆盖用 `tertiary`（信息级，不是 error），
// 内置档案用 `onSurfaceVariant` 次级文字；图标控件带 Tooltip；圆角走
// `Card.outlined`；对话框宽度取 `DialogSizes.narrow`；不新增 DESIGN token，
// 也不出现任何硬编码颜色。
import 'package:flutter/material.dart';

import '../../../../core/presentation/dialog_sizes.dart';
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
    this.onDisableOverride,
    super.key,
  });

  /// `RuleFieldPath` 的列级路径（唯一实现，不手拼）。
  final String field;

  /// null = 来源未知（不猜成内置档案）。
  final RuleFieldSource? source;

  /// 来源 id → 展示名。缺省时退回 originId。
  final Map<String, String> originLabels;

  /// 非空且该列确实是覆盖时，显示"使用内置档案"入口。
  final Future<void> Function(String originId)? onDisableOverride;

  bool get _isOverride => (source?.tier ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = source;
    final label = current == null
        ? '来源未知'
        : ruleOriginLabel(current.originId, originLabels);
    final color = _isOverride
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _isOverride ? '该列被内容包覆盖' : '该列来自内置规则档案',
          child: Icon(
            _isOverride ? Icons.extension_outlined : Icons.rule_outlined,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${RuleFieldPath.labelFor(field)}：$label',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_isOverride && current != null && onDisableOverride != null)
          TextButton(
            onPressed: () => onDisableOverride!(current.originId),
            child: const Text('使用内置档案'),
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
          onPressed: () => Navigator.of(context).pop(<RuleOverrideConflict>[
            for (final conflict in widget.conflicts)
              RuleOverrideConflict(
                field: conflict.field,
                tier: conflict.tier,
                originIds: conflict.originIds,
                effectiveOriginId:
                    _selection[conflict.field] ?? conflict.effectiveOriginId,
              ),
          ]),
          child: const Text('保存选择'),
        ),
      ],
    );
  }
}

/// 「规则来源」集中管理卡（角色资料页）：列出全部列级来源，并可逐条关闭覆盖。
class RuleSourceListCard extends StatelessWidget {
  const RuleSourceListCard({
    required this.sources,
    required this.originLabels,
    this.onDisableOverride,
    super.key,
  });

  final Map<String, RuleFieldSource> sources;
  final Map<String, String> originLabels;
  final Future<void> Function(String originId)? onDisableOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = sources.keys.toList()..sort();
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('规则来源', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '每个数值列最终取自哪里；关闭某条覆盖会回退到内置档案。',
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
                  onDisableOverride: onDisableOverride,
                ),
          ],
        ),
      ),
    );
  }
}
