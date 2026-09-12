// character_detail_page.dart 的 part：动作面板、d20 投掷与武器攻击行。
part of 'character_detail_page.dart';

class _ActionsPanel extends StatefulWidget {
  const _ActionsPanel({
    required this.character,
    this.contentEntries = const <ContentEntry>[],
    this.diceRoller,
    this.onRoll,
    this.onSaveCharacter,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
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
    final attacks = _deriveWeaponAttacks(
      character: character,
      contentEntries: widget.contentEntries,
    );
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

  final WeaponAttackAction attack;
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

/// 武器攻击现在由物品条目自身的声明派生（[WeaponAttackDerivation]），
/// 这里只做一次模型转换：动作页的渲染与掷骰仍用同一个 DTO。
List<WeaponAttackAction> _deriveWeaponAttacks({
  required CharacterSheet character,
  required List<ContentEntry> contentEntries,
}) => WeaponAttackDerivation.derive(
  character: character,
  contentEntries: contentEntries,
);

/// 空的法术位 / 职业资源区的文案（契约 §3.12，三分支）。
///
/// 三者**不是**同一件事，文案必须分开口径：
/// 1. [rangeLevelLabel] 非 `null` → 职业身份未声明（解析不到档案）：
///    说"未声明"，**不**断言成"该职业没有法术位 / 资源"；
/// 2. `max == null` 的已声明职业（rogue / monk 这类没有等级表的）→ 调用方给的
///    [emptyLabel]（"暂无法术位" / "暂无可追踪资源"）；
/// 3. 有等级声明但当前等级不在范围内 → [UndeclaredLevelNotice] 的等级级文案。
///
/// 分支判断本身就是这个函数，因此"法术位区与资源区口径一致"是结构保证，
/// 不靠两处各写一遍。
Widget _emptyClassValueNotice({
  required String? rangeLevelLabel,
  required bool levelUndeclared,
  required String emptyLabel,
  required TextStyle? style,
}) {
  final rangeLabel = rangeLevelLabel;
  if (rangeLabel != null) return UndeclaredLevelNotice(label: rangeLabel);
  if (levelUndeclared) return const UndeclaredLevelNotice();
  return Text(emptyLabel, style: style);
}
