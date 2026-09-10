import '../../content/domain/content_entry.dart';
import 'dnd5e_rules.dart';

class StructuredSkillChoice {
  const StructuredSkillChoice({required this.count, required this.options});

  static const empty = StructuredSkillChoice(count: 0, options: []);

  final int count;
  final List<String> options;
}

/// 职业初始装备的选择上限。来自 class entry 的
/// `structured.startingEquipmentChoice.maximum`，用于角色创建向导"装备"步骤
/// 限制玩家自由挑选的装备数量。null 表示该职业不使用自由挑选模式
/// （全部由 equipmentBundle 授予）。
class StartingEquipmentChoice {
  const StartingEquipmentChoice({required this.maximum});

  final int maximum;
}

abstract final class StructuredClassRules {
  static Set<String> savingThrowAbilities(ContentEntry? entry) {
    final structured = entry?.structured;
    if (structured == null) return const <String>{};
    final normalized = structured['savingThrowAbilities'];
    if (normalized is Iterable) {
      return normalized
          .map((value) => _abilityKey('$value'))
          .whereType<String>()
          .toSet();
    }

    final legacy = '${structured['savingThrows'] ?? ''}';
    return {
      for (final ability in Dnd5eRules.abilityLabels.entries)
        if (legacy.contains(ability.value)) ability.key,
    };
  }

  static StructuredSkillChoice skillChoice(ContentEntry? entry) {
    final structured = entry?.structured;
    if (structured == null) return StructuredSkillChoice.empty;
    final normalized = structured['skillChoice'];
    if (normalized is Map) {
      final map = Map<String, Object?>.from(normalized);
      final options = _validSkills(map['options']);
      final count = (map['count'] as num?)?.toInt() ?? 0;
      return StructuredSkillChoice(
        count: count.clamp(0, options.length),
        options: options,
      );
    }

    final legacy = '${structured['skills'] ?? ''}'.trim();
    final freeChoice = RegExp(r'任选\s*(\d+)\s*项').firstMatch(legacy);
    if (freeChoice != null) {
      final options = Dnd5eRules.skills
          .map((skill) => skill.name)
          .toList(growable: false);
      final count = int.tryParse(freeChoice.group(1) ?? '') ?? 0;
      return StructuredSkillChoice(
        count: count.clamp(0, options.length),
        options: options,
      );
    }
    final match = RegExp(
      r'选择\s*(\d+)\s*项\s*[：:]?\s*(.*)',
      dotAll: true,
    ).firstMatch(legacy);
    if (match == null) return StructuredSkillChoice.empty;
    final count = int.tryParse(match.group(1) ?? '') ?? 0;
    final options = _validSkills(
      (match.group(2) ?? '').split(RegExp(r'[、，,；;]|或')),
    );
    return StructuredSkillChoice(
      count: count.clamp(0, options.length),
      options: options,
    );
  }

  /// 准备法术数量上限。D&D 2024 prepared 模型：
  /// 1. 内容包若显式提供 `structured.preparedSpells`（等级 → 数量），以它为准；
  /// 2. 否则使用 [Dnd5eRules.preparedSpellMaximums] 的官方逐级表（按职业）；
  /// 3. 非核心/自制职业回退到"施法属性调整值 + 职业等级"（最低 1）。
  ///
  /// 返回 null 表示该职业不使用 prepared 模型（如内容包未声明
  /// `structured.preparedSpellcasting: true`）。
  ///
  /// 输入 [abilities] 是角色六维属性值，[level] 是职业等级。
  static int? preparedSpellLimit(
    ContentEntry? entry, {
    required Map<String, int> abilities,
    required int level,
  }) {
    final structured = entry?.structured;
    if (structured == null) return null;
    final isPrepared = structured['preparedSpellcasting'];
    if (isPrepared is! bool || !isPrepared) return null;

    final explicit = _explicitPreparedTable(structured['preparedSpells']);
    if (explicit != null) {
      return explicit[level.clamp(1, 20) - 1];
    }

    final official = Dnd5eRules.preparedSpellMaximums(
      classSummary: entry?.name ?? '',
      level: level,
    );
    if (official != null) return official;

    final abilityKey = _abilityKey('${structured['spellcastingAbility']}');
    if (abilityKey == null) return null;
    final score = abilities[abilityKey] ?? 10;
    final modifier = Dnd5eRules.abilityModifier(score);
    final total = modifier + level;
    return total < 1 ? 1 : total;
  }

  /// 解析内容包显式给出的逐级准备法术表，支持两种写法：
  /// - `{'1': 6, '5': 12}`：按"不超过当前等级的最大档位"取值；
  /// - `[4, 5, 6, ...]`：按等级顺序取值（长度不足 20 时沿用最后一档）。
  static List<int>? _explicitPreparedTable(Object? raw) {
    final byLevel = <int, int>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final level = int.tryParse('${entry.key}');
        final value = entry.value is num
            ? (entry.value as num).toInt()
            : int.tryParse('${entry.value}');
        if (level != null && level >= 1 && value != null && value >= 0) {
          byLevel[level] = value;
        }
      }
    } else if (raw is List) {
      for (var index = 0; index < raw.length; index++) {
        final item = raw[index];
        final value = item is num ? item.toInt() : int.tryParse('$item');
        if (value != null && value >= 0) byLevel[index + 1] = value;
      }
    }
    if (byLevel.isEmpty) return null;

    final levels = byLevel.keys.toList()..sort();
    var current = byLevel[levels.first]!;
    final table = <int>[];
    for (var level = 1; level <= 20; level++) {
      current = byLevel[level] ?? current;
      table.add(current);
    }
    return table;
  }

  /// 职业初始装备自由挑选上限。null 表示该职业未声明自由挑选模式。
  static StartingEquipmentChoice? startingEquipmentChoice(ContentEntry? entry) {
    final structured = entry?.structured;
    if (structured == null) return null;
    final raw = structured['startingEquipmentChoice'];
    if (raw is! Map) return null;
    final maximum = (raw['maximum'] as num?)?.toInt();
    if (maximum == null || maximum <= 0) return null;
    return StartingEquipmentChoice(maximum: maximum);
  }

  static String? _abilityKey(String value) {
    final normalized = value.trim().toLowerCase();
    if (Dnd5eRules.abilityLabels.containsKey(normalized)) return normalized;
    for (final ability in Dnd5eRules.abilityLabels.entries) {
      if (normalized == ability.value.toLowerCase()) return ability.key;
    }
    return null;
  }

  static List<String> _validSkills(Object? raw) {
    if (raw is! Iterable) return const [];
    final known = Dnd5eRules.skills.map((skill) => skill.name).toSet();
    const aliases = <String, String>{
      '特技': '杂技',
      '体操': '杂技',
      '游说': '说服',
      '医疗': '医药',
      '生存': '求生',
    };
    return raw
        .map((value) => '$value'.trim())
        .map((value) => aliases[value] ?? value)
        .where(known.contains)
        .toSet()
        .toList(growable: false);
  }
}
