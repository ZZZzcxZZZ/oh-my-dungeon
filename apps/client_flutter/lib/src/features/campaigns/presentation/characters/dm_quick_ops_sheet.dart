import 'package:flutter/material.dart';

import '../../../../core/dice/dice_roller.dart';
import '../../../characters/domain/dnd5e_rules.dart';
import '../../../content/data/local/content_repository.dart';
import '../../../content/domain/content_entry.dart';
import '../../domain/campaign_actor.dart';
import '../campaign_controller.dart';
import '../campaign_event_dispatcher.dart';
import 'campaign_actor_controller.dart';

/// Task 3.4 — DM 快捷操作面板.
///
/// 三个原子操作参考 BG3 战斗日志:
///   1. 批量扣血/治疗 — 多选 Actor + 数值 → `CampaignEventDispatcher.changeActorHp`
///   2. 给予装备 — 选 Actor + 资料物品 → `CampaignEventDispatcher.grantItem`
///   3. 快速检定 — 选 Actor + 检定类型 + DC → DM 代掷 + `sendMessage(kind: 'roll')`
class DmQuickOpsSheet extends StatelessWidget {
  const DmQuickOpsSheet({
    required this.campaignId,
    required this.actorController,
    required this.eventDispatcher,
    required this.campaignController,
    this.contentRepository,
    this.diceRoller,
    super.key,
  });

  final String campaignId;
  final CampaignActorController actorController;
  final CampaignEventDispatcher eventDispatcher;
  final CampaignController campaignController;
  final ContentRepository? contentRepository;
  final DiceRoller? diceRoller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('DM 快捷操作', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '批量扣血、给予装备、快速检定',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('批量扣血/治疗'),
            subtitle: const Text('选择多个角色, 输入数值 (负数伤害/正数治疗)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBatchHpDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('给予装备'),
            subtitle: const Text('从资料库选物品, 写入角色背包'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showGrantItemFlow(context),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('快速检定'),
            subtitle: const Text('选角色 + 检定类型 + DC, DM 代掷'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQuickCheckFlow(context),
          ),
        ],
      ),
    );
  }

  /// 操作 1: 批量扣血/治疗.
  void _showBatchHpDialog(BuildContext context) {
    final actors = actorController.actors
        .where((a) => a.status == 'active')
        .toList(growable: false);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _BatchHpDialog(
        actors: actors,
        campaignId: campaignId,
        dispatcher: eventDispatcher,
      ),
    );
  }

  /// 操作 2: 给予装备.
  Future<void> _showGrantItemFlow(BuildContext context) async {
    final actors = actorController.actors
        .where((a) => a.status == 'active')
        .toList(growable: false);
    final actor = await showDialog<CampaignActor>(
      context: context,
      builder: (_) => _ActorPickerDialog(actors: actors, title: '选择角色'),
    );
    if (actor == null || !context.mounted) return;

    var items = const <ContentEntry>[];
    if (contentRepository != null) {
      items = await contentRepository!.search(const ContentQuery(type: 'equipment'));
    }
    if (!context.mounted) return;

    final item = await showDialog<ContentEntry>(
      context: context,
      builder: (_) => _ItemPickerDialog(items: items),
    );
    if (item == null || !context.mounted) return;

    await eventDispatcher.grantItem(
      campaignId: campaignId,
      actorId: actor.id,
      itemId: item.id,
      name: item.name,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已给 ${actor.sheet['name']} ${item.name}')),
    );
  }

  /// 操作 3: 快速检定.
  Future<void> _showQuickCheckFlow(BuildContext context) async {
    final actors = actorController.actors
        .where((a) => a.status == 'active')
        .toList(growable: false);
    final actor = await showDialog<CampaignActor>(
      context: context,
      builder: (_) => _ActorPickerDialog(actors: actors, title: '选择检定角色'),
    );
    if (actor == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _QuickCheckDialog(
        actor: actor,
        campaignId: campaignId,
        campaignController: campaignController,
        diceRoller: diceRoller ?? DiceRoller(),
      ),
    );
  }
}

/// 批量 HP 变更对话框.
class _BatchHpDialog extends StatefulWidget {
  const _BatchHpDialog({
    required this.actors,
    required this.campaignId,
    required this.dispatcher,
  });

  final List<CampaignActor> actors;
  final String campaignId;
  final CampaignEventDispatcher dispatcher;

  @override
  State<_BatchHpDialog> createState() => _BatchHpDialogState();
}

class _BatchHpDialogState extends State<_BatchHpDialog> {
  final Set<String> _selectedIds = {};
  final _deltaController = TextEditingController();
  bool _applying = false;

  @override
  void dispose() {
    _deltaController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final delta = int.tryParse(_deltaController.text.trim());
    if (delta == null || _selectedIds.isEmpty) return;
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    var failures = 0;
    for (final actorId in _selectedIds.toList()) {
      try {
        await widget.dispatcher.changeActorHp(
          campaignId: widget.campaignId,
          actorId: actorId,
          delta: delta,
        );
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    setState(() => _applying = false);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? '已对 ${_selectedIds.length} 个角色应用 ${delta > 0 ? '治疗' : '伤害'} $delta'
              : '${_selectedIds.length - failures} 成功, $failures 失败',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('批量扣血/治疗'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.actors.length,
                itemBuilder: (context, index) {
                  final actor = widget.actors[index];
                  final name = actor.sheet['name']?.toString() ?? '未命名';
                  final hp = actor.sheet['currentHp'];
                  final maxHp = actor.sheet['maxHp'];
                  return CheckboxListTile(
                    value: _selectedIds.contains(actor.id),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(actor.id);
                        } else {
                          _selectedIds.remove(actor.id);
                        }
                      });
                    },
                    title: Text(name),
                    subtitle: Text('HP $hp/$maxHp'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('dm-batch-hp-delta'),
              controller: _deltaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数值 (负数=伤害, 正数=治疗)',
                hintText: '例如 -5 或 10',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applying ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('dm-batch-hp-apply'),
          onPressed: _applying || _selectedIds.isEmpty ? null : _apply,
          child: Text(_applying ? '应用中...' : '应用'),
        ),
      ],
    );
  }
}

/// 角色选择对话框.
class _ActorPickerDialog extends StatelessWidget {
  const _ActorPickerDialog({required this.actors, required this.title});

  final List<CampaignActor> actors;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: actors.length,
          itemBuilder: (context, index) {
            final actor = actors[index];
            final name = actor.sheet['name']?.toString() ?? '未命名';
            return ListTile(
              title: Text(name),
              onTap: () => Navigator.of(context).pop(actor),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 物品选择对话框.
class _ItemPickerDialog extends StatelessWidget {
  const _ItemPickerDialog({required this.items});

  final List<ContentEntry> items;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择物品'),
      content: SizedBox(
        width: double.maxFinite,
        child: items.isEmpty
            ? const Text('资料库中没有装备条目')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text(item.source.label),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 快速检定对话框.
class _QuickCheckDialog extends StatefulWidget {
  const _QuickCheckDialog({
    required this.actor,
    required this.campaignId,
    required this.campaignController,
    required this.diceRoller,
  });

  final CampaignActor actor;
  final String campaignId;
  final CampaignController campaignController;
  final DiceRoller diceRoller;

  @override
  State<_QuickCheckDialog> createState() => _QuickCheckDialogState();
}

class _QuickCheckDialogState extends State<_QuickCheckDialog> {
  String _checkType = 'ability';
  String _checkKey = 'dex';
  final _dcController = TextEditingController();

  @override
  void dispose() {
    _dcController.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    final name = widget.actor.sheet['name']?.toString() ?? '角色';
    final label = _labelFor(_checkType, _checkKey);
    final modifier = _modifierFor(_checkType, _checkKey);
    final die = widget.diceRoller.rollD20().total;
    final total = die + modifier;
    final dc = int.tryParse(_dcController.text.trim());
    final success = dc == null ? null : total >= dc;

    final content = dc == null
        ? '$name $label d20${_formatMod(modifier)} = $total'
        : '$name $label d20${_formatMod(modifier)} = $total ${success == true ? '≥' : '<'} DC $dc';

    Navigator.of(context).pop();
    await widget.campaignController.sendMessage(
      campaignId: widget.campaignId,
      kind: 'roll',
      content: content,
      campaignActorId: widget.actor.id,
      eventData: <String, Object?>{
        'checkType': _checkType,
        'checkKey': _checkKey,
        'label': label,
        'notation': 'd20${_formatMod(modifier)}',
        'die': die,
        'modifier': modifier,
        'total': total,
        'dmRolled': true,
        // ignore: use_null_aware_elements
        if (dc != null) 'dc': dc,
        // ignore: use_null_aware_elements
        if (success != null) 'success': success,
      },
    );
  }

  String _labelFor(String type, String key) {
    if (type == 'ability') {
      return Dnd5eRules.abilityLabels[key] ?? key.toUpperCase();
    }
    if (type == 'save') {
      return '${Dnd5eRules.abilityLabels[key] ?? key.toUpperCase()} 豁免';
    }
    return key;
  }

  int _modifierFor(String type, String key) {
    // 使用 actor sheet 中的属性值估算修正. 没有 level 上下文时退化为 0.
    final abilities = <String, int>{};
    final sheetAbilities = widget.actor.sheet['abilities'];
    if (sheetAbilities is Map) {
      sheetAbilities.forEach((k, v) {
        if (v is num) abilities[k.toString()] = v.toInt();
      });
    }
    final levelValue = widget.actor.sheet['level'];
    final level = levelValue is num ? levelValue.toInt() : 1;
    if (type == 'ability') {
      return Dnd5eRules.abilityModifier(Dnd5eRules.abilityScore(abilities, key));
    }
    if (type == 'save') {
      return Dnd5eRules.saveBonus(
        ability: key,
        abilities: abilities,
        level: level,
        proficient: false,
      );
    }
    return Dnd5eRules.skillBonus(
      skillName: key,
      abilities: abilities,
      level: level,
      proficient: false,
    );
  }

  String _formatMod(int mod) {
    if (mod >= 0) return '+$mod';
    return '$mod';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('快速检定'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ability', label: Text('属性')),
              ButtonSegment(value: 'save', label: Text('豁免')),
              ButtonSegment(value: 'skill', label: Text('技能')),
            ],
            selected: {_checkType},
            onSelectionChanged: (s) => setState(() => _checkType = s.single),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: '检定项'),
            child: DropdownButton<String>(
              value: _checkKey,
              items: _optionsFor(_checkType),
              onChanged: (v) {
                if (v != null) setState(() => _checkKey = v);
              },
              underline: const SizedBox.shrink(),
              isExpanded: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('dm-quick-check-dc'),
            controller: _dcController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'DC (可选)',
              hintText: '例如 15',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('dm-quick-check-roll'),
          onPressed: _roll,
          child: const Text('掷骰'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _optionsFor(String type) {
    if (type == 'skill') {
      return Dnd5eRules.skills
          .map((s) => DropdownMenuItem(value: s.name, child: Text(s.name)))
          .toList();
    }
    return Dnd5eRules.abilityLabels.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();
  }
}
