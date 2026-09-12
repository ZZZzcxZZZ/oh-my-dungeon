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

/// 法术步骤的**池渲染器**：既承担"职业 `classRules.spellcasting` 驱动"的自由
/// 挑选（[maximumCantrips] / [maximumLeveledSpells]），也承担**显式法术选择**
/// （`optionType: "spell"`，[maximum] = 该选择的有效上限）的法术池。
///
/// 候选由调用方给入：显式选择一律传
/// `RuleChoiceSemantics.candidatesFor` 的条目候选（与引擎同一份，绝不在这里
/// 再按标签 / 环阶过滤一遍——两套过滤不一致会让"选得进去、校验不过"变成静默阻塞）；
/// 职业驱动路径传 `SpellSelectionPolicy.eligibleSpells` 的结果。
///
/// 自定义法术属于 [CustomSpellSection]（不占规则选择上限），两条路径都渲染它。
class _SpellChoiceSection extends StatefulWidget {
  const _SpellChoiceSection({
    required this.entries,
    required this.selected,
    required this.onChanged,
    required this.onOpenEntry,
    this.title = '规则法术',
    this.hint,
    this.blockedReason,
    this.maximum,
    this.maximumCantrips,
    this.maximumLeveledSpells,
    this.maximumSpellLevel = 9,
    this.automaticRulesConfigured = true,
  });

  final List<ContentEntry> entries;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<ContentEntry> onOpenEntry;
  final String title;
  final String? hint;

  /// 选择级 `requires` 不满足时的原因文案（`null` = 满足）。不满足时**不渲染
  /// 候选**（与共享组件同语义，§3.10.3-5）；原因文案由 `ruleChoiceBlockedReason`
  /// 一处产出，这里只负责显示。
  final String? blockedReason;

  /// 整个池的总上限（显式法术选择的有效上限）。`null` = 用
  /// [maximumCantrips] / [maximumLeveledSpells] 的分类上限。
  final int? maximum;

  final int? maximumCantrips;
  final int? maximumLeveledSpells;
  final int maximumSpellLevel;
  final bool automaticRulesConfigured;

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
            Expanded(child: Text(widget.title, style: theme.textTheme.titleMedium)),
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
          widget.hint ??
              (!widget.automaticRulesConfigured
                  ? '该职业未提供自动法术规则；仍可在下方添加自定义法术。'
                  : '按职业列表与当前等级筛选，最高 ${widget.maximumSpellLevel} 环'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (widget.blockedReason case final String reason) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.block_outlined,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
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
              onChanged: _emit,
              onOpenEntry: widget.onOpenEntry,
            ),
        ],
      ],
    );
  }

  /// 池上限只有一处判断：`maximum`（显式法术选择的有效上限）。移除永远允许
  /// （`next.length` 只会变小），因此"超过上限"必然来自追加。
  void _emit(List<String> next) {
    if (widget.maximum case final int cap when next.length > cap) return;
    widget.onChanged(next);
  }

  static String _spellLevelLabel(int? level) {
    if (level == null) return '未分类';
    return level == 0 ? '戏法' : '$level 环';
  }

  String _selectionCountLabel({
    required int selectedCantrips,
    required int selectedLeveledSpells,
  }) {
    if (widget.maximum case final int cap) {
      return '已选 ${widget.selected.length}/$cap';
    }
    if (widget.maximumCantrips != null || widget.maximumLeveledSpells != null) {
      return '戏法 $selectedCantrips/${widget.maximumCantrips ?? '不限'}'
          ' · 法术 $selectedLeveledSpells/${widget.maximumLeveledSpells ?? '不限'}';
    }
    // 上限只有 `prepared` / `cantrips` 两列（§3.1/§3.3 原型不提供它们）；
    // 两列都未声明时没有可显示的上限，只报已选数量，不拿"未声明"当 0 或 20。
    return '已选 ${widget.selected.length}';
  }
}

/// 自定义法术（不占规则选择上限）：两条法术路径都渲染它。
class _CustomSpellSection extends StatelessWidget {
  const _CustomSpellSection({
    required this.customSpells,
    required this.onAddCustom,
    required this.onRemoveCustom,
  });

  final List<Map<String, Object?>> customSpells;
  final VoidCallback onAddCustom;
  final ValueChanged<int> onRemoveCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: Text('自定义法术', style: theme.textTheme.titleMedium)),
            FilledButton.tonalIcon(
              key: const Key('add-custom-spell'),
              onPressed: onAddCustom,
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
        for (var index = 0; index < customSpells.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text('${customSpells[index]['name']}'),
            subtitle: Text(
              _SpellChoiceSectionState._spellLevelLabel(
                customSpells[index]['level'] as int?,
              ),
            ),
            trailing: IconButton(
              tooltip: '移除自定义法术',
              onPressed: () => onRemoveCustom(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    );
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
  final List<String> selected;
  final int selectedCantrips;
  final int selectedLeveledSpells;
  final int? maximumCantrips;
  final int? maximumLeveledSpells;
  final ValueChanged<List<String>> onChanged;
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
        if (checked == true) {
          if (categoryAtLimit) return;
          onChanged(<String>[...selected, entry.id]);
        } else {
          onChanged(<String>[...selected]..remove(entry.id));
        }
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
