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
  final void Function(String key, List<String> selected) onChoiceChanged;

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
              // `group` 相同的选择归一组：归组的**唯一实现点**是
              // `groupRuleChoiceSections`（与创建向导同一份），升级队列不得再写
              // 一套逐条渲染的分组循环。每条选择仍显示自己的标题（共享组件）。
              RuleChoiceGroupedSections(
                groups: groupRuleChoiceSections<ActiveRuleChoice>(
                  preview.ruleChoices,
                  groupOf: (choice) => choice.definition.group,
                  buildChoice: (choice) => _UpgradeRuleChoiceSection(
                    choice: choice,
                    entries: entries,
                    requiresContext: RuleChoiceRequiresContext(
                      sourceEntryId: choice.sourceEntryId,
                      selectedByKey: preview.build.choices,
                      abilities: preview.build.abilities,
                      entries: {for (final entry in entries) entry.id: entry},
                    ),
                    onChanged: (selected) =>
                        onChoiceChanged(choice.key, selected),
                  ),
                ),
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

/// 编辑器升级队列里的一条规则选择：**薄包装**，只把 `ActiveRuleChoice` 翻译成
/// 共享组件 `RuleChoiceSection` 的入参（候选一律经
/// `RuleChoiceSemantics.candidatesFor`，不再各自调 `RuleChoiceResolver`）。
class _UpgradeRuleChoiceSection extends StatelessWidget {
  const _UpgradeRuleChoiceSection({
    required this.choice,
    required this.entries,
    required this.requiresContext,
    required this.onChanged,
  });

  final ActiveRuleChoice choice;
  final List<ContentEntry> entries;
  final RuleChoiceRequiresContext requiresContext;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    // `requires` 是否满足以**引擎**的判定为准（[ActiveRuleChoice.requiresSatisfied]）；
    // 原因文案由 `ruleChoiceBlockedReason` 一处产出。前置不满足时不渲染候选，
    // 只显示原因与"已选但未生效"，且该选择仍留在升级队列里（不静默跳过）。
    final blockedReason = choice.requiresSatisfied
        ? null
        : ruleChoiceBlockedReason(
                choice.definition.requires,
                context: requiresContext,
              ) ??
              '前置条件不满足';
    return RuleChoiceSection(
      definition: choice.definition,
      candidates: RuleChoiceSemantics.candidatesFor(
        choice.definition,
        entries: requiresContext.entries,
        sourceEntryId: choice.sourceEntryId,
      ),
      selected: choice.selected,
      sourceLabel: choice.sourceLevel == null
          ? choice.sourceEntryName
          : '${choice.sourceEntryName} · 等级 ${choice.sourceLevel}',
      blockedReason: blockedReason,
      requiresContext: requiresContext,
      onOpenEntry: (entry) => showContentEntryPreviewDialog(
        context,
        entry: entry,
        entries: entries,
      ),
      onChanged: onChanged,
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
