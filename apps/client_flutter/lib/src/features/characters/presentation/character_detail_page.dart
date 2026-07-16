import 'dart:async';

import 'package:flutter/material.dart';

import '../../content/domain/content_entry.dart';
import '../../content/presentation/content_entry_preview_page.dart';
import '../../../core/dice/dice_roller.dart';
import '../domain/character.dart';
import '../domain/character_manual_overrides.dart';
import '../domain/character_override_resolver.dart';
import '../domain/character_profile.dart';
import '../domain/character_quick_edit_service.dart';
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
typedef CharacterSaveCallback = Future<bool> Function(CharacterSheet character);
typedef CharacterUpgradeCallback = Future<CharacterSheet?> Function();

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

class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({
    required this.character,
    this.onEdit,
    this.onUpdateRuntime,
    this.onUpdateInventory,
    this.onSaveCharacter,
    this.onUpgrade,
    this.contentEntries = const <ContentEntry>[],
    this.diceRoller,
    this.onRoll,
    this.initialTab = 'overview',
    super.key,
  });

  final CharacterSheet character;
  final VoidCallback? onEdit;
  final CharacterRuntimeUpdate? onUpdateRuntime;
  final CharacterInventoryUpdate? onUpdateInventory;
  final CharacterSaveCallback? onSaveCharacter;
  final CharacterUpgradeCallback? onUpgrade;
  final List<ContentEntry> contentEntries;
  final DiceRoller? diceRoller;
  final CharacterRollCallback? onRoll;
  final String initialTab;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage> {
  late CharacterSheet _character;

  @override
  void initState() {
    super.initState();
    _character = widget.character;
  }

  @override
  void didUpdateWidget(covariant CharacterDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) _character = widget.character;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      initialIndex: _initialTabIndex(widget.initialTab),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_character.name),
          actions: [
            if (widget.onUpgrade != null && _character.level < 20)
              IconButton(
                tooltip: '升级角色',
                onPressed: _upgrade,
                icon: const Icon(Icons.upgrade),
              ),
            if (widget.onEdit != null)
              IconButton(
                tooltip: '编辑角色',
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CharacterHeader(character: _character),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '总览'),
                Tab(text: '属性'),
                Tab(text: '动作'),
                Tab(text: '法术'),
                Tab(text: '装备'),
                Tab(text: '资源'),
                Tab(text: '特性'),
                Tab(text: '角色资料'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SheetTab(
                    child: _RuntimePanel(
                      character: _character,
                      onUpdateRuntime: _updateRuntime,
                    ),
                  ),
                  _SheetTab(child: _AbilityOverview(character: _character)),
                  _SheetTab(
                    child: _ActionsPanel(
                      character: _character,
                      diceRoller: widget.diceRoller,
                      onRoll: widget.onRoll,
                      onSaveCharacter: _saveCharacter,
                    ),
                  ),
                  _SheetTab(
                    child: _SpellsPanel(
                      character: _character,
                      contentEntries: widget.contentEntries,
                      onUpdateRuntime: _updateRuntime,
                      onSaveCharacter: _saveCharacter,
                    ),
                  ),
                  _SheetTab(
                    child: _EquipmentPanel(
                      character: _character,
                      contentEntries: widget.contentEntries,
                      onUpdateInventory: widget.onUpdateInventory,
                    ),
                  ),
                  _SheetTab(
                    child: _ResourcesPanel(
                      character: _character,
                      onUpdateRuntime: _updateRuntime,
                      onSaveCharacter: _saveCharacter,
                    ),
                  ),
                  _SheetTab(
                    child: _FeaturesPanel(
                      character: _character,
                      contentEntries: widget.contentEntries,
                      onSaveCharacter: _saveCharacter,
                    ),
                  ),
                  _SheetTab(
                    child: _ProfilePanel(
                      character: _character,
                      onSaveCharacter: _saveCharacter,
                    ),
                  ),
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
      'abilities' || 'attributes' => 1,
      'actions' => 2,
      'spells' => 3,
      'equipment' => 4,
      'resources' => 5,
      'features' => 6,
      'profile' || 'details' || 'notes' => 7,
      _ => 0,
    };
  }

  Future<void> _updateRuntime({
    int? currentHp,
    int? temporaryHp,
    bool? inspiration,
    List<String>? conditions,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    Map<String, int>? spellSlotsUsed,
    Map<String, int>? classResourcesUsed,
  }) async {
    final runtime = Map<String, Object?>.from(_character.runtimeMap);
    if (temporaryHp != null) runtime['temporaryHp'] = temporaryHp;
    if (inspiration != null) runtime['inspiration'] = inspiration;
    if (conditions != null) runtime['conditions'] = conditions;
    if (spellSlotsUsed != null) runtime['spellSlotsUsed'] = spellSlotsUsed;
    if (classResourcesUsed != null) {
      runtime['classResourcesUsed'] = classResourcesUsed;
    }
    if (deathSaveSuccesses != null || deathSaveFailures != null) {
      final deathSaves = Map<String, Object?>.from(
        runtime['deathSaves'] is Map
            ? Map<String, Object?>.from(runtime['deathSaves']! as Map)
            : const <String, Object?>{},
      );
      if (deathSaveSuccesses != null) {
        deathSaves['successes'] = deathSaveSuccesses;
      }
      if (deathSaveFailures != null) deathSaves['failures'] = deathSaveFailures;
      runtime['deathSaves'] = deathSaves;
    }
    final data = Map<String, Object?>.from(_character.dataMap)
      ..['runtime'] = runtime;
    final updated = _character.copyWith(currentHp: currentHp, data: data);
    if (mounted) setState(() => _character = updated);
    await widget.onUpdateRuntime?.call(
      currentHp: currentHp,
      temporaryHp: temporaryHp,
      inspiration: inspiration,
      conditions: conditions,
      deathSaveSuccesses: deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures,
      spellSlotsUsed: spellSlotsUsed,
      classResourcesUsed: classResourcesUsed,
    );
  }

  Future<bool> _saveCharacter(CharacterSheet character) async {
    final callback = widget.onSaveCharacter;
    if (callback == null) return false;
    final success = await callback(character);
    if (!mounted) return success;
    if (success) {
      setState(() => _character = character);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
    }
    return success;
  }

  Future<void> _upgrade() async {
    final upgraded = await widget.onUpgrade?.call();
    if (mounted && upgraded != null) setState(() => _character = upgraded);
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            child: Text(character.name.characters.first.toUpperCase()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(character.name, style: theme.textTheme.titleMedium),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 2,
                children: [
                  Text(
                    'HP ${character.currentHp}/${character.maxHp}',
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    'AC ${character.armorClass}',
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    '先攻 ${Dnd5eRules.formatModifier(character.initiativeBonus)}',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            ),
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
  const _ActionsPanel({
    required this.character,
    this.diceRoller,
    this.onRoll,
    this.onSaveCharacter,
  });

  final CharacterSheet character;
  final DiceRoller? diceRoller;
  final CharacterRollCallback? onRoll;
  final CharacterSaveCallback? onSaveCharacter;

  @override
  State<_ActionsPanel> createState() => _ActionsPanelState();
}

class _ActionsPanelState extends State<_ActionsPanel> {
  static const _quickEditService = CharacterQuickEditService();
  _D20RollMode _rollMode = _D20RollMode.normal;

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final attacks = _deriveWeaponAttacks(character);
    final ruleActions = CharacterOverrideResolver.resolve(character).actions;
    final spellSaveDc = Dnd5eRules.spellSaveDc(
      classSummary: character.classSummary,
      abilities: character.abilityMap,
      level: character.level,
    );
    final roller = widget.diceRoller ?? DiceRoller();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onSaveCharacter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton.tonalIcon(
              onPressed: _addCustomAction,
              icon: const Icon(Icons.add),
              label: const Text('添加自定义动作'),
            ),
          ),
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
        if (ruleActions.isNotEmpty)
          _Section(
            title: '资料动作',
            icon: Icons.auto_awesome_motion_outlined,
            child: Column(
              children: [
                for (final action in ruleActions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bolt_outlined),
                    title: Text('${action['name'] ?? action['id'] ?? '动作'}'),
                    subtitle: Text(
                      [
                        if ('${action['formula'] ?? ''}'.isNotEmpty)
                          '${action['formula']}',
                        if ('${action['entryId'] ?? ''}'.isNotEmpty)
                          '${action['entryId']}',
                      ].join(' · '),
                    ),
                    trailing:
                        widget.onSaveCharacter != null &&
                            '${action['id'] ?? ''}'.startsWith('custom-action-')
                        ? IconButton(
                            tooltip: '删除动作',
                            onPressed: () =>
                                _removeCustomAction('${action['id']}'),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
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

  Future<void> _addCustomAction() async {
    final value = await _showNameDescriptionDialog(context, title: '自定义动作');
    if (value == null) return;
    await widget.onSaveCharacter?.call(
      _quickEditService.addCustomAction(
        widget.character,
        name: value.$1,
        description: value.$2,
      ),
    );
  }

  Future<void> _removeCustomAction(String id) async {
    await widget.onSaveCharacter?.call(
      _quickEditService.removeCustomAction(widget.character, id),
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
  const _SpellsPanel({
    required this.character,
    required this.contentEntries,
    this.onUpdateRuntime,
    this.onSaveCharacter,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
  final CharacterRuntimeUpdate? onUpdateRuntime;
  final CharacterSaveCallback? onSaveCharacter;

  @override
  State<_SpellsPanel> createState() => _SpellsPanelState();
}

class _SpellsPanelState extends State<_SpellsPanel> {
  static const _quickEditService = CharacterQuickEditService();
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
    final ability = _spellcastingAbility();
    final slotMaximums = _slotMaximums();
    final resolved = CharacterOverrideResolver.resolve(widget.character);
    final spellRefs = resolved.spellEntryIds;
    final spellsByLevel = _spellsByLevel(spellRefs);

    if (ability == null &&
        slotMaximums.isEmpty &&
        spellRefs.isEmpty &&
        widget.onSaveCharacter == null) {
      return const _EmptyPanel(title: '暂无法术引用');
    }

    final abilityLabel = ability == null
        ? '无'
        : Dnd5eRules.abilityLabels[ability] ?? ability;
    final saveDc = ability == null
        ? null
        : 8 +
              Dnd5eRules.proficiencyBonus(widget.character.level) +
              Dnd5eRules.abilityModifier(
                Dnd5eRules.abilityScore(widget.character.abilityMap, ability),
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
          title: '已知与已准备法术',
          icon: Icons.menu_book_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onSaveCharacter != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.tonalIcon(
                    onPressed: _addSpell,
                    icon: const Icon(Icons.add),
                    label: const Text('添加法术'),
                  ),
                ),
              if (spellRefs.isEmpty)
                Text('暂无法术', style: Theme.of(context).textTheme.bodyMedium)
              else
                for (final entry in spellsByLevel.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      _spellLevelLabel(entry.key),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final spell in entry.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_fix_high_outlined),
                      title: Text(_entryName(spell)),
                      subtitle: Text(
                        resolved.preparedSpellEntryIds.contains(spell)
                            ? '已准备'
                            : '未准备',
                      ),
                      onTap: () => _openSpell(spell),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onSaveCharacter != null)
                            IconButton(
                              tooltip:
                                  resolved.preparedSpellEntryIds.contains(spell)
                                  ? '取消准备${_entryName(spell)}'
                                  : '准备${_entryName(spell)}',
                              onPressed: () => _setPrepared(
                                spell,
                                !resolved.preparedSpellEntryIds.contains(spell),
                              ),
                              icon: Icon(
                                resolved.preparedSpellEntryIds.contains(spell)
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                              ),
                            ),
                          if (widget.onSaveCharacter != null)
                            IconButton(
                              tooltip: '移除${_entryName(spell)}',
                              onPressed: () => _removeSpell(spell),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Map<String, int> _slotMaximums() {
    final derived = widget.character.dataMap['spellSlots'];
    if (derived is Map) {
      return {
        for (final entry in derived.entries)
          '${entry.key}': entry.value is num
              ? (entry.value as num).toInt()
              : int.tryParse('${entry.value}') ?? 0,
      };
    }
    return Dnd5eRules.spellSlotMaximums(
      classSummary: widget.character.classSummary,
      level: widget.character.level,
    );
  }

  String? _spellcastingAbility() {
    final derived = widget.character.dataMap['spellcastingAbility'];
    if (derived is String && Dnd5eRules.abilityLabels.containsKey(derived)) {
      return derived;
    }
    return Dnd5eRules.spellcastingAbility(widget.character.classSummary);
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

  String _entryName(String entryId) {
    for (final entry in widget.contentEntries) {
      if (entry.id == entryId) return entry.name;
    }
    return entryId;
  }

  Map<int, List<String>> _spellsByLevel(List<String> spellRefs) {
    final result = <int, List<String>>{};
    for (final spell in spellRefs) {
      final entry = widget.contentEntries
          .where((candidate) => candidate.id == spell)
          .firstOrNull;
      final value = entry?.structured['level'];
      final level = value is num ? value.toInt() : int.tryParse('$value') ?? 99;
      (result[level] ??= []).add(spell);
    }
    return Map.fromEntries(
      result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  String _spellLevelLabel(int level) {
    if (level == 0) return '戏法';
    if (level == 99) return '未分类法术';
    return Dnd5eRules.spellLevelLabel('$level');
  }

  void _openSpell(String entryId) {
    final entry = widget.contentEntries
        .where((candidate) => candidate.id == entryId)
        .firstOrNull;
    if (entry == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前资料库中找不到这条法术')));
      return;
    }
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: widget.contentEntries,
    );
  }

  Future<void> _addSpell() async {
    final entry = await _pickContentEntry(
      context,
      title: '添加法术',
      entries: widget.contentEntries
          .where((entry) => entry.type == 'spell')
          .toList(growable: false),
    );
    if (entry == null) return;
    await widget.onSaveCharacter?.call(
      _quickEditService.addSpell(widget.character, entry.id),
    );
  }

  Future<void> _removeSpell(String entryId) async {
    await widget.onSaveCharacter?.call(
      _quickEditService.removeSpell(widget.character, entryId),
    );
  }

  Future<void> _setPrepared(String entryId, bool prepared) async {
    await widget.onSaveCharacter?.call(
      _quickEditService.setSpellPrepared(widget.character, entryId, prepared),
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
  const _EquipmentPanel({
    required this.character,
    required this.contentEntries,
    this.onUpdateInventory,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
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
    final equipped = _inventory
        .where((item) => item['equipped'] == true)
        .toList(growable: false);
    final carried = _inventory
        .where((item) => item['equipped'] != true)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '货币',
          icon: Icons.paid_outlined,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_currency.isEmpty)
                    Text(
                      '暂无货币记录',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
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
          ),
        ),
        _Section(
          title: '装备与物品',
          icon: Icons.inventory_2_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onUpdateInventory != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _addLibraryItem,
                        icon: const Icon(Icons.add),
                        label: const Text('从资料库添加'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addCustomItem,
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('自定义物品'),
                      ),
                    ],
                  ),
                ),
              if (_inventory.isEmpty)
                Text('暂无装备', style: Theme.of(context).textTheme.bodyMedium)
              else ...[
                if (equipped.isNotEmpty) ...[
                  Text('已装备', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final item in equipped) _buildInventoryLine(item),
                  const SizedBox(height: 8),
                ],
                if (carried.isNotEmpty) ...[
                  Text('背包', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final item in carried) _buildInventoryLine(item),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryLine(Map<String, Object> item) {
    final index = _inventory.indexOf(item);
    final entryId = item['entryId']?.toString();
    final entry = widget.contentEntries
        .where((candidate) => candidate.id == entryId)
        .firstOrNull;
    return _InventoryLine(
      item: item,
      entry: entry,
      onOpen: entry == null ? null : () => _openEntry(entry),
      onIncrement: () => _adjustInventoryQuantity(index, 1),
      onDecrement: () => _adjustInventoryQuantity(index, -1),
      onConsume: _isConsumable(item)
          ? () => _adjustInventoryQuantity(index, -1)
          : null,
      onToggleEquipped: () => _toggleItemFlag(index, 'equipped'),
      onToggleAttuned: () => _toggleItemFlag(index, 'attuned'),
      onDelete: () => _deleteInventoryItem(index),
    );
  }

  void _openEntry(ContentEntry entry) {
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: widget.contentEntries,
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

  Future<void> _addLibraryItem() async {
    final entry = await _pickContentEntry(
      context,
      title: '添加装备',
      entries: widget.contentEntries
          .where(
            (entry) => const <String>{
              'equipment',
              'item',
              'weapon',
              'armor',
            }.contains(entry.type),
          )
          .toList(growable: false),
    );
    if (entry == null) return;
    final next = <Map<String, Object>>[
      ..._inventory.map(Map<String, Object>.from),
      <String, Object>{
        'entryId': entry.id,
        'name': entry.name,
        'quantity': 1,
        'equipped': false,
        'attuned': false,
      },
    ];
    await _saveInventory(next);
  }

  Future<void> _addCustomItem() async {
    final value = await _showNameDescriptionDialog(context, title: '自定义物品');
    if (value == null) return;
    final next = <Map<String, Object>>[
      ..._inventory.map(Map<String, Object>.from),
      <String, Object>{
        'name': value.$1,
        'quantity': 1,
        if (value.$2.trim().isNotEmpty) 'description': value.$2.trim(),
        'equipped': false,
        'attuned': false,
      },
    ];
    await _saveInventory(next);
  }

  Future<void> _toggleItemFlag(int index, String key) async {
    final next = _inventory.map(Map<String, Object>.from).toList();
    next[index][key] = next[index][key] != true;
    await _saveInventory(next);
  }

  Future<void> _deleteInventoryItem(int index) async {
    final next = _inventory.map(Map<String, Object>.from).toList()
      ..removeAt(index);
    await _saveInventory(next);
  }

  Future<void> _saveInventory(List<Map<String, Object>> next) async {
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

class _FeaturesPanel extends StatelessWidget {
  const _FeaturesPanel({
    required this.character,
    required this.contentEntries,
    this.onSaveCharacter,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
  final CharacterSaveCallback? onSaveCharacter;
  static const _quickEditService = CharacterQuickEditService();

  @override
  Widget build(BuildContext context) {
    final overrides = CharacterManualOverrides.fromCharacter(character);
    final resolved = CharacterOverrideResolver.resolve(character);
    final allGrants = _objectMaps(
      character.dataMap['resolvedGrants'],
    ).where((grant) => grant['kind'] == 'feature').toList(growable: false);
    final visibleGrants = allGrants
        .where(
          (grant) => !overrides.hiddenGrantKeys.contains(
            CharacterOverrideResolver.grantKey(grant),
          ),
        )
        .toList(growable: false);
    final hiddenGrants = allGrants
        .where(
          (grant) => overrides.hiddenGrantKeys.contains(
            CharacterOverrideResolver.grantKey(grant),
          ),
        )
        .toList(growable: false);
    final grantedEntryIds = allGrants
        .map((grant) => grant['entryId'])
        .whereType<String>()
        .toSet();
    final selectedFeatureEntryIds = resolved.featureEntryIds
        .where(
          (entryId) =>
              !grantedEntryIds.contains(entryId) &&
              !overrides.addedFeatureEntryIds.contains(entryId),
        )
        .toList(growable: false);
    if (visibleGrants.isEmpty &&
        resolved.featureEntryIds.isEmpty &&
        resolved.customFeatures.isEmpty &&
        onSaveCharacter == null) {
      return const _EmptyPanel(title: '暂无已获得特性');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onSaveCharacter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _addLibraryFeature(context),
                  icon: const Icon(Icons.add),
                  label: const Text('从资料库添加'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addCustomFeature(context),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('自定义特性'),
                ),
              ],
            ),
          ),
        if (visibleGrants.isNotEmpty)
          _Section(
            title: '自动获得的特性',
            icon: Icons.auto_awesome_outlined,
            child: Column(
              children: [
                for (final grant in visibleGrants)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text('${grant['label'] ?? grant['id'] ?? '职业特性'}'),
                    subtitle: Text(_grantSource(grant)),
                    onTap: grant['entryId'] is String
                        ? () => _openEntry(context, grant['entryId'] as String)
                        : null,
                    trailing: onSaveCharacter == null
                        ? null
                        : IconButton(
                            tooltip: '在角色卡中隐藏',
                            onPressed: () => _setGrantHidden(grant, true),
                            icon: const Icon(Icons.visibility_off_outlined),
                          ),
                  ),
              ],
            ),
          ),
        if (selectedFeatureEntryIds.isNotEmpty)
          _Section(
            title: '选择获得',
            icon: Icons.task_alt_outlined,
            child: Column(
              children: [
                for (final entryId in selectedFeatureEntryIds)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(_entryName(entryId)),
                    onTap: () => _openEntry(context, entryId),
                  ),
              ],
            ),
          ),
        if (overrides.addedFeatureEntryIds.isNotEmpty ||
            resolved.customFeatures.isNotEmpty)
          _Section(
            title: '手动添加',
            icon: Icons.menu_book_outlined,
            child: Column(
              children: [
                for (final entryId in overrides.addedFeatureEntryIds)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_outlined),
                    title: Text(_entryName(entryId)),
                    onTap: () => _openEntry(context, entryId),
                    trailing: onSaveCharacter == null
                        ? null
                        : IconButton(
                            tooltip: '删除',
                            onPressed: () => _removeAddedFeature(entryId),
                            icon: const Icon(Icons.delete_outline),
                          ),
                  ),
                for (final feature in resolved.customFeatures)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_note_outlined),
                    title: Text('${feature['name'] ?? '自定义特性'}'),
                    subtitle: '${feature['description'] ?? ''}'.isEmpty
                        ? null
                        : Text('${feature['description']}'),
                    trailing: onSaveCharacter == null
                        ? null
                        : IconButton(
                            tooltip: '删除',
                            onPressed: () =>
                                _removeCustomFeature('${feature['id'] ?? ''}'),
                            icon: const Icon(Icons.delete_outline),
                          ),
                  ),
              ],
            ),
          ),
        if (hiddenGrants.isNotEmpty)
          _Section(
            title: '已隐藏',
            icon: Icons.visibility_off_outlined,
            child: Column(
              children: [
                for (final grant in hiddenGrants)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${grant['label'] ?? grant['id'] ?? '职业特性'}'),
                    trailing: IconButton(
                      tooltip: '恢复显示',
                      onPressed: () => _setGrantHidden(grant, false),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _entryName(String entryId) {
    for (final entry in contentEntries) {
      if (entry.id == entryId) return entry.name;
    }
    return entryId;
  }

  void _openEntry(BuildContext context, String entryId) {
    final entry = contentEntries
        .where((candidate) => candidate.id == entryId)
        .firstOrNull;
    if (entry == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前资料库中找不到这条特性')));
      return;
    }
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: contentEntries,
    );
  }

  Future<void> _addLibraryFeature(BuildContext context) async {
    final entry = await _pickContentEntry(
      context,
      title: '添加特性',
      entries: contentEntries
          .where(
            (entry) => const <String>{
              'classFeature',
              'feature',
              'feat',
            }.contains(entry.type),
          )
          .toList(growable: false),
    );
    if (entry == null) return;
    await onSaveCharacter?.call(
      _quickEditService.addFeature(character, entry.id),
    );
  }

  Future<void> _addCustomFeature(BuildContext context) async {
    final value = await _showNameDescriptionDialog(context, title: '自定义特性');
    if (value == null) return;
    await onSaveCharacter?.call(
      _quickEditService.addCustomFeature(
        character,
        name: value.$1,
        description: value.$2,
      ),
    );
  }

  Future<void> _setGrantHidden(Map<String, Object?> grant, bool hidden) async {
    await onSaveCharacter?.call(
      _quickEditService.setGrantHidden(
        character,
        CharacterOverrideResolver.grantKey(grant),
        hidden,
      ),
    );
  }

  Future<void> _removeAddedFeature(String entryId) async {
    await onSaveCharacter?.call(
      _quickEditService.removeAddedFeature(character, entryId),
    );
  }

  Future<void> _removeCustomFeature(String id) async {
    await onSaveCharacter?.call(
      _quickEditService.removeCustomFeature(character, id),
    );
  }

  String _grantSource(Map<String, Object?> grant) {
    final source =
        '${grant['sourceEntryName'] ?? grant['sourceEntryId'] ?? '未知来源'}';
    final level = grant['sourceLevel'];
    return level == null ? source : '$source · $level 级获得';
  }
}

class _ProfilePanel extends StatefulWidget {
  const _ProfilePanel({required this.character, this.onSaveCharacter});

  final CharacterSheet character;
  final CharacterSaveCallback? onSaveCharacter;

  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  static const _service = CharacterQuickEditService();
  final _controllers = <String, TextEditingController>{};
  Timer? _saveTimer;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load(widget.character);
  }

  @override
  void didUpdateWidget(covariant _ProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character && !_saving) {
      _load(widget.character);
    }
  }

  void _load(CharacterSheet character) {
    final profile = CharacterProfile.fromCharacter(character);
    final values = <String, String>{
      'alignment': profile.alignment,
      'appearance': profile.appearance,
      'personalityTraits': profile.personalityTraits,
      'ideals': profile.ideals,
      'bonds': profile.bonds,
      'flaws': profile.flaws,
      'backstory': profile.backstory,
      'languages': profile.languages.join('、'),
      'privateNotes': profile.privateNotes,
    };
    for (final entry in values.entries) {
      (_controllers[entry.key] ??= TextEditingController()).text = entry.value;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onSaveCharacter != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '角色资料',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_saving)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_saved)
              const Icon(Icons.cloud_done_outlined, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        _profileField('alignment', '阵营', enabled: enabled),
        _profileField('appearance', '外貌', enabled: enabled, lines: 2),
        _profileField('personalityTraits', '个性特征', enabled: enabled, lines: 2),
        _profileField('ideals', '理想', enabled: enabled, lines: 2),
        _profileField('bonds', '牵绊', enabled: enabled, lines: 2),
        _profileField('flaws', '缺点', enabled: enabled, lines: 2),
        _profileField('languages', '语言', enabled: enabled),
        _profileField('backstory', '背景故事', enabled: enabled, lines: 6),
        _profileField('privateNotes', '私人笔记', enabled: enabled, lines: 5),
        if (!enabled) const Text('当前角色为只读；从本地角色列表打开后可直接编辑。'),
      ],
    );
  }

  Widget _profileField(
    String key,
    String label, {
    required bool enabled,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key('character-profile-$key'),
        controller: _controllers[key],
        enabled: enabled,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          alignLabelWithHint: lines > 1,
        ),
        onChanged: (_) => _scheduleSave(),
      ),
    );
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    if (_saved) setState(() => _saved = false);
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    final callback = widget.onSaveCharacter;
    if (callback == null || _saving) return;
    setState(() => _saving = true);
    final profile = CharacterProfile(
      alignment: _controllers['alignment']!.text.trim(),
      appearance: _controllers['appearance']!.text.trim(),
      personalityTraits: _controllers['personalityTraits']!.text.trim(),
      ideals: _controllers['ideals']!.text.trim(),
      bonds: _controllers['bonds']!.text.trim(),
      flaws: _controllers['flaws']!.text.trim(),
      backstory: _controllers['backstory']!.text.trim(),
      languages: _controllers['languages']!.text
          .split(RegExp(r'[,，、]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      privateNotes: _controllers['privateNotes']!.text.trim(),
    );
    final success = await callback(
      _service.updateProfile(widget.character, profile),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = success;
    });
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
  }

  @override
  void dispose() {
    _conditionSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '状态',
          icon: Icons.favorite_outline,
          child: _RuntimeStatusGrid(
            currentHp: _currentHp,
            maxHp: widget.character.maxHp,
            temporaryHp: _temporaryHp,
            inspiration: _inspiration,
            deathSaveSuccesses: _deathSaveSuccesses,
            deathSaveFailures: _deathSaveFailures,
            onAdjustHp: _showHpAdjustment,
            onTemporaryHpDecrease: _temporaryHp <= 0
                ? null
                : () => _setTemporaryHp(_temporaryHp - 1),
            onTemporaryHpIncrease: () => _setTemporaryHp(_temporaryHp + 1),
            onToggleInspiration: () => _setInspiration(!_inspiration),
            onDeathSaveSuccess: _deathSaveSuccesses >= 3
                ? null
                : () => _setDeathSaveSuccesses(_deathSaveSuccesses + 1),
            onDeathSaveFailure: _deathSaveFailures >= 3
                ? null
                : () => _setDeathSaveFailures(_deathSaveFailures + 1),
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
              OutlinedButton.icon(
                onPressed: _resetDeathSaves,
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('重置死亡豁免'),
              ),
            ],
          ),
        ),
        _Section(
          title: '状态与效果',
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

  Future<void> _showHpAdjustment() async {
    final delta = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _HpAdjustmentSheet(),
    );
    if (delta != null) await _setCurrentHp(_currentHp + delta);
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
    final resources = widget.character.classResources;
    final next = {
      for (final resource in resources)
        resource.id: (widget.character.classResourcesUsed[resource.id] ?? 0)
            .clamp(0, resource.maximum)
            .toInt(),
    };
    for (final resource in resources) {
      if (resource.recovery == 'shortRest') next[resource.id] = 0;
    }
    setState(() {
      _deathSaveSuccesses = 0;
      _deathSaveFailures = 0;
    });
    return widget.onUpdateRuntime?.call(
          deathSaveSuccesses: 0,
          deathSaveFailures: 0,
          classResourcesUsed: next,
        ) ??
        Future.value();
  }

  Future<void> _takeLongRest() async {
    final classResourcesUsed = {
      for (final resource in widget.character.classResources)
        resource.id: resource.recovery == 'none'
            ? (widget.character.classResourcesUsed[resource.id] ?? 0)
                  .clamp(0, resource.maximum)
                  .toInt()
            : 0,
    };
    setState(() {
      _currentHp = widget.character.maxHp;
      _temporaryHp = 0;
      _deathSaveSuccesses = 0;
      _deathSaveFailures = 0;
    });
    await widget.onUpdateRuntime?.call(
      currentHp: widget.character.maxHp,
      temporaryHp: 0,
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
      classResourcesUsed: classResourcesUsed,
    );
  }
}

class _RuntimeStatusGrid extends StatelessWidget {
  const _RuntimeStatusGrid({
    required this.currentHp,
    required this.maxHp,
    required this.temporaryHp,
    required this.inspiration,
    required this.deathSaveSuccesses,
    required this.deathSaveFailures,
    required this.onAdjustHp,
    required this.onTemporaryHpDecrease,
    required this.onTemporaryHpIncrease,
    required this.onToggleInspiration,
    required this.onDeathSaveSuccess,
    required this.onDeathSaveFailure,
  });

  final int currentHp;
  final int maxHp;
  final int temporaryHp;
  final bool inspiration;
  final int deathSaveSuccesses;
  final int deathSaveFailures;
  final VoidCallback onAdjustHp;
  final VoidCallback? onTemporaryHpDecrease;
  final VoidCallback onTemporaryHpIncrease;
  final VoidCallback onToggleInspiration;
  final VoidCallback? onDeathSaveSuccess;
  final VoidCallback? onDeathSaveFailure;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 360
            ? 2
            : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              height: 148,
              child: _RuntimeStatusTile(
                key: const Key('runtime-hp-panel'),
                icon: Icons.favorite_outline,
                title: '生命值',
                onTap: onAdjustHp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前 HP $currentHp/$maxHp',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: maxHp <= 0 ? 0 : currentHp / maxHp,
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '点击调整',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: width,
              height: 148,
              child: _RuntimeStatusTile(
                key: const Key('runtime-temporary-hp-panel'),
                icon: Icons.shield_outlined,
                title: '临时生命值',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '临时 HP $temporaryHp',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: '-1 临时 HP',
                          onPressed: onTemporaryHpDecrease,
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: '+1 临时 HP',
                          onPressed: onTemporaryHpIncrease,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: width,
              height: 148,
              child: _RuntimeStatusTile(
                key: const Key('runtime-inspiration-panel'),
                icon: Icons.auto_awesome_outlined,
                title: '灵感',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inspiration ? '当前可用' : '当前未获得'),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: onToggleInspiration,
                      child: Text(inspiration ? '消耗灵感' : '获得灵感'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: width,
              height: 148,
              child: _RuntimeStatusTile(
                key: const Key('runtime-death-saves-panel'),
                icon: Icons.monitor_heart_outlined,
                title: '死亡豁免',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('死亡豁免 $deathSaveSuccesses/$deathSaveFailures'),
                    const SizedBox(height: 4),
                    Text('成功 $deathSaveSuccesses · 失败 $deathSaveFailures'),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: '死亡豁免成功 +1',
                          onPressed: onDeathSaveSuccess,
                          icon: const Icon(Icons.check_outlined),
                        ),
                        IconButton(
                          tooltip: '死亡豁免失败 +1',
                          onPressed: onDeathSaveFailure,
                          icon: const Icon(Icons.close_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RuntimeStatusTile extends StatelessWidget {
  const _RuntimeStatusTile({
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  if (onTap != null) const Icon(Icons.edit_outlined, size: 17),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourcesPanel extends StatefulWidget {
  const _ResourcesPanel({
    required this.character,
    this.onUpdateRuntime,
    this.onSaveCharacter,
  });

  final CharacterSheet character;
  final CharacterRuntimeUpdate? onUpdateRuntime;
  final CharacterSaveCallback? onSaveCharacter;

  @override
  State<_ResourcesPanel> createState() => _ResourcesPanelState();
}

class _ResourcesPanelState extends State<_ResourcesPanel> {
  late Map<String, int> _classResourcesUsed;
  late List<CharacterClassResource> _resources;

  @override
  void initState() {
    super.initState();
    _syncFromCharacter();
  }

  @override
  void didUpdateWidget(covariant _ResourcesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) _syncFromCharacter();
  }

  void _syncFromCharacter() {
    _resources = [...widget.character.classResources];
    _classResourcesUsed = {
      for (final resource in _resources)
        resource.id: (widget.character.classResourcesUsed[resource.id] ?? 0)
            .clamp(0, resource.maximum)
            .toInt(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '职业资源',
      icon: Icons.bolt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_resources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _restoreResources(longRest: false),
                    icon: const Icon(Icons.bedtime_outlined),
                    label: const Text('恢复短休资源'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _restoreResources(longRest: true),
                    icon: const Icon(Icons.night_shelter_outlined),
                    label: const Text('恢复长休资源'),
                  ),
                ],
              ),
            ),
          if (_resources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '暂无可追踪资源',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final resource in _resources)
                      SizedBox(
                        width: width,
                        child: _ClassResourceLine(
                          resource: resource,
                          current:
                              resource.maximum -
                              (_classResourcesUsed[resource.id] ?? 0),
                          onSetCurrent: (value) =>
                              _setResourceCurrent(resource, value),
                          onEdit: widget.onSaveCharacter == null
                              ? null
                              : () => _editResource(resource),
                          onDelete: widget.onSaveCharacter == null
                              ? null
                              : () => _deleteResource(resource),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (widget.onSaveCharacter != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _addResource,
              icon: const Icon(Icons.add),
              label: const Text('添加资源'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setResourceCurrent(
    CharacterClassResource resource,
    int current,
  ) async {
    final next = Map<String, int>.from(_classResourcesUsed);
    next[resource.id] = (resource.maximum - current)
        .clamp(0, resource.maximum)
        .toInt();
    setState(() => _classResourcesUsed = next);
    await widget.onUpdateRuntime?.call(classResourcesUsed: next);
  }

  Future<void> _restoreResources({required bool longRest}) async {
    final next = Map<String, int>.from(_classResourcesUsed);
    for (final resource in _resources) {
      final recovers = longRest
          ? resource.recovery != 'none'
          : resource.recovery == 'shortRest';
      if (recovers) next[resource.id] = 0;
    }
    setState(() => _classResourcesUsed = next);
    await widget.onUpdateRuntime?.call(classResourcesUsed: next);
  }

  Future<void> _addResource() async {
    final resource = await _showResourceDialog(context);
    if (resource == null) return;
    await _saveResourceDefinitions([..._resources, resource]);
  }

  Future<void> _editResource(CharacterClassResource resource) async {
    final updated = await _showResourceDialog(context, initial: resource);
    if (updated == null) return;
    await _saveResourceDefinitions([
      for (final item in _resources)
        if (item.id == resource.id) updated else item,
    ]);
  }

  Future<void> _deleteResource(CharacterClassResource resource) async {
    await _saveResourceDefinitions(
      _resources
          .where((item) => item.id != resource.id)
          .toList(growable: false),
    );
  }

  Future<void> _saveResourceDefinitions(
    List<CharacterClassResource> resources,
  ) async {
    final used = Map<String, int>.from(_classResourcesUsed)
      ..removeWhere((id, _) => !resources.any((resource) => resource.id == id));
    for (final resource in resources) {
      used[resource.id] = (used[resource.id] ?? 0).clamp(0, resource.maximum);
    }
    final data = Map<String, Object?>.from(widget.character.dataMap)
      ..['classResources'] = [
        for (final resource in resources)
          <String, Object?>{
            'id': resource.id,
            'name': resource.name,
            'maximum': resource.maximum,
            'recovery': resource.recovery,
          },
      ];
    final saved = await widget.onSaveCharacter?.call(
      widget.character.copyWith(data: data),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _resources = resources;
      _classResourcesUsed = used;
    });
    await widget.onUpdateRuntime?.call(classResourcesUsed: used);
  }
}

class _ClassResourceLine extends StatelessWidget {
  const _ClassResourceLine({
    required this.resource,
    required this.current,
    required this.onSetCurrent,
    this.onEdit,
    this.onDelete,
  });

  final CharacterClassResource resource;
  final int current;
  final ValueChanged<int> onSetCurrent;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resource.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: '资源操作',
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑资源')),
                      PopupMenuItem(value: 'delete', child: Text('删除资源')),
                    ],
                  ),
              ],
            ),
            Text(
              '${resource.name} $current/${resource.maximum}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(_resourceRecoveryLabel(resource.recovery)),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: resource.maximum == 0 ? 0 : current / resource.maximum,
            ),
            const SizedBox(height: 8),
            if (resource.maximum <= 8)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var index = 0; index < resource.maximum; index++)
                    IconButton.filledTonal(
                      key: Key('resource-pip-${resource.id}-$index'),
                      tooltip: '设置${resource.name}为${index + 1}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          onSetCurrent(index < current ? index : index + 1),
                      icon: Icon(
                        index < current ? Icons.circle : Icons.circle_outlined,
                        size: 16,
                      ),
                    ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _setNumericCurrent(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('设置当前值'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setNumericCurrent(BuildContext context) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ResourceCurrentSheet(
        name: resource.name,
        current: current,
        maximum: resource.maximum,
      ),
    );
    if (result != null) onSetCurrent(result);
  }
}

class _HpAdjustmentSheet extends StatefulWidget {
  const _HpAdjustmentSheet();

  @override
  State<_HpAdjustmentSheet> createState() => _HpAdjustmentSheetState();
}

class _HpAdjustmentSheetState extends State<_HpAdjustmentSheet> {
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('调整生命值', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('hp-quick-value-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数值',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monitor_heart_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(-_positiveValue),
                    icon: const Icon(Icons.heart_broken_outlined),
                    label: const Text('受到伤害'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).pop(_positiveValue),
                    icon: const Icon(Icons.healing_outlined),
                    label: const Text('恢复 HP'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int get _positiveValue {
    final parsed = int.tryParse(_controller.text.trim());
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }
}

class _ResourceCurrentSheet extends StatefulWidget {
  const _ResourceCurrentSheet({
    required this.name,
    required this.current,
    required this.maximum,
  });

  final String name;
  final int current;
  final int maximum;

  @override
  State<_ResourceCurrentSheet> createState() => _ResourceCurrentSheetState();
}

class _ResourceCurrentSheetState extends State<_ResourceCurrentSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.current}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '当前值（0-${widget.maximum}）',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(_controller.text.trim());
                Navigator.of(context).pop(
                  (value ?? widget.current).clamp(0, widget.maximum).toInt(),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<ContentEntry?> _pickContentEntry(
  BuildContext context, {
  required String title,
  required List<ContentEntry> entries,
}) {
  var query = '';
  return showModalBottomSheet<ContentEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final filtered = entries
            .where((entry) {
              if (query.isEmpty) return true;
              final normalized = query.toLowerCase();
              return entry.name.toLowerCase().contains(normalized) ||
                  entry.summary.toLowerCase().contains(normalized);
            })
            .toList(growable: false);
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SearchBar(
                    hintText: '搜索名称',
                    leading: const Icon(Icons.search),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('没有可添加的条目'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            return ListTile(
                              title: Text(entry.name),
                              subtitle: entry.summary.isEmpty
                                  ? Text(entry.type)
                                  : Text(
                                      entry.summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => Navigator.of(context).pop(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<(String, String)?> _showNameDescriptionDialog(
  BuildContext context, {
  required String title,
}) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '说明（可选）',
                border: OutlineInputBorder(),
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
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop((name, descriptionController.text));
          },
          child: const Text('添加'),
        ),
      ],
    ),
  );
  nameController.dispose();
  descriptionController.dispose();
  return result;
}

Future<CharacterClassResource?> _showResourceDialog(
  BuildContext context, {
  CharacterClassResource? initial,
}) async {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final maximumController = TextEditingController(
    text: '${initial?.maximum ?? 1}',
  );
  var recovery = initial?.recovery ?? 'longRest';
  final result = await showDialog<CharacterClassResource>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(initial == null ? '添加资源' : '编辑资源'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('resource-name-field'),
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '资源名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('resource-maximum-field'),
                controller: maximumController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '最大次数',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('resource-recovery-field'),
                initialValue: recovery,
                decoration: const InputDecoration(
                  labelText: '恢复规则',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'shortRest', child: Text('短休恢复')),
                  DropdownMenuItem(value: 'longRest', child: Text('长休恢复')),
                  DropdownMenuItem(value: 'none', child: Text('不自动恢复')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => recovery = value);
                },
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
            onPressed: () {
              final name = nameController.text.trim();
              final maximum = int.tryParse(maximumController.text.trim()) ?? 0;
              if (name.isEmpty || maximum <= 0) return;
              final id =
                  initial?.id ??
                  'custom-resource-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';
              Navigator.of(context).pop(
                CharacterClassResource(
                  id: id.isEmpty
                      ? 'custom-resource-${DateTime.now().microsecondsSinceEpoch}'
                      : id,
                  name: name,
                  maximum: maximum,
                  recovery: recovery,
                ),
              );
            },
            child: Text(initial == null ? '添加' : '保存'),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  maximumController.dispose();
  return result;
}

String _resourceRecoveryLabel(String recovery) {
  return switch (recovery) {
    'shortRest' => '短休恢复',
    'none' => '不自动恢复',
    _ => '长休恢复',
  };
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
    this.entry,
    this.onOpen,
    this.onConsume,
    this.onToggleEquipped,
    this.onToggleAttuned,
    this.onDelete,
  });

  final Map<String, Object> item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ContentEntry? entry;
  final VoidCallback? onOpen;
  final VoidCallback? onConsume;
  final VoidCallback? onToggleEquipped;
  final VoidCallback? onToggleAttuned;
  final VoidCallback? onDelete;

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
            subtitle: Text(
              [
                if (entry != null) entry!.type,
                if (item['equipped'] == true) '已装备',
                if (item['attuned'] == true) '已同调',
                if ('${item['description'] ?? ''}'.trim().isNotEmpty)
                  '${item['description']}',
              ].join(' · '),
            ),
            onTap: onOpen,
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
                if (onDelete != null ||
                    onToggleEquipped != null ||
                    onToggleAttuned != null)
                  PopupMenuButton<String>(
                    tooltip: '更多装备操作',
                    onSelected: (value) {
                      switch (value) {
                        case 'equipped':
                          onToggleEquipped?.call();
                        case 'attuned':
                          onToggleAttuned?.call();
                        case 'delete':
                          onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'equipped',
                        child: Text(item['equipped'] == true ? '卸下' : '装备'),
                      ),
                      PopupMenuItem(
                        value: 'attuned',
                        child: Text(item['attuned'] == true ? '解除同调' : '同调'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
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

List<Map<String, Object?>> _objectMaps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
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
