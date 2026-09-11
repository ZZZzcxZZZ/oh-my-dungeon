import '../../content/domain/content_entry.dart';
import 'character.dart';
import 'dnd5e_rules.dart';

/// 角色卡"动作"页展示的一次武器攻击。
class WeaponAttackAction {
  const WeaponAttackAction({
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

/// 武器攻击派生：**只读物品条目自身的声明**（契约 §3.6 第 3 步）。
///
/// - 伤害来自 `structured.damage`（如 `"1d8 挥砍"`）；
/// - 攻击属性来自 `structured.ability` / `finesse` / `category`（[Dnd5eRules.weaponAbility]）；
/// - **未声明伤害的物品不产出攻击**（不猜物品名，也不按相近名字回退）；
/// - 灵巧武器用 str / dex 中较高者。
abstract final class WeaponAttackDerivation {
  /// `1d8` / `2d6+1` 后跟可选伤害类型（`1d8 挥砍`、`1d8 穿刺`）。
  static final _damagePattern = RegExp(r'^(\d*d\d+(?:[+-]\d+)?)\s*(\S+)?$');

  static List<WeaponAttackAction> derive({
    required CharacterSheet character,
    required Iterable<ContentEntry> contentEntries,
  }) {
    final byId = <String, ContentEntry>{
      for (final entry in contentEntries) entry.id: entry,
    };
    final attacks = <WeaponAttackAction>[];
    for (final item in _normalizeInventory(character.inventoryList)) {
      final entryId = '${item['entryId'] ?? ''}'.trim();
      if (entryId.isEmpty) continue;
      final entry = byId[entryId];
      if (entry == null) continue;
      final damage = '${entry.structured['damage'] ?? ''}'.trim();
      final match = _damagePattern.firstMatch(damage);
      // 未声明伤害（或声明无法解析）→ 不产出攻击。
      if (match == null) continue;
      final die = match.group(1)!;
      final damageType = (match.group(2) ?? '').trim();
      final ability = _attackAbility(character, entry);
      final attackBonus = Dnd5eRules.attackBonus(
        abilities: character.abilityMap,
        level: character.level,
        ability: ability,
      );
      final damageFormula = Dnd5eRules.damageFormula(
        Dnd5eWeaponProfile(
          name: entry.name,
          ability: ability,
          damageDie: die,
          damageType: damageType,
        ),
        character.abilityMap,
      );
      attacks.add(
        WeaponAttackAction(
          name: entry.name,
          bonus: attackBonus,
          toHit: '${Dnd5eRules.formatModifier(attackBonus)} 命中',
          damage: '$damageFormula ${damageType.isEmpty ? '' : damageType}'
              .trim(),
          damageFormula: damageFormula,
          damageType: damageType,
        ),
      );
    }
    return attacks;
  }

  /// 攻击属性：判据只有一份，在 [Dnd5eRules.weaponAbility]（含灵巧的 STR/DEX
  /// 较优判断）；这里只把角色属性传进去，不再各写一遍。
  static String _attackAbility(CharacterSheet character, ContentEntry entry) {
    return Dnd5eRules.weaponAbility(
          entry.structured,
          abilities: character.abilityMap,
        ) ??
        'str';
  }

  static List<Map<String, Object?>> _normalizeInventory(List<Object?> items) {
    return items
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}
