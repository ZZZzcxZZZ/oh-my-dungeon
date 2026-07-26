import 'character.dart';

class CharacterImportChange {
  const CharacterImportChange({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;
}

class CharacterImportDiff {
  const CharacterImportDiff(this.changes);

  factory CharacterImportDiff.compare(
    CharacterSheet? before,
    CharacterSheet after,
  ) {
    if (before == null) {
      return const CharacterImportDiff([
        CharacterImportChange(label: '角色', before: '不存在', after: '新建'),
      ]);
    }
    final changes = <CharacterImportChange>[];
    void add(String label, Object? oldValue, Object? newValue) {
      if ('$oldValue' == '$newValue') return;
      changes.add(
        CharacterImportChange(
          label: label,
          before: '$oldValue',
          after: '$newValue',
        ),
      );
    }

    add('名称', before.name, after.name);
    add('等级', before.level, after.level);
    add('种族', before.raceSummary, after.raceSummary);
    add('职业', before.classSummary, after.classSummary);
    add(
      '生命值',
      '${before.currentHp}/${before.maxHp}',
      '${after.currentHp}/${after.maxHp}',
    );
    add('护甲等级', before.armorClass, after.armorClass);
    add('速度', before.speed, after.speed);
    add('先攻', before.initiativeBonus, after.initiativeBonus);
    add('属性', before.abilityMap, after.abilityMap);
    add('装备', before.inventoryList, after.inventoryList);
    add('货币', before.currencyMap, after.currencyMap);
    add('笔记', before.notes, after.notes);
    return CharacterImportDiff(changes);
  }

  final List<CharacterImportChange> changes;
}
