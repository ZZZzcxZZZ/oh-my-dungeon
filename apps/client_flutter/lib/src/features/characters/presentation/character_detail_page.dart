import 'package:flutter/material.dart';

import '../../rooms/domain/dice_roller.dart';
import '../domain/character.dart';
import '../domain/dnd5e_rules.dart';

typedef CharacterRuntimeUpdate =
    Future<void> Function({
      int? currentHp,
      int? temporaryHp,
      bool? inspiration,
      List<String>? conditions,
      int? deathSaveSuccesses,
      int? deathSaveFailures,
      Map<String, int>? spellSlotsUsed,
      Map<String, int>? classResourcesUsed,
    });

typedef CharacterInventoryUpdate =
    Future<void> Function({
      List<Map<String, Object>>? inventory,
      Map<String, int>? currency,
    });

typedef CharacterRollCallback = void Function(CharacterRollEvent event);

class CharacterRollEvent {
  const CharacterRollEvent({
    required this.label,
    required this.notation,
    required this.total,
    required this.summary,
  });

  final String label;
  final String notation;
  final int total;
  final String summary;
}

class CharacterDetailPage extends StatelessWidget {
  const CharacterDetailPage({
    required this.character,
    this.onEdit,
    this.onUpdateRuntime,
    this.onUpdateInventory,
    this.diceRoller,
    this.onRoll,
    this.initialTab = 'overview',
    super.key,
  });

  final CharacterSheet character;
  final VoidCallback? onEdit;
  final CharacterRuntimeUpdate? onUpdateRuntime;
  final CharacterInventoryUpdate? onUpdateInventory;
  final DiceRoller? diceRoller;
  final CharacterRollCallback? onRoll;
  final String initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      initialIndex: _initialTabIndex(initialTab),
      child: Scaffold(
        appBar: AppBar(
          title: Text(character.name),
          actions: [
            if (onEdit != null)
              IconButton(
                tooltip: '编辑角色',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CharacterHeader(character: character),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '属性'),
                Tab(text: '动作'),
                Tab(text: '法术'),
                Tab(text: '装备'),
                Tab(text: '状态'),
                Tab(text: '特性'),
                Tab(text: '详情'),
                Tab(text: '笔记'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SheetTab(child: _AbilityOverview(character: character)),
                  _SheetTab(
                    child: _ActionsPanel(
                      character: character,
                      diceRoller: diceRoller,
                      onRoll: onRoll,
                    ),
                  ),
                  _SheetTab(
                    child: _SpellsPanel(
                      character: character,
                      onUpdateRuntime: onUpdateRuntime,
                    ),
                  ),
                  _SheetTab(
                    child: _EquipmentPanel(
                      character: character,
                      onUpdateInventory: onUpdateInventory,
                    ),
                  ),
                  _SheetTab(
                    child: _RuntimePanel(
                      character: character,
                      onUpdateRuntime: onUpdateRuntime,
                    ),
                  ),
                  const _SheetTab(child: _EmptyPanel(title: '暂无特性引用')),
                  _SheetTab(child: _DetailsPanel(character: character)),
                  _SheetTab(child: _NotesPanel(character: character)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _initialTabIndex(String tab) {
    return switch (tab) {
      'actions' => 1,
      'spells' => 2,
      'equipment' => 3,
      'status' => 4,
      'features' => 5,
      'details' => 6,
      'notes' => 7,
      _ => 0,
    };
  }
}

class _CharacterHeader extends StatelessWidget {
  const _CharacterHeader({required this.character});

  final CharacterSheet character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (character.raceSummary.isNotEmpty) character.raceSummary,
      if (character.classSummary.isNotEmpty) character.classSummary,
      'Lv.${character.level}',
    ].join(' / ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(character.name.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(character.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(label: 'HP ${character.currentHp}/${character.maxHp}'),
              _StatChip(label: 'AC ${character.armorClass}'),
              _StatChip(
                label:
                    '先攻 ${Dnd5eRules.formatModifier(character.initiativeBonus)}',
              ),
              _StatChip(label: '速度 ${character.speed} 尺'),
              _StatChip(
                label: '熟练 +${Dnd5eRules.proficiencyBonus(character.level)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetTab extends StatelessWidget {
  const _SheetTab({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: child,
        ),
      ),
    );
  }
}

class _AbilityOverview extends StatelessWidget {
  const _AbilityOverview({required this.character});

  final CharacterSheet character;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '属性',
          icon: Icons.tune_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in Dnd5eRules.abilityLabels.entries)
                _AbilityTile(
                  label: entry.value,
                  score: Dnd5eRules.abilityScore(
                    character.abilityMap,
                    entry.key,
                  ),
                ),
            ],
          ),
        ),
        _Section(
          title: '豁免',
          icon: Icons.shield_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in Dnd5eRules.abilityLabels.entries)
                _RollChip(
                  label: entry.value,
                  value: Dnd5eRules.saveBonus(
                    ability: entry.key,
                    abilities: character.abilityMap,
                    level: character.level,
                    proficient: character.saveMap[entry.key] == true,
                  ),
                  proficient: character.saveMap[entry.key] == true,
                ),
            ],
          ),
        ),
        _Section(
          title: '技能',
          icon: Icons.checklist_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in Dnd5eRules.skills)
                _RollChip(
                  label: skill.name,
                  value: Dnd5eRules.skillBonus(
                    skillName: skill.name,
                    abilities: character.abilityMap,
                    level: character.level,
                    proficient: character.skillMap[skill.name] == true,
                  ),
                  proficient: character.skillMap[skill.name] == true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionsPanel extends StatefulWidget {
  const _ActionsPanel({required this.character, this.diceRoller, this.onRoll});

  final CharacterSheet character;
  final DiceRoller? diceRoller;
  final CharacterRollCallback? onRoll;

  @override
  State<_ActionsPanel> createState() => _ActionsPanelState();
}

class _ActionsPanelState extends State<_ActionsPanel> {
  _D20RollMode _rollMode = _D20RollMode.normal;

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final attacks = _deriveWeaponAttacks(character);
    final spellSaveDc = Dnd5eRules.spellSaveDc(
      classSummary: character.classSummary,
      abilities: character.abilityMap,
      level: character.level,
    );
    final roller = widget.diceRoller ?? DiceRoller();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '掷骰模式',
          icon: Icons.casino_outlined,
          child: SegmentedButton<_D20RollMode>(
            segments: const [
              ButtonSegment(value: _D20RollMode.normal, label: Text('普通')),
              ButtonSegment(value: _D20RollMode.advantage, label: Text('优势')),
              ButtonSegment(
                value: _D20RollMode.disadvantage,
                label: Text('劣势'),
              ),
            ],
            selected: {_rollMode},
            onSelectionChanged: (selection) {
              setState(() => _rollMode = selection.single);
            },
          ),
        ),
        _Section(
          title: '常用检定',
          icon: Icons.bolt_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RollChip(
                label: '先攻',
                value: character.initiativeBonus,
                proficient: false,
                diceRoller: roller,
                rollMode: _rollMode,
                onRoll: widget.onRoll,
              ),
              _RollChip(
                label: '察觉',
                value: Dnd5eRules.skillBonus(
                  skillName: '察觉',
                  abilities: character.abilityMap,
                  level: character.level,
                  proficient: character.skillMap['察觉'] == true,
                ),
                proficient: character.skillMap['察觉'] == true,
                diceRoller: roller,
                rollMode: _rollMode,
                onRoll: widget.onRoll,
              ),
              _RollChip(
                label: '隐匿',
                value: Dnd5eRules.skillBonus(
                  skillName: '隐匿',
                  abilities: character.abilityMap,
                  level: character.level,
                  proficient: character.skillMap['隐匿'] == true,
                ),
                proficient: character.skillMap['隐匿'] == true,
                diceRoller: roller,
                rollMode: _rollMode,
                onRoll: widget.onRoll,
              ),
            ],
          ),
        ),
        _Section(
          title: '攻击动作',
          icon: Icons.gps_fixed_outlined,
          child: attacks.isEmpty
              ? Text('暂无可识别武器', style: Theme.of(context).textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final attack in attacks)
                      _AttackActionLine(
                        attack: attack,
                        diceRoller: roller,
                        rollMode: _rollMode,
                        onRoll: widget.onRoll,
                      ),
                  ],
                ),
        ),
        if (spellSaveDc != null)
          _Section(
            title: '施法',
            icon: Icons.auto_fix_high_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('法术豁免 DC $spellSaveDc')),
                Chip(
                  label: Text(
                    '施法加值 ${Dnd5eRules.formatModifier(spellSaveDc - 8)}',
                  ),
                ),
              ],
            ),
          ),
        _Section(
          title: '附赠动作',
          icon: Icons.flash_on_outlined,
          child: Text(
            '职业、法术和物品提供的附赠动作会显示在这里。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _Section(
          title: '反应',
          icon: Icons.reply_outlined,
          child: Text(
            '借机攻击、护盾术和其他反应会显示在这里。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

enum _D20RollMode { normal, advantage, disadvantage }

class _D20RollResult {
  const _D20RollResult({
    required this.label,
    required this.notation,
    required this.total,
  });

  final String label;
  final String notation;
  final int total;
}

_D20RollResult _rollD20WithMode({
  required DiceRoller diceRoller,
  required _D20RollMode mode,
  required int modifier,
}) {
  final formattedModifier = Dnd5eRules.formatModifier(modifier);
  if (mode == _D20RollMode.normal) {
    final roll = diceRoller.rollD20().total;
    final notation = 'd20$formattedModifier';
    return _D20RollResult(
      label: '$notation = ${roll + modifier}',
      notation: notation,
      total: roll + modifier,
    );
  }

  final first = diceRoller.rollD20().total;
  final second = diceRoller.rollD20().total;
  final selected = mode == _D20RollMode.advantage
      ? (first > second ? first : second)
      : (first < second ? first : second);
  final modeLabel = mode == _D20RollMode.advantage ? '优势' : '劣势';
  final notation = '$modeLabel d20($first, $second)$formattedModifier';
  return _D20RollResult(
    label: '$notation = ${selected + modifier}',
    notation: notation,
    total: selected + modifier,
  );
}

class _AttackActionLine extends StatelessWidget {
  const _AttackActionLine({
    required this.attack,
    required this.diceRoller,
    required this.rollMode,
    this.onRoll,
  });

  final _WeaponAttackAction attack;
  final DiceRoller diceRoller;
  final _D20RollMode rollMode;
  final CharacterRollCallback? onRoll;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.gps_fixed_outlined),
      title: Text(attack.name),
      subtitle: Text(attack.damage),
      onTap: () => _showAttackRoll(context),
      trailing: Text(
        attack.toHit,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  void _showAttackRoll(BuildContext context) {
    final attackRoll = _rollD20WithMode(
      diceRoller: diceRoller,
      mode: rollMode,
      modifier: attack.bonus,
    );
    final damageRoll = diceRoller.rollExpression(attack.damageFormula);
    final summary =
        '${attack.name}：${attackRoll.label}，伤害 ${attack.damageFormula} = ${damageRoll.total} ${attack.damageType}';
    onRoll?.call(
      CharacterRollEvent(
        label: attack.name,
        notation: '${attackRoll.notation} / ${attack.damageFormula}',
        total: attackRoll.total + damageRoll.total,
        summary: summary,
      ),
    );
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(summary)));
  }
}

class _WeaponAttackAction {
  const _WeaponAttackAction({
    required this.name,
    required this.bonus,
    required this.toHit,
    required this.damage,
    required this.damageFormula,
    required this.damageType,
  });

  final String name;
  final int bonus;
  final String toHit;
  final String damage;
  final String damageFormula;
  final String damageType;
}

List<_WeaponAttackAction> _deriveWeaponAttacks(CharacterSheet character) {
  final attacks = <_WeaponAttackAction>[];
  for (final item in _normalizeInventory(character.inventoryList)) {
    final itemName = item['name']?.toString() ?? '';
    final weapon = Dnd5eRules.weaponProfile(itemName);
    if (weapon == null) continue;
    final attackBonus = Dnd5eRules.attackBonus(
      abilities: character.abilityMap,
      level: character.level,
      ability: weapon.ability,
    );
    final damageFormula = Dnd5eRules.damageFormula(
      weapon,
      character.abilityMap,
    );
    attacks.add(
      _WeaponAttackAction(
        name: weapon.name,
        bonus: attackBonus,
        toHit: '${Dnd5eRules.formatModifier(attackBonus)} 命中',
        damage: '$damageFormula ${weapon.damageType}',
        damageFormula: damageFormula,
        damageType: weapon.damageType,
      ),
    );
  }
  return attacks;
}

class _SpellsPanel extends StatefulWidget {
  const _SpellsPanel({required this.character, this.onUpdateRuntime});

  final CharacterSheet character;
  final CharacterRuntimeUpdate? onUpdateRuntime;

  @override
  State<_SpellsPanel> createState() => _SpellsPanelState();
}

class _SpellsPanelState extends State<_SpellsPanel> {
  late Map<String, int> _slotsUsed;

  @override
  void initState() {
    super.initState();
    _syncFromCharacter();
  }

  @override
  void didUpdateWidget(covariant _SpellsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) {
      _syncFromCharacter();
    }
  }

  void _syncFromCharacter() {
    final maximums = _slotMaximums();
    _slotsUsed = {
      for (final entry in maximums.entries)
        entry.key: (widget.character.spellSlotsUsed[entry.key] ?? 0)
            .clamp(0, entry.value)
            .toInt(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ability = Dnd5eRules.spellcastingAbility(
      widget.character.classSummary,
    );
    final slotMaximums = _slotMaximums();
    final spellRefs = widget.character.spellRefs;

    if (ability == null && slotMaximums.isEmpty && spellRefs.isEmpty) {
      return const _EmptyPanel(title: '暂无法术引用');
    }

    final abilityLabel = ability == null
        ? '无'
        : Dnd5eRules.abilityLabels[ability] ?? ability;
    final saveDc = Dnd5eRules.spellSaveDc(
      classSummary: widget.character.classSummary,
      abilities: widget.character.abilityMap,
      level: widget.character.level,
    );
    final spellAttack = saveDc == null ? null : saveDc - 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '施法概览',
          icon: Icons.auto_fix_high_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('施法属性 $abilityLabel')),
              if (saveDc != null) Chip(label: Text('法术豁免 DC $saveDc')),
              if (spellAttack != null)
                Chip(
                  label: Text('法术攻击 ${Dnd5eRules.formatModifier(spellAttack)}'),
                ),
            ],
          ),
        ),
        _Section(
          title: '法术位',
          icon: Icons.hourglass_bottom_outlined,
          child: slotMaximums.isEmpty
              ? Text('暂无法术位', style: Theme.of(context).textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final entry in _sortedSlotEntries(slotMaximums))
                      _SpellSlotLine(
                        level: entry.key,
                        used: _slotsUsed[entry.key] ?? 0,
                        maximum: entry.value,
                        onConsume: () => _adjustSlot(entry.key, 1),
                        onRecover: () => _adjustSlot(entry.key, -1),
                      ),
                  ],
                ),
        ),
        _Section(
          title: '已绑定法术',
          icon: Icons.menu_book_outlined,
          child: spellRefs.isEmpty
              ? Text(
                  '还没有绑定法术。可以在角色列表中维护法术 ID，后续会接入资料库选择器。',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final spell in spellRefs)
                      InputChip(
                        avatar: const Icon(Icons.auto_fix_high, size: 18),
                        label: Text(spell),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Map<String, int> _slotMaximums() {
    return Dnd5eRules.spellSlotMaximums(
      classSummary: widget.character.classSummary,
      level: widget.character.level,
    );
  }

  Future<void> _adjustSlot(String level, int delta) async {
    final maximum = _slotMaximums()[level] ?? 0;
    final current = _slotsUsed[level] ?? 0;
    final next = Map<String, int>.from(_slotsUsed);
    next[level] = (current + delta).clamp(0, maximum).toInt();
    setState(() => _slotsUsed = next);
    await widget.onUpdateRuntime?.call(
      spellSlotsUsed: Map.unmodifiable(_slotsUsed),
    );
  }
}

class _SpellSlotLine extends StatelessWidget {
  const _SpellSlotLine({
    required this.level,
    required this.used,
    required this.maximum,
    required this.onConsume,
    required this.onRecover,
  });

  final String level;
  final int used;
  final int maximum;
  final VoidCallback onConsume;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final label = Dnd5eRules.spellLevelLabel(level);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.auto_awesome_outlined),
      title: Text('$label $used/$maximum 已用'),
      subtitle: LinearProgressIndicator(
        value: maximum == 0 ? 0 : used / maximum,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '恢复$label法术位',
            onPressed: used <= 0 ? null : onRecover,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: '消耗$label法术位',
            onPressed: used >= maximum ? null : onConsume,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

List<MapEntry<String, int>> _sortedSlotEntries(Map<String, int> slots) {
  final entries = slots.entries.toList();
  entries.sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
  return entries;
}

class _EquipmentPanel extends StatefulWidget {
  const _EquipmentPanel({required this.character, this.onUpdateInventory});

  final CharacterSheet character;
  final CharacterInventoryUpdate? onUpdateInventory;

  @override
  State<_EquipmentPanel> createState() => _EquipmentPanelState();
}

class _EquipmentPanelState extends State<_EquipmentPanel> {
  late List<Map<String, Object>> _inventory;
  late Map<String, int> _currency;

  @override
  void initState() {
    super.initState();
    _syncFromCharacter();
  }

  @override
  void didUpdateWidget(covariant _EquipmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) {
      _syncFromCharacter();
    }
  }

  void _syncFromCharacter() {
    _inventory = _normalizeInventory(widget.character.inventoryList);
    _currency = _normalizeCurrency(widget.character.currencyMap);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '装备',
          icon: Icons.inventory_2_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_inventory.isEmpty)
                Text('暂无装备', style: Theme.of(context).textTheme.bodyMedium)
              else
                for (var index = 0; index < _inventory.length; index++)
                  _InventoryLine(
                    item: _inventory[index],
                    onIncrement: () => _adjustInventoryQuantity(index, 1),
                    onDecrement: () => _adjustInventoryQuantity(index, -1),
                    onConsume: _isConsumable(_inventory[index])
                        ? () => _adjustInventoryQuantity(index, -1)
                        : null,
                  ),
            ],
          ),
        ),
        _Section(
          title: '货币',
          icon: Icons.paid_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_currency.isEmpty)
                Text('暂无货币记录', style: Theme.of(context).textTheme.bodyMedium)
              else
                for (final entry in _currency.entries)
                  _CurrencyControl(
                    code: entry.key,
                    value: entry.value,
                    onIncrement: () => _adjustCurrency(entry.key, 1),
                    onDecrement: () => _adjustCurrency(entry.key, -1),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _adjustInventoryQuantity(int index, int delta) async {
    final next = _inventory
        .map((item) => Map<String, Object>.from(item))
        .toList();
    final item = next[index];
    final current = _intValue(item['quantity'], fallback: 1);
    item['quantity'] = (current + delta).clamp(0, 999);
    setState(() => _inventory = next);
    await widget.onUpdateInventory?.call(inventory: _snapshotInventory());
  }

  Future<void> _adjustCurrency(String code, int delta) async {
    final next = Map<String, int>.from(_currency);
    final current = next[code] ?? 0;
    next[code] = (current + delta).clamp(0, 999999);
    setState(() => _currency = next);
    await widget.onUpdateInventory?.call(currency: Map.unmodifiable(_currency));
  }

  List<Map<String, Object>> _snapshotInventory() {
    return _inventory
        .map((item) => Map<String, Object>.unmodifiable(item))
        .toList(growable: false);
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.character});

  final CharacterSheet character;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '详情',
          icon: Icons.badge_outlined,
          child: Column(
            children: [
              _DetailLine(label: '系统', value: character.system),
              _DetailLine(label: '职业', value: character.classSummary),
              _DetailLine(label: '种族', value: character.raceSummary),
              _DetailLine(label: '等级', value: '${character.level}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _RuntimePanel extends StatefulWidget {
  const _RuntimePanel({required this.character, this.onUpdateRuntime});

  final CharacterSheet character;
  final CharacterRuntimeUpdate? onUpdateRuntime;

  @override
  State<_RuntimePanel> createState() => _RuntimePanelState();
}

class _RuntimePanelState extends State<_RuntimePanel> {
  final _hpDeltaController = TextEditingController(text: '1');
  final _conditionSearchController = TextEditingController();

  static const _commonConditions = [
    '失明',
    '魅惑',
    '耳聋',
    '恐慌',
    '擒抱',
    '失能',
    '隐形',
    '麻痹',
    '石化',
    '中毒',
    '倒地',
    '束缚',
    '震慑',
    '昏迷',
    '力竭 1',
    '力竭 2',
    '力竭 3',
    '力竭 4',
    '力竭 5',
    '力竭 6',
  ];

  late int _currentHp;
  late int _temporaryHp;
  late bool _inspiration;
  late List<String> _conditions;
  late int _deathSaveSuccesses;
  late int _deathSaveFailures;
  late Map<String, int> _classResourcesUsed;

  @override
  void initState() {
    super.initState();
    _syncFromCharacter();
  }

  @override
  void didUpdateWidget(covariant _RuntimePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) {
      _syncFromCharacter();
    }
  }

  void _syncFromCharacter() {
    _currentHp = widget.character.currentHp;
    _temporaryHp = widget.character.temporaryHp;
    _inspiration = widget.character.inspiration;
    _conditions = [...widget.character.conditions];
    _deathSaveSuccesses = widget.character.deathSaveSuccesses;
    _deathSaveFailures = widget.character.deathSaveFailures;
    _classResourcesUsed = {
      for (final resource in widget.character.classResources)
        resource.id: (widget.character.classResourcesUsed[resource.id] ?? 0)
            .clamp(0, resource.maximum)
            .toInt(),
    };
  }

  @override
  void dispose() {
    _hpDeltaController.dispose();
    _conditionSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '生命与状态',
          icon: Icons.favorite_outline,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('当前 HP $_currentHp/${widget.character.maxHp}')),
              IconButton.filledTonal(
                tooltip: '受到 1 点伤害',
                onPressed: _currentHp <= 0
                    ? null
                    : () => _setCurrentHp(_currentHp - 1),
                icon: const Icon(Icons.heart_broken_outlined),
              ),
              IconButton.filledTonal(
                tooltip: '恢复 1 点 HP',
                onPressed: _currentHp >= widget.character.maxHp
                    ? null
                    : () => _setCurrentHp(_currentHp + 1),
                icon: const Icon(Icons.healing_outlined),
              ),
              Chip(label: Text('临时 HP $_temporaryHp')),
              IconButton.filledTonal(
                tooltip: '-1 临时 HP',
                onPressed: _temporaryHp <= 0
                    ? null
                    : () => _setTemporaryHp(_temporaryHp - 1),
                icon: const Icon(Icons.remove),
              ),
              IconButton.filledTonal(
                tooltip: '+1 临时 HP',
                onPressed: () => _setTemporaryHp(_temporaryHp + 1),
                icon: const Icon(Icons.add),
              ),
              if (_inspiration)
                const Chip(
                  avatar: Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text('灵感'),
                ),
              FilledButton.tonal(
                onPressed: () => _setInspiration(!_inspiration),
                child: Text(_inspiration ? '消耗灵感' : '获得灵感'),
              ),
              Chip(
                label: Text('死亡豁免 $_deathSaveSuccesses/$_deathSaveFailures'),
              ),
              IconButton.outlined(
                tooltip: '死亡豁免成功 +1',
                onPressed: _deathSaveSuccesses >= 3
                    ? null
                    : () => _setDeathSaveSuccesses(_deathSaveSuccesses + 1),
                icon: const Icon(Icons.check_outlined),
              ),
              IconButton.outlined(
                tooltip: '死亡豁免失败 +1',
                onPressed: _deathSaveFailures >= 3
                    ? null
                    : () => _setDeathSaveFailures(_deathSaveFailures + 1),
                icon: const Icon(Icons.close_outlined),
              ),
            ],
          ),
        ),
        _Section(
          title: '生命快改',
          icon: Icons.monitor_heart_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  key: const Key('hp-delta-field'),
                  controller: _hpDeltaController,
                  decoration: const InputDecoration(
                    labelText: '数值',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _applyHpDelta(-_hpDeltaValue()),
                icon: const Icon(Icons.heart_broken_outlined),
                label: const Text('受到伤害'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _applyHpDelta(_hpDeltaValue()),
                icon: const Icon(Icons.healing_outlined),
                label: const Text('恢复 HP'),
              ),
              OutlinedButton.icon(
                onPressed: _resetDeathSaves,
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('重置死亡豁免'),
              ),
            ],
          ),
        ),
        _Section(
          title: '休息',
          icon: Icons.hotel_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _takeShortRest,
                icon: const Icon(Icons.bedtime_outlined),
                label: const Text('短休'),
              ),
              FilledButton.icon(
                onPressed: _takeLongRest,
                icon: const Icon(Icons.night_shelter_outlined),
                label: const Text('长休'),
              ),
            ],
          ),
        ),
        _Section(
          title: '职业资源',
          icon: Icons.bolt_outlined,
          child: widget.character.classResources.isEmpty
              ? Text('暂无职业资源', style: Theme.of(context).textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final resource in widget.character.classResources)
                      _ClassResourceLine(
                        resource: resource,
                        used: _classResourcesUsed[resource.id] ?? 0,
                        onConsume: () => _adjustClassResource(resource, 1),
                        onRecover: () => _adjustClassResource(resource, -1),
                      ),
                  ],
                ),
        ),
        _Section(
          title: '状态',
          icon: Icons.warning_amber_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_conditions.isEmpty)
                    Text('暂无状态', style: Theme.of(context).textTheme.bodyMedium)
                  else
                    for (final condition in _conditions)
                      InputChip(
                        avatar: const Icon(Icons.flag_outlined, size: 18),
                        deleteIcon: const Icon(Icons.cancel),
                        label: Text(condition),
                        onDeleted: () => _removeCondition(condition),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: TextField(
                  key: const Key('condition-search-field'),
                  controller: _conditionSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '搜索或输入自定义状态',
                    prefixIcon: const Icon(Icons.search_outlined),
                    suffixIcon: _conditionSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空状态搜索',
                            onPressed: () {
                              setState(_conditionSearchController.clear);
                            },
                            icon: const Icon(Icons.close_outlined),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final condition in _filteredConditionOptions())
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(condition),
                      onPressed: () => _addCondition(condition),
                    ),
                  if (_canAddCustomCondition())
                    FilledButton.icon(
                      onPressed: _addCustomCondition,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('添加自定义状态'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setCurrentHp(int value) async {
    final next = value.clamp(0, widget.character.maxHp);
    setState(() => _currentHp = next);
    await widget.onUpdateRuntime?.call(currentHp: next);
  }

  int _hpDeltaValue() {
    final parsed = int.tryParse(_hpDeltaController.text.trim());
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  Future<void> _applyHpDelta(int delta) {
    return _setCurrentHp(_currentHp + delta);
  }

  Future<void> _setTemporaryHp(int value) async {
    setState(() => _temporaryHp = value);
    await widget.onUpdateRuntime?.call(temporaryHp: value);
  }

  Future<void> _setInspiration(bool value) async {
    setState(() => _inspiration = value);
    await widget.onUpdateRuntime?.call(inspiration: value);
  }

  Future<void> _addCondition(String condition) async {
    final normalized = condition.trim();
    if (normalized.isEmpty || _conditions.contains(normalized)) return;
    final next = [..._conditions, normalized];
    setState(() => _conditions = next);
    await widget.onUpdateRuntime?.call(conditions: next);
  }

  List<String> _filteredConditionOptions() {
    final query = _conditionSearchController.text.trim();
    final options = _commonConditions.where((condition) {
      if (_conditions.contains(condition)) return false;
      if (query.isEmpty) return true;
      return condition.contains(query);
    }).toList();
    return query.isEmpty ? options.take(12).toList() : options;
  }

  bool _canAddCustomCondition() {
    final query = _conditionSearchController.text.trim();
    if (query.isEmpty || _conditions.contains(query)) return false;
    return !_commonConditions.contains(query);
  }

  Future<void> _addCustomCondition() async {
    final condition = _conditionSearchController.text.trim();
    await _addCondition(condition);
    setState(_conditionSearchController.clear);
  }

  Future<void> _removeCondition(String condition) async {
    final next = _conditions.where((item) => item != condition).toList();
    setState(() => _conditions = next);
    await widget.onUpdateRuntime?.call(conditions: next);
  }

  Future<void> _setDeathSaveSuccesses(int value) async {
    final next = value.clamp(0, 3);
    setState(() => _deathSaveSuccesses = next);
    await widget.onUpdateRuntime?.call(deathSaveSuccesses: next);
  }

  Future<void> _setDeathSaveFailures(int value) async {
    final next = value.clamp(0, 3);
    setState(() => _deathSaveFailures = next);
    await widget.onUpdateRuntime?.call(deathSaveFailures: next);
  }

  Future<void> _adjustClassResource(
    CharacterClassResource resource,
    int delta,
  ) async {
    final current = _classResourcesUsed[resource.id] ?? 0;
    final next = Map<String, int>.from(_classResourcesUsed);
    next[resource.id] = (current + delta).clamp(0, resource.maximum).toInt();
    setState(() => _classResourcesUsed = next);
    await widget.onUpdateRuntime?.call(classResourcesUsed: next);
  }

  Future<void> _resetDeathSaves() async {
    setState(() {
      _deathSaveSuccesses = 0;
      _deathSaveFailures = 0;
    });
    await widget.onUpdateRuntime?.call(
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
    );
  }

  Future<void> _takeShortRest() {
    return _resetDeathSaves();
  }

  Future<void> _takeLongRest() async {
    setState(() {
      _currentHp = widget.character.maxHp;
      _temporaryHp = 0;
      _deathSaveSuccesses = 0;
      _deathSaveFailures = 0;
      _classResourcesUsed = {
        for (final resource in widget.character.classResources) resource.id: 0,
      };
    });
    await widget.onUpdateRuntime?.call(
      currentHp: widget.character.maxHp,
      temporaryHp: 0,
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
      classResourcesUsed: _classResourcesUsed,
    );
  }
}

class _ClassResourceLine extends StatelessWidget {
  const _ClassResourceLine({
    required this.resource,
    required this.used,
    required this.onConsume,
    required this.onRecover,
  });

  final CharacterClassResource resource;
  final int used;
  final VoidCallback onConsume;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bolt_outlined),
      title: Text('${resource.name} $used/${resource.maximum} 已用'),
      subtitle: LinearProgressIndicator(
        value: resource.maximum == 0 ? 0 : used / resource.maximum,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '恢复${resource.name}',
            onPressed: used <= 0 ? null : onRecover,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: '消耗${resource.name}',
            onPressed: used >= resource.maximum ? null : onConsume,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.character});

  final CharacterSheet character;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '笔记',
      icon: Icons.notes_outlined,
      child: Text(
        character.notes.isEmpty ? '暂无笔记' : character.notes,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _RollChip extends StatelessWidget {
  const _RollChip({
    required this.label,
    required this.value,
    required this.proficient,
    this.diceRoller,
    this.rollMode = _D20RollMode.normal,
    this.onRoll,
  });

  final String label;
  final int value;
  final bool proficient;
  final DiceRoller? diceRoller;
  final _D20RollMode rollMode;
  final CharacterRollCallback? onRoll;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(
        proficient ? Icons.check_circle_outline : Icons.casino_outlined,
        size: 18,
      ),
      label: Text('$label ${Dnd5eRules.formatModifier(value)}'),
      onPressed: () => _showRollResult(context),
    );
  }

  void _showRollResult(BuildContext context) {
    final roll = _rollD20WithMode(
      diceRoller: diceRoller ?? DiceRoller(),
      mode: rollMode,
      modifier: value,
    );
    final summary = '$label：${roll.label}';
    onRoll?.call(
      CharacterRollEvent(
        label: label,
        notation: roll.notation,
        total: roll.total,
        summary: summary,
      ),
    );
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(summary)));
  }
}

class _AbilityTile extends StatelessWidget {
  const _AbilityTile({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final modifier = Dnd5eRules.formatModifier(
      Dnd5eRules.abilityModifier(score),
    );
    return SizedBox(
      width: 104,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text('$score', style: Theme.of(context).textTheme.titleLarge),
              Text(modifier),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryLine extends StatelessWidget {
  const _InventoryLine({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    this.onConsume,
  });

  final Map<String, Object> item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onConsume;

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? '未命名物品';
    final quantity = _intValue(item['quantity'], fallback: 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text('$name x$quantity'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '$name -1',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: '$name +1',
                  visualDensity: VisualDensity.compact,
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          if (onConsume != null)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: OutlinedButton.icon(
                onPressed: quantity > 0 ? onConsume : null,
                icon: const Icon(Icons.local_drink_outlined),
                label: Text('消耗$name'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrencyControl extends StatelessWidget {
  const _CurrencyControl({
    required this.code,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String code;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '$code -1',
              visualDensity: VisualDensity.compact,
              onPressed: onDecrement,
              icon: const Icon(Icons.remove),
            ),
            Text('$code $value'),
            IconButton(
              tooltip: '$code +1',
              visualDensity: VisualDensity.compact,
              onPressed: onIncrement,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

List<Map<String, Object>> _normalizeInventory(List<Object?> items) {
  return items.map(_normalizeInventoryItem).toList(growable: false);
}

Map<String, Object> _normalizeInventoryItem(Object? item) {
  if (item is Map) {
    final name = item['name']?.toString() ?? '未命名物品';
    final result = <String, Object>{
      'name': name,
      'quantity': _intValue(item['quantity'], fallback: 1),
    };
    if (item['consumable'] is bool) {
      result['consumable'] = item['consumable']! as bool;
    }
    return result;
  }
  return {'name': item?.toString() ?? '未命名物品', 'quantity': 1};
}

Map<String, int> _normalizeCurrency(Map<String, Object?> currency) {
  return {
    for (final entry in currency.entries)
      entry.key: _intValue(entry.value, fallback: 0),
  };
}

bool _isConsumable(Map<String, Object> item) {
  if (item['consumable'] == true) return true;
  final name = item['name']?.toString().toLowerCase() ?? '';
  return name.contains('药水') ||
      name.contains('potion') ||
      name.contains('卷轴') ||
      name.contains('scroll') ||
      name.contains('口粮') ||
      name.contains('ration');
}

int _intValue(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value.isEmpty ? '-' : value),
    );
  }
}
