// character_detail_page.dart 的 part：共享分区容器、空态、投掷胶囊与属性块。
part of 'character_detail_page.dart';

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
