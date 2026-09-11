/// D&D 2024 纯运算。`Dnd5eRules` 的同名方法委托到这里，保证只有一份公式。
int abilityModifier(int score) => ((score - 10) / 2).floor();

int proficiencyBonus(int level) {
  final clamped = level.clamp(1, 20);
  return ((clamped - 1) ~/ 4) + 2;
}

String formatModifier(int modifier) => modifier >= 0 ? '+$modifier' : '$modifier';
