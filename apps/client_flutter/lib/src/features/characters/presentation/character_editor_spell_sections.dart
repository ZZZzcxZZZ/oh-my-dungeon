// character_editor_page.dart 的 part：法术选择、自定义法术对话框与装备预算摘要。
part of 'character_editor_page.dart';

class _CustomSpellDialog extends StatefulWidget {
  const _CustomSpellDialog();

  @override
  State<_CustomSpellDialog> createState() => _CustomSpellDialogState();
}

class _CustomSpellDialogState extends State<_CustomSpellDialog> {
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _level = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加自定义法术'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('custom-spell-name'),
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            DropdownMenu<int>(
              key: const Key('custom-spell-level'),
              initialSelection: _level,
              label: const Text('环位'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                for (var value = 0; value <= 9; value++)
                  DropdownMenuEntry(
                    value: value,
                    label: value == 0 ? '戏法' : '$value 环',
                  ),
              ],
              onSelected: (value) {
                if (value != null) setState(() => _level = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _schoolController,
              decoration: const InputDecoration(labelText: '学派（可选）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '说明（可选）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('custom-spell-confirm'),
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop({
              'id': 'custom-spell-${DateTime.now().microsecondsSinceEpoch}',
              'name': name,
              'level': _level,
              'school': _schoolController.text.trim(),
              'description': _descriptionController.text.trim(),
            });
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}

class _SpellChoiceSection extends StatefulWidget {
  const _SpellChoiceSection({
    required this.entries,
    required this.selected,
    required this.onChanged,
    required this.maximumCantrips,
    required this.maximumLeveledSpells,
    required this.maximumSpellLevel,
    required this.automaticRulesConfigured,
    required this.customSpells,
    required this.onAddCustom,
    required this.onRemoveCustom,
    required this.onOpenEntry,
  });

  final List<ContentEntry> entries;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final int? maximumCantrips;
  final int? maximumLeveledSpells;
  final int maximumSpellLevel;
  final bool automaticRulesConfigured;
  final List<Map<String, Object?>> customSpells;
  final VoidCallback onAddCustom;
  final ValueChanged<int> onRemoveCustom;
  final ValueChanged<ContentEntry> onOpenEntry;

  @override
  State<_SpellChoiceSection> createState() => _SpellChoiceSectionState();
}

class _SpellChoiceSectionState extends State<_SpellChoiceSection> {
  final _searchController = TextEditingController();
  int? _level;
  String? _school;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schools =
        widget.entries
            .map(SpellSelectionPolicy.spellSchool)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.entries
        .where((entry) {
          final level = SpellSelectionPolicy.spellLevel(entry);
          if (_level != null && level != _level) return false;
          if (_school != null &&
              SpellSelectionPolicy.spellSchool(entry) != _school) {
            return false;
          }
          return query.isEmpty ||
              entry.name.toLowerCase().contains(query) ||
              entry.aliases.any((alias) => alias.toLowerCase().contains(query));
        })
        .toList(growable: false);
    final selectedCantrips = widget.selected.where((id) {
      final entry = widget.entries.where((entry) => entry.id == id).firstOrNull;
      return entry != null && SpellSelectionPolicy.spellLevel(entry) == 0;
    }).length;
    final selectedLeveledSpells = widget.selected.length - selectedCantrips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('规则法术', style: theme.textTheme.titleMedium)),
            Text(
              _selectionCountLabel(
                selectedCantrips: selectedCantrips,
                selectedLeveledSpells: selectedLeveledSpells,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          !widget.automaticRulesConfigured
              ? '该职业未提供自动法术规则；仍可在下方添加自定义法术。'
              : '按职业列表与当前等级筛选，最高 ${widget.maximumSpellLevel} 环',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('spell-choice-search'),
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: '搜索法术',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DropdownMenu<int?>(
              key: const Key('spell-choice-level-filter'),
              initialSelection: _level,
              label: const Text('环位'),
              width: 136,
              dropdownMenuEntries: [
                const DropdownMenuEntry(value: null, label: '全部环位'),
                for (var value = 0; value <= widget.maximumSpellLevel; value++)
                  DropdownMenuEntry(
                    value: value,
                    label: value == 0 ? '戏法' : '$value 环',
                  ),
              ],
              onSelected: (value) => setState(() => _level = value),
            ),
            if (schools.isNotEmpty)
              DropdownMenu<String?>(
                key: const Key('spell-choice-school-filter'),
                initialSelection: _school,
                label: const Text('学派'),
                width: 160,
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: '全部学派'),
                  for (final school in schools)
                    DropdownMenuEntry(value: school, label: school),
                ],
                onSelected: (value) => setState(() => _school = value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Text(widget.entries.isEmpty ? '没有符合当前职业与等级的规则法术。' : '没有符合筛选条件的法术。')
        else
          for (final entry in filtered)
            _SpellOptionTile(
              entry: entry,
              selected: widget.selected,
              selectedCantrips: selectedCantrips,
              selectedLeveledSpells: selectedLeveledSpells,
              maximumCantrips: widget.maximumCantrips,
              maximumLeveledSpells: widget.maximumLeveledSpells,
              onChanged: widget.onChanged,
              onOpenEntry: widget.onOpenEntry,
            ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: Text('自定义法术', style: theme.textTheme.titleMedium)),
            FilledButton.tonalIcon(
              key: const Key('add-custom-spell'),
              onPressed: widget.onAddCustom,
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '自定义法术不计入规则选择上限。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (var index = 0; index < widget.customSpells.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text('${widget.customSpells[index]['name']}'),
            subtitle: Text(
              _spellLevelLabel(widget.customSpells[index]['level'] as int?),
            ),
            trailing: IconButton(
              tooltip: '移除自定义法术',
              onPressed: () => widget.onRemoveCustom(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    );
  }

  static String _spellLevelLabel(int? level) {
    if (level == null) return '未分类';
    return level == 0 ? '戏法' : '$level 环';
  }

  String _selectionCountLabel({
    required int selectedCantrips,
    required int selectedLeveledSpells,
  }) {
    if (widget.maximumCantrips != null || widget.maximumLeveledSpells != null) {
      return '戏法 $selectedCantrips/${widget.maximumCantrips ?? '不限'}'
          ' · 法术 $selectedLeveledSpells/${widget.maximumLeveledSpells ?? '不限'}';
    }
    // 上限只有 `prepared` / `cantrips` 两列（§3.1/§3.3 原型不提供它们）；
    // 两列都未声明时没有可显示的上限，只报已选数量，不拿"未声明"当 0 或 20。
    return '已选 ${widget.selected.length}';
  }
}

class _SpellOptionTile extends StatelessWidget {
  const _SpellOptionTile({
    required this.entry,
    required this.selected,
    required this.selectedCantrips,
    required this.selectedLeveledSpells,
    required this.maximumCantrips,
    required this.maximumLeveledSpells,
    required this.onChanged,
    required this.onOpenEntry,
  });

  final ContentEntry entry;
  final Set<String> selected;
  final int selectedCantrips;
  final int selectedLeveledSpells;
  final int? maximumCantrips;
  final int? maximumLeveledSpells;
  final ValueChanged<Set<String>> onChanged;
  final ValueChanged<ContentEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected.contains(entry.id);
    final isCantrip = SpellSelectionPolicy.spellLevel(entry) == 0;
    final categoryMaximum = isCantrip ? maximumCantrips : maximumLeveledSpells;
    final categorySelected = isCantrip
        ? selectedCantrips
        : selectedLeveledSpells;
    // 上限只有 `prepared` / `cantrips` 两列；两列都未声明时不设上限
    // （不拿"未声明"当 0）。
    final categoryAtLimit =
        categoryMaximum != null && categorySelected >= categoryMaximum;

    return CheckboxListTile(
      key: Key('spell-choice-${entry.id}'),
      contentPadding: EdgeInsets.zero,
      value: isSelected,
      enabled: isSelected || !categoryAtLimit,
      title: Text(entry.name),
      subtitle: Text(
        '${_SpellChoiceSectionState._spellLevelLabel(SpellSelectionPolicy.spellLevel(entry))}'
        '${SpellSelectionPolicy.spellSchool(entry).isEmpty ? '' : ' · ${SpellSelectionPolicy.spellSchool(entry)}'}',
      ),
      secondary: IconButton(
        tooltip: '查看${entry.name}',
        onPressed: () => onOpenEntry(entry),
        icon: const Icon(Icons.open_in_new),
      ),
      onChanged: (checked) {
        final next = Set<String>.from(selected);
        if (checked == true) {
          if (!categoryAtLimit) next.add(entry.id);
        } else {
          next.remove(entry.id);
        }
        onChanged(next);
      },
    );
  }
}

class _EquipmentBudgetSummary extends StatelessWidget {
  const _EquipmentBudgetSummary({
    required this.startingEquipment,
    required this.selectedNames,
    required this.entries,
  });

  final Object? startingEquipment;
  final Set<String> selectedNames;
  final List<ContentEntry> entries;

  @override
  Widget build(BuildContext context) {
    final budget = EquipmentCost.suggestedBudget(startingEquipment);
    var total = const EquipmentCost(0);
    var unpriced = 0;
    for (final name in selectedNames) {
      final entry = entries
          .where((candidate) => candidate.name.trim() == name.trim())
          .firstOrNull;
      final price = EquipmentCost.parse(entry?.structured['price']);
      if (price == null) {
        unpriced++;
      } else {
        total += price;
      }
    }
    final overBudget =
        budget != null && total.copperPieces > budget.copperPieces;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: overBudget ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                overBudget ? Icons.info_outline : Icons.paid_outlined,
                color: overBudget
                    ? colors.onErrorContainer
                    : colors.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                // Text rows sit on a secondaryContainer/errorContainer
                // surface, so they must use the matching on-* role (E2).
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: overBudget
                        ? colors.onErrorContainer
                        : colors.onSecondaryContainer,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已选总价 ${total.format()}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (budget != null) Text('建议金币上限 ${budget.format()}'),
                      if (unpriced > 0) Text('$unpriced 件自定义或资料物品未标价'),
                      if (overBudget) const Text('已超出建议上限，仍可继续创建和购买。'),
                    ],
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
