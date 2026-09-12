// character_editor_page.dart 的 part：创建流程选择、职业/种族/背景选项与升级预览区。
part of 'character_editor_page.dart';

String _characterSectionKey(String title) {
  return switch (title) {
    '感官与语言' => 'senses',
    '特质' => 'traits',
    '动作' => 'actions',
    '附赠动作' => 'bonus-actions',
    '反应' => 'reactions',
    '传奇动作' => 'legendary-actions',
    _ => title,
  };
}

class _CharacterUpgradePreview {
  const _CharacterUpgradePreview({
    required this.build,
    required this.newGrants,
    required this.ruleChoices,
    required this.pendingChoices,
    required this.missingEntryIds,
  });

  final CharacterBuild build;
  final List<ResolvedRuleGrant> newGrants;
  final List<ActiveRuleChoice> ruleChoices;
  final List<PendingRuleChoice> pendingChoices;
  final List<String> missingEntryIds;

  bool get canApply => pendingChoices.isEmpty && missingEntryIds.isEmpty;
}

class _CharacterUpgradeSection extends StatelessWidget {
  const _CharacterUpgradeSection({
    required this.preview,
    required this.applied,
    required this.onApply,
    required this.entries,
    required this.onChoiceChanged,
  });

  final _CharacterUpgradePreview preview;
  final bool applied;
  final VoidCallback? onApply;
  final List<ContentEntry> entries;
  final void Function(String key, Set<String> selected) onChoiceChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '升级队列',
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.trending_up_outlined),
                title: Text('升级到 ${preview.build.level} 级'),
                subtitle: Text(
                  applied ? '等级规则已应用，保存角色后生效。' : '检查本级自动授予与必须完成的选择。',
                ),
              ),
              for (final grant in preview.newGrants)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text('新增：${grant.label}'),
                  subtitle: Text(
                    grant.sourceLevel == null
                        ? grant.sourceEntryName
                        : '${grant.sourceEntryName} · 等级 ${grant.sourceLevel}',
                  ),
                ),
              for (final choice in preview.ruleChoices)
                _UpgradeRuleChoiceSection(
                  choice: choice,
                  entries: entries,
                  onChanged: (selected) =>
                      onChoiceChanged(choice.key, selected),
                ),
              for (final entryId in preview.missingEntryIds)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.link_off_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text('缺少资料：$entryId'),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: applied ? null : onApply,
                icon: Icon(
                  applied ? Icons.check_circle_outline : Icons.auto_fix_high,
                ),
                label: Text(applied ? '等级规则已应用' : '应用等级规则'),
              ),
              if (!preview.canApply)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '请完成本级新增选择，或恢复缺失的资料条目。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeRuleChoiceSection extends StatelessWidget {
  const _UpgradeRuleChoiceSection({
    required this.choice,
    required this.entries,
    required this.onChanged,
  });

  final ActiveRuleChoice choice;
  final List<ContentEntry> entries;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final definition = choice.definition;
    final options = RuleChoiceResolver(
      entries: {for (final entry in entries) entry.id: entry},
    ).optionsFor(definition, sourceEntryId: choice.sourceEntryId);
    return Card.outlined(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    definition.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(
                  choice.isValid
                      ? Icons.check_circle_outline
                      : Icons.pending_actions_outlined,
                  color: choice.isValid
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${choice.sourceEntryName} · 选择 ${definition.minimum}-${definition.maximum} 项',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (options.isEmpty)
              Text(
                '没有符合当前等级与资格的选项。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in options)
                    FilterChip(
                      label: Text(option.name),
                      selected: choice.selected.contains(option.id),
                      onSelected: (selected) {
                        final next = choice.selected.toSet();
                        if (selected) {
                          if (definition.maximum == 1) next.clear();
                          if (next.length < definition.maximum) {
                            next.add(option.id);
                          }
                        } else {
                          next.remove(option.id);
                        }
                        onChanged(next);
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _CreationFlow { choose, standard, fullSheet }

/// 无内容条目时的职业兜底选项：**从档案 `classAliases` 的键派生**
/// （12 项展示名），不写死任何职业名；排序只为让快速选择项稳定可复现。
/// 档案未装配即启动 fail-fast（`Dnd5eRules.profile` 抛错），不做空清单兜底。
List<String> get _defaultClassOptions =>
    Dnd5eRules.profile.aliases.keys.toList()..sort();

const _defaultSpeciesOptions = ['人类', '精灵', '矮人', '半身人'];
const _defaultBackgroundOptions = ['士兵', '贤者', '罪犯', '侍祭'];

_CreationFlow _flowFromPreference(String value) {
  return switch (value) {
    'standard' => _CreationFlow.standard,
    'fullSheet' => _CreationFlow.fullSheet,
    _ => _CreationFlow.choose,
  };
}

class _CreationChoiceCard extends StatelessWidget {
  const _CreationChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
