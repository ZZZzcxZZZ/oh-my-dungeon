import 'package:flutter/material.dart';

import '../../content/domain/content_entry.dart';
import '../../content/presentation/content_entry_preview_page.dart';
import '../../rules/domain/character_rules_engine.dart';
import '../../rules/domain/rule_choice_semantics.dart';
import '../domain/character.dart';
import '../domain/character_upgrade_planner.dart';
import 'widgets/declared_level_banner.dart';
import 'widgets/rule_choice_section.dart';

typedef CharacterUpgradeApply = Future<bool> Function(CharacterSheet character);

class CharacterUpgradePage extends StatefulWidget {
  const CharacterUpgradePage({
    required this.character,
    required this.contentEntries,
    required this.onApply,
    this.packagePriorities = const <String, int>{},
    this.disabledOriginIds = const <String>{},
    this.pinnedOrigins = const <String, String>{},
    super.key,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
  final CharacterUpgradeApply onApply;

  /// 包 id → priority 与用户对覆盖的选择（决策 D2 / D6）：升级再派生必须与建档
  /// 同一口径，否则"关闭覆盖"会在升级时被静默还原（0.4-1）。
  final Map<String, int> packagePriorities;
  final Set<String> disabledOriginIds;
  final Map<String, String> pinnedOrigins;

  @override
  State<CharacterUpgradePage> createState() => _CharacterUpgradePageState();
}

class _CharacterUpgradePageState extends State<CharacterUpgradePage> {
  late final Map<String, ContentEntry> _entries;
  late final CharacterUpgradePlanner _planner;
  CharacterUpgradePlan? _plan;
  String? _error;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _entries = <String, ContentEntry>{
      for (final entry in widget.contentEntries) entry.id: entry,
    };
    _planner = CharacterUpgradePlanner(
      entries: _entries,
      packagePriorities: widget.packagePriorities,
      disabledOriginIds: widget.disabledOriginIds,
      pinnedOrigins: widget.pinnedOrigins,
    );
    try {
      _plan = _planner.plan(widget.character);
    } on StateError catch (error) {
      _error = error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('升级角色')),
      body: plan == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error ?? '当前角色无法使用规则引导升级'),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(
                        '${plan.currentLevel} → ${plan.targetLevel} 级',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.character.classSummary,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      _UpgradeSection(
                        title: '自动获得',
                        icon: Icons.auto_awesome_outlined,
                        child: plan.newGrants.isEmpty
                            ? const Text('本级没有新的固定条目')
                            : Column(
                                children: [
                                  for (final grant in plan.newGrants)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      title: Text(grant.label),
                                      subtitle: Text(_grantKindLabel(grant)),
                                    ),
                                ],
                              ),
                      ),
                      // `group` 相同的选择归一组：归组的**唯一实现点**是
                      // `groupRuleChoiceSections`（与创建向导 / 编辑器升级队列同一
                      // 份），本页不得再写一套逐条渲染的分组循环。
                      RuleChoiceGroupedSections(
                        groups: groupRuleChoiceSections<ActiveRuleChoice>(
                          plan.choices,
                          groupOf: (choice) => choice.definition.group,
                          buildChoice: (choice) => _UpgradeSection(
                            title: choice.definition.label,
                            icon: choice.isValid
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            child: _ChoiceOptions(
                              choice: choice,
                              entries: _entries,
                              requiresContext: RuleChoiceRequiresContext(
                                sourceEntryId: choice.sourceEntryId,
                                selectedByKey: plan.build.choices,
                                abilities: plan.build.abilities,
                                entries: _entries,
                              ),
                              onChanged: (selected) =>
                                  _select(choice.key, selected),
                            ),
                          ),
                        ),
                      ),
                      if (plan.missingEntryIds.isNotEmpty)
                        _UpgradeSection(
                          title: '缺少资料',
                          icon: Icons.warning_amber_outlined,
                          child: Text(plan.missingEntryIds.join('\n')),
                        ),
                      _UpgradeSection(
                        title: '确认',
                        icon: Icons.fact_check_outlined,
                        child: Text(
                          plan.isComplete
                              ? '所有选择已完成。确认后将一次性更新角色卡。'
                              : '完成上方必选项后即可升级。',
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // §3.12：目标等级超出职业声明范围时，在确认按钮上方说明
                        // "仍可继续（数值按未声明处理）"，不阻断升级。
                        if (plan.beyondDeclaredLevel) ...[
                          DeclaredLevelBanner(
                            levels: plan.declaredLevels,
                            currentLevel: plan.targetLevel,
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('apply-upgrade'),
                            onPressed: plan.isComplete && !_applying
                                ? _apply
                                : null,
                            icon: _applying
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upgrade),
                            label: const Text('确认升级'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _select(String choiceKey, List<String> selected) {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _plan = _planner.select(widget.character, plan, choiceKey, selected);
    });
  }

  Future<void> _apply() async {
    final plan = _plan;
    if (plan == null || !plan.isComplete) return;
    setState(() => _applying = true);
    final upgraded = _planner.apply(widget.character, plan);
    final success = await widget.onApply(upgraded);
    if (!mounted) return;
    setState(() => _applying = false);
    if (success) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(upgraded);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('升级保存失败，请重试')));
    }
  }
}

class _ChoiceOptions extends StatelessWidget {
  const _ChoiceOptions({
    required this.choice,
    required this.entries,
    required this.requiresContext,
    required this.onChanged,
  });

  final ActiveRuleChoice choice;
  final Map<String, ContentEntry> entries;
  final RuleChoiceRequiresContext requiresContext;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    // 候选一律经 `RuleChoiceSemantics.candidatesFor`（内联 `options` + 条目候选
    // 合并），共享组件是唯一的渲染器；`requires` 的判定与原因文案同样只有
    // `RuleChoiceSemantics.requiresSatisfied` / `ruleChoiceBlockedReason` 两处。
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
        entries: entries,
        sourceEntryId: choice.sourceEntryId,
      ),
      selected: choice.selected,
      showTitle: false,
      blockedReason: blockedReason,
      requiresContext: requiresContext,
      onOpenEntry: (entry) => showContentEntryPreviewDialog(
        context,
        entry: entry,
        entries: entries.values.toList(growable: false),
      ),
      onChanged: onChanged,
    );
  }
}

class _UpgradeSection extends StatelessWidget {
  const _UpgradeSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

String _grantKindLabel(ResolvedRuleGrant grant) => switch (grant.kind.name) {
  'feature' => '特性',
  'spell' => '法术',
  'equipment' => '装备',
  'action' => '动作',
  _ => '规则更新',
};
