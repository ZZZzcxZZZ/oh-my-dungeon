import 'package:flutter/material.dart';

import '../../domain/content_entry.dart';
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
              title: '等级 ${step.level}',
              grants: _visibleGrants(step.grants),
              choices: step.choices,
            ),
          ],
      ],
    );
  }

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
      RuleGrantKind.resource => Icons.battery_5_bar_outlined,
      RuleGrantKind.action => Icons.bolt_outlined,
      RuleGrantKind.conditionResistance => Icons.health_and_safety_outlined,
      RuleGrantKind.speed => Icons.directions_run_outlined,
      RuleGrantKind.armorClass => Icons.shield_outlined,
      RuleGrantKind.hitPoints => Icons.favorite_outline,
      RuleGrantKind.ability => Icons.hexagon_outlined,
      RuleGrantKind.note => Icons.notes_outlined,
    };
  }
}
