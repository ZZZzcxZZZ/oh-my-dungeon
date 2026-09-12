import 'package:flutter/material.dart';

import '../../domain/content_entry.dart';
import '../../../characters/domain/declared_levels.dart';
import '../../../characters/presentation/widgets/declared_level_banner.dart';
import '../../../rules/domain/character_rule_definition.dart';

class ContentCharacterRulesView extends StatelessWidget {
  const ContentCharacterRulesView({
    required this.entry,
    this.hiddenFeatureTargets = const {},
    super.key,
  });

  final ContentEntry entry;
  final Set<String> hiddenFeatureTargets;

  @override
  Widget build(BuildContext context) {
    final rules = entry.rules;
    if (rules == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final immediateGrants = _visibleGrants(rules.grants);
    // §3.12：声明范围是**职业**概念。判据就是条目类型：只有 `class` 条目才显示
    // "职业声明：…"，职业条目即使完全没有声明也要显式说明"未声明"；非职业条目
    // （物种/背景等）即便碰巧解析出等级区间也不显示——否则资料库会凭空冒出一条
    // "职业声明"。这与 [DeclaredLevels._progressionLevels] 只认 `class` 一致。
    final declaredLevels = DeclaredLevels.fromEntry(entry);
    final showDeclaredLevels = entry.type == 'class';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.account_tree_outlined, size: 20),
            const SizedBox(width: 8),
            Text('角色规则', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '角色创建和升级会自动应用以下内容。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (showDeclaredLevels) ...[
          const SizedBox(height: 8),
          // `currentLevel` 传最早声明等级：规则视图只说"声明了什么范围"，
          // 不针对某个角色喊"超出"。
          DeclaredLevelBanner(
            levels: declaredLevels,
            currentLevel: declaredLevels.min,
          ),
        ],
        if (immediateGrants.isNotEmpty || rules.choices.isNotEmpty) ...[
          const SizedBox(height: 8),
          _RuleGroup(
            title: '选择后立即获得',
            grants: immediateGrants,
            choices: rules.choices,
          ),
        ],
        for (final step in rules.progression)
          if (_visibleGrants(step.grants).isNotEmpty ||
              step.choices.isNotEmpty) ...[
            const SizedBox(height: 8),
            _RuleGroup(
              title: _levelsLabel(step.levels),
              grants: _visibleGrants(step.grants),
              choices: step.choices,
            ),
          ],
      ],
    );
  }

  /// 一个步骤可覆盖多个等级（`levels`）；单等级显示 `等级 4`，
  /// 多等级显示到达这些等级的集合 `等级 4/8/12/16`。
  String _levelsLabel(List<int> levels) => levels.length == 1
      ? '等级 ${levels.single}'
      : '等级 ${levels.join('/')}';

  List<RuleGrantDefinition> _visibleGrants(List<RuleGrantDefinition> grants) {
    return grants
        .where(
          (grant) =>
              grant.kind != RuleGrantKind.feature ||
              grant.target == null ||
              !hiddenFeatureTargets.contains(grant.target),
        )
        .toList(growable: false);
  }
}

class _RuleGroup extends StatelessWidget {
  const _RuleGroup({
    required this.title,
    required this.grants,
    required this.choices,
  });

  final String title;
  final List<RuleGrantDefinition> grants;
  final List<RuleChoiceDefinition> choices;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(title),
        subtitle: Text('${grants.length} 项授予 · ${choices.length} 项选择'),
        children: [
          for (final grant in grants)
            ListTile(
              dense: true,
              leading: Icon(_grantIcon(grant.kind)),
              title: Text(grant.label),
              subtitle: grant.target == null ? null : Text(grant.target!),
            ),
          for (final choice in choices)
            ListTile(
              dense: true,
              leading: const Icon(Icons.rule_outlined),
              title: Text(choice.label),
              subtitle: Text(_choiceSummary(choice)),
            ),
        ],
      ),
    );
  }

  String _choiceSummary(RuleChoiceDefinition choice) {
    final count = choice.minimum == choice.maximum
        ? '选择 ${choice.minimum} 项'
        : '选择 ${choice.minimum}–${choice.maximum} 项';
    return [
      count,
      choice.optionType,
      if (choice.builderStep != null) '步骤 ${choice.builderStep}',
      if (choice.optionTags.isNotEmpty) '标签 ${choice.optionTags.join(', ')}',
      if (choice.maximumOptionLevel != null)
        '最高等级 ${choice.maximumOptionLevel}',
      if (choice.recommendedEntryIds.isNotEmpty)
        '推荐 ${choice.recommendedEntryIds.length} 项',
    ].join(' · ');
  }

  IconData _grantIcon(RuleGrantKind kind) {
    return switch (kind) {
      RuleGrantKind.feature => Icons.auto_awesome_outlined,
      RuleGrantKind.proficiency => Icons.workspace_premium_outlined,
      RuleGrantKind.spell => Icons.auto_fix_high_outlined,
      RuleGrantKind.equipment => Icons.inventory_2_outlined,
      RuleGrantKind.action => Icons.bolt_outlined,
      RuleGrantKind.speed => Icons.directions_run_outlined,
      RuleGrantKind.armorClass => Icons.shield_outlined,
      RuleGrantKind.hitPoints => Icons.favorite_outline,
      RuleGrantKind.ability => Icons.hexagon_outlined,
    };
  }
}
