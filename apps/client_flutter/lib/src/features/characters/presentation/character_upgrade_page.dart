import 'package:flutter/material.dart';

import '../../content/domain/content_entry.dart';
import '../../content/presentation/content_entry_preview_page.dart';
import '../../rules/domain/character_rules_engine.dart';
import '../../rules/domain/rule_choice_resolver.dart';
import '../domain/character.dart';
import '../domain/character_upgrade_planner.dart';

typedef CharacterUpgradeApply = Future<bool> Function(CharacterSheet character);

class CharacterUpgradePage extends StatefulWidget {
  const CharacterUpgradePage({
    required this.character,
    required this.contentEntries,
    required this.onApply,
    super.key,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
  final CharacterUpgradeApply onApply;

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
    _planner = CharacterUpgradePlanner(entries: _entries);
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
                      for (final choice in plan.choices)
                        _UpgradeSection(
                          title: choice.definition.label,
                          icon: choice.isValid
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          child: _ChoiceOptions(
                            choice: choice,
                            entries: _entries,
                            onChanged: (selected) =>
                                _select(choice.key, selected),
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
                    child: SizedBox(
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
    required this.onChanged,
  });

  final ActiveRuleChoice choice;
  final Map<String, ContentEntry> entries;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = RuleChoiceResolver(
      entries: entries,
    ).optionsFor(choice.definition, sourceEntryId: choice.sourceEntryId);
    if (options.isEmpty) return const Text('没有符合条件的资料条目');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选择 ${choice.definition.minimum}–${choice.definition.maximum} 项'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilterChip(
                    label: Text(option.name),
                    selected: choice.selected.contains(option.id),
                    onSelected: (selected) {
                      final next = <String>[...choice.selected];
                      if (selected) {
                        if (choice.definition.maximum == 1) next.clear();
                        if (next.length < choice.definition.maximum) {
                          next.add(option.id);
                        }
                      } else {
                        next.remove(option.id);
                      }
                      onChanged(next);
                    },
                  ),
                  IconButton(
                    key: Key('builder-open-entry-${option.id}'),
                    tooltip: '查看 ${option.name}',
                    onPressed: () => showContentEntryPreviewDialog(
                      context,
                      entry: option,
                      entries: entries.values.toList(growable: false),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                ],
              ),
          ],
        ),
      ],
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
  'resource' => '职业资源',
  _ => '规则更新',
};
