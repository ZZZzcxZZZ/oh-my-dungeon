import 'package:flutter/material.dart';

import '../../../content/data/local/content_repository.dart';
import '../../../content/domain/content_entry.dart';
import '../../domain/campaign_character.dart';
import '../campaign_event_dispatcher.dart';
import 'campaign_character_controller.dart';
import 'campaign_character_picker_sheet.dart';
import '../../../../core/presentation/dialog_sizes.dart';
import '../../../../core/widgets/empty_state.dart';

/// Task 3.4 — DM 快捷操作面板.
///
/// 三个原子操作参考 BG3 战斗日志:
///   1. 批量扣血/治疗 — 多选 Character + 数值 → `CampaignEventDispatcher.changeCharacterHp`
///   2. 给予装备 — 选 Character + 资料物品 → `CampaignEventDispatcher.grantItem`
///   3. 给予状态 — 选 Character + 状态 + 持续轮数
class DmQuickOpsSheet extends StatelessWidget {
  const DmQuickOpsSheet({
    required this.campaignId,
    required this.characterController,
    required this.eventDispatcher,
    this.contentRepository,
    super.key,
  });

  final String campaignId;
  final CampaignCharacterController characterController;
  final CampaignEventDispatcher eventDispatcher;
  final ContentRepository? contentRepository;

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
            '批量扣血、给予物品、给予状态',
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
            title: const Text('给予物品'),
            subtitle: const Text('检索资料库物品或输入自定义物品'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showGrantItemFlow(context),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: const Text('给予状态'),
            subtitle: const Text('添加常用或自定义状态，可记录持续轮数'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAddConditionFlow(context),
          ),
        ],
      ),
    );
  }

  /// 操作 1: 批量扣血/治疗.
  void _showBatchHpDialog(BuildContext context) {
    showHpOperation(
      context: context,
      campaignId: campaignId,
      characterController: characterController,
      eventDispatcher: eventDispatcher,
    );
  }

  static Future<void> showHpOperation({
    required BuildContext context,
    required String campaignId,
    required CampaignCharacterController characterController,
    required CampaignEventDispatcher eventDispatcher,
  }) {
    final characters = characterController.characters
        .where((a) => a.status == 'active')
        .toList(growable: false);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _BatchHpDialog(
        characters: characters,
        campaignId: campaignId,
        dispatcher: eventDispatcher,
      ),
    );
  }

  /// 操作 2: 给予装备.
  Future<void> _showGrantItemFlow(BuildContext context) async {
    await showGrantItemOperation(
      context: context,
      campaignId: campaignId,
      characterController: characterController,
      eventDispatcher: eventDispatcher,
      contentRepository: contentRepository,
    );
  }

  static Future<void> showGrantItemOperation({
    required BuildContext context,
    required String campaignId,
    required CampaignCharacterController characterController,
    required CampaignEventDispatcher eventDispatcher,
    ContentRepository? contentRepository,
  }) async {
    final characters = characterController.characters
        .where((a) => a.status == 'active')
        .toList(growable: false);
    final character = await showCampaignCharacterPickerSheet(
      context: context,
      title: '选择角色',
      characters: characters,
    );
    if (character == null || !context.mounted) return;

    var items = const <ContentEntry>[];
    if (contentRepository != null) {
      final entries = await contentRepository.search(const ContentQuery());
      items = entries
          .where((entry) => entry.type == 'equipment' || entry.type == 'item')
          .toList(growable: false);
    }
    if (!context.mounted) return;

    final item = await showDialog<_ItemSelection>(
      context: context,
      builder: (_) => _ItemPickerDialog(items: items),
    );
    if (item == null || !context.mounted) return;

    await eventDispatcher.grantItem(
      campaignId: campaignId,
      characterId: character.id,
      itemId: item.id,
      name: item.name,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已给 ${character.sheet['name']} ${item.name}')),
    );
  }

  /// 操作 3: 给予状态.
  Future<void> _showAddConditionFlow(BuildContext context) async {
    await showConditionOperation(
      context: context,
      campaignId: campaignId,
      characterController: characterController,
      eventDispatcher: eventDispatcher,
    );
  }

  static Future<void> showConditionOperation({
    required BuildContext context,
    required String campaignId,
    required CampaignCharacterController characterController,
    required CampaignEventDispatcher eventDispatcher,
  }) async {
    final characters = characterController.characters
        .where((a) => a.status == 'active')
        .toList(growable: false);
    final character = await showCampaignCharacterPickerSheet(
      context: context,
      title: '选择角色',
      characters: characters,
    );
    if (character == null || !context.mounted) return;

    final condition = await showDialog<_ConditionSelection>(
      context: context,
      builder: (_) => const _ConditionPickerDialog(),
    );
    if (condition == null || !context.mounted) return;

    await eventDispatcher.addCondition(
      campaignId: campaignId,
      characterId: character.id,
      type: condition.type,
      name: condition.name,
      durationRounds: condition.durationRounds,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已给 ${character.sheet['name']} 添加 ${condition.name}'),
      ),
    );
  }
}

/// 批量 HP 变更对话框.
class _BatchHpDialog extends StatefulWidget {
  const _BatchHpDialog({
    required this.characters,
    required this.campaignId,
    required this.dispatcher,
  });

  final List<CampaignCharacter> characters;
  final String campaignId;
  final CampaignEventDispatcher dispatcher;

  @override
  State<_BatchHpDialog> createState() => _BatchHpDialogState();
}

class _BatchHpDialogState extends State<_BatchHpDialog> {
  final Set<String> _selectedIds = {};
  final _deltaController = TextEditingController();
  _HpMode _mode = _HpMode.damage;
  bool _applying = false;

  @override
  void dispose() {
    _deltaController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final amount = int.tryParse(_deltaController.text.trim());
    if (amount == null || amount <= 0 || _selectedIds.isEmpty) return;
    final delta = _mode == _HpMode.damage ? -amount : amount;
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    var failures = 0;
    for (final characterId in _selectedIds.toList()) {
      try {
        await widget.dispatcher.changeCharacterHp(
          campaignId: widget.campaignId,
          characterId: characterId,
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
              ? '已对 ${_selectedIds.length} 个角色应用 ${_mode == _HpMode.heal ? '治疗' : '伤害'} $amount'
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
                itemCount: widget.characters.length,
                itemBuilder: (context, index) {
                  final character = widget.characters[index];
                  final name = character.sheet['name']?.toString() ?? '未命名';
                  final hp = character.sheet['currentHp'];
                  final maxHp = character.sheet['maxHp'];
                  return CheckboxListTile(
                    value: _selectedIds.contains(character.id),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(character.id);
                        } else {
                          _selectedIds.remove(character.id);
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
            SegmentedButton<_HpMode>(
              segments: const [
                ButtonSegment(
                  value: _HpMode.damage,
                  icon: Icon(Icons.heart_broken_outlined),
                  label: Text('伤害'),
                ),
                ButtonSegment(
                  value: _HpMode.heal,
                  icon: Icon(Icons.healing_outlined),
                  label: Text('治疗'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() => _mode = value.single);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('dm-batch-hp-delta'),
              controller: _deltaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数值',
                hintText: '输入正整数，例如 5',
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

enum _HpMode { damage, heal }

class _ConditionSelection {
  const _ConditionSelection({
    required this.type,
    required this.name,
    this.durationRounds,
  });

  final String type;
  final String name;
  final int? durationRounds;
}

class _ConditionPreset {
  const _ConditionPreset(this.type, this.name);

  final String type;
  final String name;
}

const _conditionPresets = <_ConditionPreset>[
  _ConditionPreset('poisoned', '中毒'),
  _ConditionPreset('prone', '倒地'),
  _ConditionPreset('frightened', '恐慌'),
  _ConditionPreset('stunned', '震慑'),
  _ConditionPreset('restrained', '束缚'),
  _ConditionPreset('unconscious', '昏迷'),
  _ConditionPreset('concentrating', '专注'),
];

class _ConditionPickerDialog extends StatefulWidget {
  const _ConditionPickerDialog();

  @override
  State<_ConditionPickerDialog> createState() => _ConditionPickerDialogState();
}

class _ConditionPickerDialogState extends State<_ConditionPickerDialog> {
  final _durationController = TextEditingController();
  final _customController = TextEditingController();
  _ConditionPreset? _selected;

  @override
  void dispose() {
    _durationController.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _submit() {
    final customName = _customController.text.trim();
    if (_selected == null && customName.isEmpty) return;
    final duration = int.tryParse(_durationController.text.trim());
    final preset = _selected;
    Navigator.of(context).pop(
      _ConditionSelection(
        type: preset?.type ?? 'custom',
        name: preset?.name ?? customName,
        durationRounds: duration != null && duration > 0 ? duration : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('给予状态'),
      content: SizedBox(
        width: DialogSizes.narrow,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('常用状态', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _conditionPresets)
                    FilterChip(
                      label: Text(preset.name),
                      selected: _selected == preset,
                      onSelected: (selected) {
                        setState(() {
                          _selected = selected ? preset : null;
                          if (selected) _customController.clear();
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customController,
                decoration: const InputDecoration(
                  labelText: '自定义状态',
                  hintText: '例如：受祝福',
                ),
                onChanged: (value) {
                  setState(() {
                    if (value.trim().isNotEmpty) _selected = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('dm-condition-duration'),
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '持续轮数（可选）',
                  hintText: '留空表示不自动计时',
                ),
              ),
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
          key: const Key('dm-condition-apply'),
          onPressed:
              _selected != null || _customController.text.trim().isNotEmpty
              ? _submit
              : null,
          child: const Text('应用'),
        ),
      ],
    );
  }
}

class _ItemSelection {
  const _ItemSelection({required this.id, required this.name});

  final String id;
  final String name;
}

/// Searchable item picker with an escape hatch for table-specific objects.
class _ItemPickerDialog extends StatefulWidget {
  const _ItemPickerDialog({required this.items});

  final List<ContentEntry> items;

  @override
  State<_ItemPickerDialog> createState() => _ItemPickerDialogState();
}

class _ItemPickerDialogState extends State<_ItemPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final visible = widget.items
        .where(
          (item) =>
              normalized.isEmpty ||
              item.name.toLowerCase().contains(normalized) ||
              item.tags.any((tag) => tag.toLowerCase().contains(normalized)),
        )
        .toList(growable: false);
    return AlertDialog(
      title: const Text('选择物品'),
      content: SizedBox(
        width: DialogSizes.compact,
        height: DialogSizes.pickerHeight,
        child: Column(
          children: [
            SearchBar(
              key: const Key('dm-item-search'),
              controller: _searchController,
              hintText: '搜索名称或标签',
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: '清除搜索',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('dm-custom-item'),
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('自定义物品'),
              subtitle: const Text('直接输入这次要给予的物品名称'),
              onTap: _createCustomItem,
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const EmptyState(icon: Icons.search_off, title: '没有匹配的物品')
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.source.label),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_ItemSelection(id: item.id, name: item.name)),
                        );
                      },
                    ),
            ),
          ],
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

  Future<void> _createCustomItem() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CustomItemDialog(),
    );
    if (name == null || !mounted) return;
    Navigator.of(context).pop(
      _ItemSelection(
        id: 'custom:${DateTime.now().microsecondsSinceEpoch}',
        name: name,
      ),
    );
  }
}

class _CustomItemDialog extends StatefulWidget {
  const _CustomItemDialog();

  @override
  State<_CustomItemDialog> createState() => _CustomItemDialogState();
}

class _CustomItemDialogState extends State<_CustomItemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义物品'),
      content: TextField(
        key: const Key('dm-custom-item-name'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '物品名称',
          hintText: '例如：酒馆钥匙',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('dm-custom-item-confirm'),
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('给予'),
        ),
      ],
    );
  }
}
