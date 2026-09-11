import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../rules/domain/class_rule_set.dart';
import '../../rules/domain/rule_diagnostic.dart';
import '../../rules/domain/rule_math.dart' as rule_math;
import '../../rules/domain/rule_profile.dart';
import '../../rules/domain/rule_profile_resolver.dart';

/// D&D 5e (2024) 规则查询门面。
///
/// **所有随职业变化的数值只来自档案**：内置档案（[profile]）与角色所用条目的
/// `structured.classRules` 做字段级合并（[resolveClassRules]），未声明即不猜。
/// 本文件里**不存在**以职业名（中文或英文）为键的规则表，也没有任何职业名子串
/// 匹配（契约 §10 第 1 条）。
///
/// 纯运算（属性调整值 / 熟练加值 / 加值格式化）只有一份实现，在
/// `features/rules/domain/rule_math.dart`；本类同名方法只是委托，避免第二份公式。
///
/// 任务 8 已删除全部过渡 shim（`spellSlotMaximums` / `classResources` /
/// `usesPactMagic` / `pactSlotMaximums` / `preparedSpellMaximums` /
/// `spellcastingAbility` / `classSavingThrows`）：随职业变化的数值一律经
/// [resolveClassRules] 读取，调用方必须用条目身份（[resolveClassSlug] 只服务
/// UI 预设，不参与规则判断）。
class Dnd5eRules {
  const Dnd5eRules._();

  /// 启动时装配的内置规则档案（tier 0）。
  ///
  /// 这里是**装配入口**，不是表查询逻辑：未装配时任何读取都抛错，绝不返回
  /// null / 空档案兜底（契约 §4.4：内置档案缺失或非法即启动 fail-fast）。
  static RuleProfile? _profile;

  static RuleProfile get profile {
    final profile = _profile;
    if (profile == null) {
      throw StateError(
        'Dnd5eRules 尚未配置规则档案：请在启动时 await Dnd5eRules.configure(...)',
      );
    }
    return profile;
  }

  static Future<void> configure(RuleProfile profile) async {
    if (_profile != null) {
      throw StateError('规则档案已配置，重复 configure 被拒绝');
    }
    _profile = profile;
  }

  @visibleForTesting
  static void resetForTests() => _profile = null;

  /// 展示用的属性中文标签（UI 文案，不是规则数值）。
  /// 属性键本身由档案的 `abilities` 声明；两者的键集合由
  /// `test/rules/builtin_rule_profile_test.dart` 的
  /// 「abilityLabels 的键集合与档案 abilities 一致」断言守卫。
  static const abilityLabels = {
    'str': '力量',
    'dex': '敏捷',
    'con': '体质',
    'int': '智力',
    'wis': '感知',
    'cha': '魅力',
  };

  static const skills = [
    Dnd5eSkill(name: '杂技', ability: 'dex'),
    Dnd5eSkill(name: '驯兽', ability: 'wis'),
    Dnd5eSkill(name: '奥秘', ability: 'int'),
    Dnd5eSkill(name: '运动', ability: 'str'),
    Dnd5eSkill(name: '欺瞒', ability: 'cha'),
    Dnd5eSkill(name: '历史', ability: 'int'),
    Dnd5eSkill(name: '洞悉', ability: 'wis'),
    Dnd5eSkill(name: '威吓', ability: 'cha'),
    Dnd5eSkill(name: '调查', ability: 'int'),
    Dnd5eSkill(name: '医药', ability: 'wis'),
    Dnd5eSkill(name: '自然', ability: 'int'),
    Dnd5eSkill(name: '察觉', ability: 'wis'),
    Dnd5eSkill(name: '表演', ability: 'cha'),
    Dnd5eSkill(name: '说服', ability: 'cha'),
    Dnd5eSkill(name: '宗教', ability: 'int'),
    Dnd5eSkill(name: '巧手', ability: 'dex'),
    Dnd5eSkill(name: '隐匿', ability: 'dex'),
    Dnd5eSkill(name: '求生', ability: 'wis'),
  ];

  static const defaultAbilities = {
    'str': 10,
    'dex': 10,
    'con': 10,
    'int': 10,
    'wis': 10,
    'cha': 10,
  };

  // ── 纯运算：唯一公式来源是 rule_math.dart，这里只做委托 ──

  static int abilityModifier(int score) => rule_math.abilityModifier(score);

  static String formatModifier(int modifier) =>
      rule_math.formatModifier(modifier);

  static int proficiencyBonus(int level) => rule_math.proficiencyBonus(level);

  static int abilityScore(Map<String, Object?> abilities, String ability) {
    final value = abilities[ability];
    if (value is num) return value.toInt();
    return defaultAbilities[ability] ?? 10;
  }

  static int abilityBonus(Map<String, Object?> abilities, String ability) {
    return abilityModifier(abilityScore(abilities, ability));
  }

  static int saveBonus({
    required String ability,
    required Map<String, Object?> abilities,
    required int level,
    required bool proficient,
  }) {
    return abilityBonus(abilities, ability) +
        (proficient ? proficiencyBonus(level) : 0);
  }

  static int skillBonus({
    required String skillName,
    required Map<String, Object?> abilities,
    required int level,
    required bool proficient,
  }) {
    final skill = skills.firstWhere(
      (item) => item.name == skillName,
      orElse: () => Dnd5eSkill(name: skillName, ability: 'int'),
    );
    return abilityBonus(abilities, skill.ability) +
        (proficient ? proficiencyBonus(level) : 0);
  }

  static int baseArmorClass(
    Map<String, Object?> abilities, {
    int shieldBonus = 0,
  }) {
    return 10 + abilityBonus(abilities, 'dex') + shieldBonus;
  }

  static int initiativeBonus(Map<String, Object?> abilities) {
    return abilityBonus(abilities, 'dex');
  }

  static int attackBonus({
    required Map<String, Object?> abilities,
    required int level,
    required String ability,
    bool proficient = true,
  }) {
    return abilityBonus(abilities, ability) +
        (proficient ? proficiencyBonus(level) : 0);
  }

  /// [Dnd5eWeaponProfile] 只是伤害公式的入参载体（攻击属性 + 伤害骰 + 伤害类型），
  /// **不是物品名 → 数值的映射表**：武器数值一律来自物品条目自身的声明
  /// （`structured.damage` / `category` / `ability` / `finesse`）。
  static String damageFormula(
    Dnd5eWeaponProfile weapon,
    Map<String, Object?> abilities,
  ) {
    final bonus = abilityBonus(abilities, weapon.ability);
    if (bonus == 0) return weapon.damageDie;
    return '${weapon.damageDie}${formatModifier(bonus)}';
  }

  /// 武器是否灵巧：只读条目声明（`finesse: true`，或 `properties` / `category`
  /// 文本含「灵巧」）。真实 PHB 条目的特性写在 `properties`（如 `"灵巧，轻型"`），
  /// `category` 只写类别（如 `"军用武器"`）。
  static bool isFinesse(Map<String, Object?>? structured) {
    if (structured == null) return false;
    if (structured['finesse'] == true) return true;
    return _weaponText(structured).contains('灵巧');
  }

  /// `properties` 与 `category` 的拼接文本：真实物品条目把武器特性分散在这两处，
  /// 文本判据只在这里拼一次，[isFinesse] 与 [weaponAbility] 共用。
  static String _weaponText(Map<String, Object?> structured) =>
      '${structured['properties'] ?? ''} ${structured['category'] ?? ''}';

  /// 武器攻击属性：**只读物品条目的声明**，不按物品名猜。
  ///
  /// 判据顺序（唯一实现，[WeaponAttackDerivation] 也必须走这里，不再各写一份）：
  /// 1. `structured.ability` ∈ {str, dex} → 用它；
  /// 2. `properties` / `category` 含「弹药」或「远程」→ dex（真实长弓写
  ///    `properties: "弹药（射程 150/600），重型，双手"`，`category` 不含「远程」）；
  /// 3. `finesse: true` 或 `properties` / `category` 含「灵巧」→ 取 STR/DEX 较优者
  ///    （提供 [abilities] 时比较调整值，平手取 dex；未提供时取 dex）；
  /// 4. 否则 str。
  static String? weaponAbility(
    Map<String, Object?>? structured, {
    Map<String, Object?>? abilities,
  }) {
    if (structured == null) return null;
    final declared = '${structured['ability'] ?? ''}'.trim().toLowerCase();
    if (declared == 'str' || declared == 'dex') return declared;
    final text = _weaponText(structured);
    if (text.contains('弹药') || text.contains('远程')) return 'dex';
    if (isFinesse(structured)) {
      if (abilities == null) return 'dex';
      final dex = abilityBonus(abilities, 'dex');
      final str = abilityBonus(abilities, 'str');
      return dex >= str ? 'dex' : 'str';
    }
    return 'str';
  }

  // ── 职业规则解析（唯一的职业身份入口） ──

  /// 由一个职业条目解析出的规则形态（条目声明 ∪ 内置档案，条目优先）。
  ///
  /// `classSummary` 只用于**过渡期**把老角色的散文展示名解析成 slug
  /// （见 [_slugFor]）；条目身份以 [entryId] 为准，规则判断只认解析出的 slug。
  static ResolvedClassRules resolveClassRules({
    required String? entryId,
    required String classSummary,
    Map<String, Object?> structured = const <String, Object?>{},
    List<RuleDiagnostic>? diagnostics,
  }) {
    final slug = _slugFor(entryId: entryId, classSummary: classSummary);
    final rawClassRules = structured['classRules'];
    final entryRules = rawClassRules is Map
        ? ClassRuleSet.parse(
            Map<String, Object?>.from(rawClassRules),
            path: r'$.structured.classRules',
            diagnostics: diagnostics ?? <RuleDiagnostic>[],
          )
        : null;
    return RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: slug,
      entryRules: entryRules,
      entryId: entryId,
    );
  }

  /// 档案 `classAliases` 分隔符（契约 §3.6 第 2 步）：只有"展示名"可用时，
  /// 别名后紧跟其中之一才算前缀命中，保证 `星界游侠` 不会命中 `游侠`。
  static const _aliasPrefixDelimiters = {'（', '(', ' ', '-', '/'};

  /// slug：条目 id 的最后一段（契约 §3.6 的规范对齐键）；没有条目身份时，
  /// 用展示名归一化后按档案做**精确相等**或**`<别名><分隔符>` 前缀**匹配
  /// （候选集只有档案里的职业名 / 别名 / slug，不写死任何名字）。**禁止裸子串
  /// 匹配**：`星界游侠` 与任何候选都不构成前缀关系，因此不命中 `游侠`。
  ///
  /// 双语展示名（`法师 / Wizard`、`战士 / Fighter`）按分隔符切成片段后逐段尝试，
  /// 每段仍只用上面两条规则判断——这是 `startsWith(needle)` 加分隔符白名单的
  /// 直接推论，不是放宽的子串匹配。
  static String _slugFor({
    required String? entryId,
    required String classSummary,
  }) {
    final id = entryId?.trim() ?? '';
    if (id.isNotEmpty) {
      final slug = id.split('/').last.trim().toLowerCase();
      if (slug.isNotEmpty) return slug;
    }
    final normalized = classSummary.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    final candidates = <String, String>{
      for (final entry in profile.aliases.entries)
        if (entry.key.isNotEmpty) entry.key: entry.value,
      for (final slug in profile.classes.keys)
        if (slug.isNotEmpty) slug: slug,
    };

    String? match(String segment) {
      String? bestSlug;
      var bestLength = 0;
      candidates.forEach((needle, slug) {
        if (needle.length <= bestLength) return;
        if (segment == needle) {
          bestSlug = slug;
          bestLength = needle.length;
          return;
        }
        if (!segment.startsWith(needle)) return;
        final rest = segment.substring(needle.length);
        if (!_aliasPrefixDelimiters.contains(rest[0])) return;
        bestSlug = slug;
        bestLength = needle.length;
      });
      return bestSlug;
    }

    final first = match(normalized);
    if (first != null) return first;
    // 双语展示名：`法师 / Wizard` → 逐段（`法师` 已由上面的前缀规则命中，这里覆盖
    // `英文 / 中文` 或前后带括号说明的写法）。
    for (final segment in normalized.split(RegExp(r'[/()（）\-]'))) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      final slug = match(trimmed);
      if (slug != null) return slug;
    }
    // 档案里没有的职业（如自制职业）保持原样：查不到数值即"未声明"，不猜。
    return normalized;
  }

  /// 展示名 / 条目 id → 档案 slug 的唯一入口（UI 预设按它取键，不再写死中文职业名）。
  ///
  /// 与 [resolveClassRules] 内部用的是同一套 [_slugFor]：精确相等或
  /// `<别名><分隔符>` 前缀，**禁止裸子串**（`星界游侠` 不命中 `游侠`）。
  /// - 有 [entryId] 时以条目身份为准：slug 就是 id 最后一段（自制职业同样成立）；
  /// - 只有展示名、且档案里没有这个 slug 时返回空串，调用方据此走默认预设。
  static String resolveClassSlug({
    String? entryId,
    required String classSummary,
  }) {
    final id = entryId?.trim() ?? '';
    if (id.isNotEmpty) return _slugFor(entryId: id, classSummary: classSummary);
    final slug = _slugFor(entryId: null, classSummary: classSummary);
    return profile.classes.containsKey(slug) ? slug : '';
  }

  static int? hitDieFor({String? entryId, required String classSummary}) =>
      resolveClassRules(entryId: entryId, classSummary: classSummary).hitDie;

  static int? spellSaveDc({
    required String classSummary,
    required Map<String, Object?> abilities,
    required int level,
  }) {
    final ability = resolveClassRules(
      entryId: null,
      classSummary: classSummary,
    ).spellcastingAbility;
    if (ability == null) return null;
    return 8 + proficiencyBonus(level) + abilityBonus(abilities, ability);
  }

  /// 休息后仍处于消耗状态的法术位：长休清空；契约魔法短休同样清空。
  static Map<String, int> spellSlotsAfterRest({
    required String classSummary,
    required Map<String, int> used,
    required bool longRest,
  }) {
    if (longRest) return const {};
    final rules = resolveClassRules(entryId: null, classSummary: classSummary);
    if (rules.usesPactMagic) return const {};
    return Map<String, int>.unmodifiable(used);
  }

  // ── 资源 ──

  /// 职业资源上限表。**必须传 [abilities]**：`formula: ability:<key>` 的上限
  /// 由属性调整值决定（如诗人激励 = CHA 调整值），缺省 10 只是一种兜底。
  static Map<String, int> classResourceMaximums({
    required String classSummary,
    required int level,
    Map<String, Object?> abilities = const <String, Object?>{},
  }) {
    return classResourcesFromRules(
      rules: resolveClassRules(entryId: null, classSummary: classSummary),
      level: level,
      abilities: abilities,
    ).fold(<String, int>{}, (result, resource) {
      result[resource.id] = resource.maximum;
      return result;
    });
  }

  /// 休息后的职业资源"已用次数"。规则（2024）：
  /// - 长休：除 `none` 外全部恢复；
  /// - 短休：`shortRest` 全恢复，`shortRestOne` 只恢复 1 次（如野蛮人狂暴），
  ///   `longRest` / `none` 不变。
  static Map<String, int> classResourcesAfterRest({
    required Iterable<Dnd5eClassResource> resources,
    required Map<String, int> used,
    required bool longRest,
  }) {
    return {
      for (final resource in resources)
        resource.id: _resourceUsedAfterRest(
          resource,
          used[resource.id] ?? 0,
          longRest: longRest,
        ),
    };
  }

  static int _resourceUsedAfterRest(
    Dnd5eClassResource resource,
    int currentlyUsed, {
    required bool longRest,
  }) {
    final used = currentlyUsed.clamp(0, resource.maximum).toInt();
    if (longRest) return resource.recovery == 'none' ? used : 0;
    return switch (resource.recovery) {
      'shortRest' => 0,
      'shortRestOne' => (used - 1).clamp(0, resource.maximum).toInt(),
      _ => used,
    };
  }

  static String spellLevelLabel(String level) {
    return switch (level) {
      '1' => '一环',
      '2' => '二环',
      '3' => '三环',
      '4' => '四环',
      '5' => '五环',
      '6' => '六环',
      '7' => '七环',
      '8' => '八环',
      '9' => '九环',
      _ => '$level 环',
    };
  }

  // ── 2024 生命值 ──

  /// 2024 伤害/治疗结算结果。
  ///
  /// 规则：受到伤害时**先扣除临时生命值**，溢出部分才扣当前生命值，当前生命值
  /// 最低为 0；治疗只提高当前生命值且不超过上限，**不改变临时生命值**。
  static Dnd5eHitPoints applyHitPointDelta({
    required int current,
    required int maximum,
    required int temporary,
    required int delta,
  }) {
    final boundedMaximum = maximum < 0 ? 0 : maximum;
    var hp = current.clamp(0, boundedMaximum);
    var temp = temporary < 0 ? 0 : temporary;
    if (delta >= 0) {
      hp = (hp + delta).clamp(0, boundedMaximum);
      return Dnd5eHitPoints(current: hp, temporary: temp);
    }
    final damage = -delta;
    final absorbed = temp < damage ? temp : damage;
    temp -= absorbed;
    hp = (hp - (damage - absorbed)).clamp(0, boundedMaximum);
    return Dnd5eHitPoints(current: hp, temporary: temp);
  }

  static int averageHitPoints({
    required String className,
    required int level,
    required Map<String, Object?> abilities,
  }) {
    final constitution = abilityScore(abilities, 'con');
    final die = resolveClassRules(
      entryId: null,
      classSummary: className,
    ).hitDie;
    if (die == null) {
      // 未声明生命骰：不猜，只按体质调整值计，且总生命至少 1。
      return (abilityModifier(constitution) * level.clamp(1, 20)).clamp(
        1,
        1 << 30,
      );
    }
    return averageHitPointsForHitDie(
      hitDie: die,
      level: level,
      constitution: constitution,
    );
  }

  /// 按生命骰面数计算平均生命值。规则（2024）：
  /// 1 级取满骰 + 体质调整值；之后每级 `骰面/2 + 1 + 体质调整值`，
  /// 且每级至少获得 1 点生命。
  static int averageHitPointsForHitDie({
    required int hitDie,
    required int level,
    required int constitution,
  }) {
    final safeHitDie = hitDie <= 0 ? 8 : hitDie;
    final conBonus = abilityModifier(constitution);
    final clampedLevel = level.clamp(1, 20);
    final laterLevelAverage = (safeHitDie ~/ 2) + 1;
    final perLevelGain = (laterLevelAverage + conBonus).clamp(1, 1 << 30);
    final total = safeHitDie + conBonus + (clampedLevel - 1) * perLevelGain;
    return total.clamp(1, 1 << 30);
  }

  // ── 由"已解析规则"直接取值（任务 8 迁移调用方用，避免重复解析） ──

  static Map<String, int> spellSlotMaximumsFromRules({
    required ResolvedClassRules rules,
    required int level,
  }) => rules.spellSlots(level);

  static List<Dnd5eClassResource> classResourcesFromRules({
    required ResolvedClassRules rules,
    required int level,
    Map<String, Object?> abilities = const <String, Object?>{},
  }) => rules
      .resourcesAt(level, _abilityScores(abilities))
      .map(
        (r) => Dnd5eClassResource(
          id: r.id,
          name: r.name,
          maximum: r.maximum,
          recovery: r.recovery,
        ),
      )
      .toList(growable: false);

  /// 资源的 `formula: ability:<key>` 需要六个属性键都有值；缺省按 10（调整值 0）。
  static Map<String, int> _abilityScores(Map<String, Object?> abilities) => {
    for (final key in abilityLabels.keys) key: abilityScore(abilities, key),
  };
}

class Dnd5eSkill {
  const Dnd5eSkill({required this.name, required this.ability});

  final String name;
  final String ability;
}

/// 生命值结算结果（当前生命值 / 临时生命值）。
class Dnd5eHitPoints {
  const Dnd5eHitPoints({required this.current, required this.temporary});

  final int current;
  final int temporary;
}

class Dnd5eClassResource {
  const Dnd5eClassResource({
    required this.id,
    required this.name,
    required this.maximum,
    this.recovery = 'longRest',
  });

  final String id;
  final String name;
  final int maximum;
  final String recovery;
}

class Dnd5eWeaponProfile {
  const Dnd5eWeaponProfile({
    required this.name,
    required this.ability,
    required this.damageDie,
    required this.damageType,
  });

  final String name;
  final String ability;
  final String damageDie;
  final String damageType;
}
