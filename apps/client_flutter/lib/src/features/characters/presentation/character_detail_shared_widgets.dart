// character_detail_page.dart 的 part：共享分区容器、空态、投掷胶囊与属性块。
part of 'character_detail_page.dart';

/// 走**用户覆盖**的规则解析（角色详情页的**唯一**口径，0.4-1 / L）。
///
/// 详情页里所有"临时按规则解析一次"的地方（无持久化派生快照时回退解析、短休判定
/// 契约魔法）都必须走这里：带上 `data.ruleOverrides` 的 `disabledOriginIds` /
/// `pinned` 与包 priority，否则"关闭覆盖"只在数值路径生效、行为路径仍按旧规则
/// （同屏自相矛盾）。`packagePriorities` 与建档 / 再派生**同一份**（决策 D2）。
///
/// [overrides] 是跨包职业规则声明索引（决策 D3）：**必须**传，否则勘误包声明的列
/// （典型是 `spellcasting.archetype: pact`）在行为路径上看不见，"关闭该勘误来源"
/// 也就无从生效——派生快照走的是 `Dnd5eRules.resolveClassRules(..., overrides:)`，
/// 两条路径必须同一口径。
ResolvedClassRules _resolveRulesWithOverrides(
  CharacterSheet character,
  Map<String, int> packagePriorities, {
  RuleOverrideIndex overrides = RuleOverrideIndex.empty,
}) {
  final identity = character.dataMap['classIdentity'];
  final entryId = identity is Map ? identity['entryId'] as String? : null;
  final ruleOverrides = CharacterRuleOverrides.fromCharacter(character);
  return Dnd5eRules.resolveClassRules(
    entryId: entryId,
    classSummary: character.classSummary,
    overrides: overrides,
    entryPriority:
        packagePriorities[RuleOverrideDeclaration.packageIdOf(entryId ?? '')] ??
        0,
    disabledOriginIds: ruleOverrides.disabledOriginIds,
    pinnedOrigins: ruleOverrides.pinned,
  );
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
      padding: const EdgeInsets.only(bottom: 16),
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
          const SizedBox(height: 8),
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
          padding: const EdgeInsets.all(12),
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
