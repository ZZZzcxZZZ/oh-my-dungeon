import '../../content/domain/content_entry.dart';
import 'dnd5e_rules.dart';

class SpellSelectionRules {
  const SpellSelectionRules({
    required this.configured,
    this.mode,
    this.ability,
    this.listTags = const [],
    this.maximumSpellLevel = -1,
    this.maximum,
    this.maximumCantrips,
    this.maximumLeveledSpells,
  });

  const SpellSelectionRules.unconfigured()
    : configured = false,
      mode = null,
      ability = null,
      listTags = const [],
      maximumSpellLevel = -1,
      maximum = null,
      maximumCantrips = null,
      maximumLeveledSpells = null;

  final bool configured;
  final String? mode;
  final String? ability;
  final List<String> listTags;
  final int maximumSpellLevel;
  final int? maximum;
  final int? maximumCantrips;
  final int? maximumLeveledSpells;
}

abstract final class SpellSelectionPolicy {
  /// 法术选择规则：**只读新契约**（`structured.classRules.spellcasting` ∪ 内置档案，
  /// 条目优先），不再读旧的顶层 `structured.spellcasting.progression` 行数组。
  ///
  /// 取值全部经 [Dnd5eRules.resolveClassRules]：
  /// - `mode` / `ability` / `listTags` 来自解析出的 `spellcasting`；
  /// - `maximumSpellLevel` 来自 `resolved.maxSpellLevel(level)`（自身表 → 原型表）；
  /// - `maximumCantrips` / `maximumLeveledSpells` 来自 `cantripLimit` / `preparedLimit`
  ///   （只看职业自身，原型不承载这两列）。
  ///
  /// **未声明即未配置**：没有 `spellcasting` 声明、`mode == 'none'`，或该等级算不出
  /// 最高环阶时返回 [SpellSelectionRules.unconfigured]，绝不猜。
  static SpellSelectionRules rulesFor({
    required ContentEntry? classEntry,
    required int characterLevel,
  }) {
    final resolved = Dnd5eRules.resolveClassRules(
      entryId: classEntry?.id,
      classSummary: classEntry?.name ?? '',
      structured: classEntry?.structured ?? const <String, Object?>{},
    );
    final spellcasting = resolved.spellcasting;
    if (spellcasting == null || spellcasting.mode == 'none') {
      return const SpellSelectionRules.unconfigured();
    }
    final level = characterLevel.clamp(1, 20);
    final maximumSpellLevel = resolved.maxSpellLevel(level);
    if (maximumSpellLevel == null) {
      return const SpellSelectionRules.unconfigured();
    }

    return SpellSelectionRules(
      configured: true,
      mode: spellcasting.mode,
      ability: spellcasting.ability,
      listTags: spellcasting.listTags,
      maximumSpellLevel: maximumSpellLevel,
      maximumCantrips: resolved.cantripLimit(level),
      maximumLeveledSpells: resolved.preparedLimit(level),
    );
  }

  static List<ContentEntry> eligibleSpells({
    required Iterable<ContentEntry> entries,
    required SpellSelectionRules rules,
  }) {
    if (!rules.configured) return const [];

    final options = entries
        .where((entry) {
          if (entry.type != 'spell') return false;
          final level = spellLevel(entry);
          if (level == null || level > rules.maximumSpellLevel) return false;
          if (rules.listTags.isEmpty) return true;
          return entry.tags.any(rules.listTags.contains);
        })
        .toList(growable: false);

    return options..sort((left, right) {
      final byLevel = spellLevel(left)!.compareTo(spellLevel(right)!);
      return byLevel != 0 ? byLevel : left.name.compareTo(right.name);
    });
  }

  static int? spellLevel(ContentEntry entry) {
    return _intValue(entry.structured['level']);
  }

  static String spellSchool(ContentEntry entry) {
    return '${entry.structured['school'] ?? ''}'.trim();
  }

  static int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
