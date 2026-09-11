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
/// [spellSlotMaximums] / [classResources] / [usesPactMagic] / [pactSlotMaximums] /
/// [preparedSpellMaximums] / [spellcastingAbility] / [classSavingThrows] /
/// [averageHitPoints] 保留旧签名作为**过渡 shim**（任务 8 迁移调用方后删除），
/// 内部同样只查档案，因此行为会随契约收紧（例如无法解析的职业不再有法术位）。
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

  static String formatModifier(int modifier) => rule_math.formatModifier(modifier);

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

  static String damageFormula(
    Dnd5eWeaponProfile weapon,
    Map<String, Object?> abilities,
  ) {
    final bonus = abilityBonus(abilities, weapon.ability);
    if (bonus == 0) return weapon.damageDie;
    return '${weapon.damageDie}${formatModifier(bonus)}';
  }

  /// 武器档案是**物品名 → 数值**的展示映射，不是职业表；删除它属于任务 8
  /// （改读物品条目自身声明的 `damage` / `category` / `finesse`）。
  static Dnd5eWeaponProfile? weaponProfile(String itemName) {
    final normalized = itemName.toLowerCase();
    for (final entry in _weaponProfiles.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return null;
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
  static String _slugFor({required String? entryId, required String classSummary}) {
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
    String? bestSlug;
    var bestLength = 0;
    candidates.forEach((needle, slug) {
      if (needle.length <= bestLength) return;
      if (normalized == needle) {
        bestSlug = slug;
        bestLength = needle.length;
        return;
      }
      if (!normalized.startsWith(needle)) return;
      final rest = normalized.substring(needle.length);
      if (!_aliasPrefixDelimiters.contains(rest[0])) return;
      bestSlug = slug;
      bestLength = needle.length;
    });
    // 档案里没有的职业（如自制职业）保持原样：查不到数值即"未声明"，不猜。
    return bestSlug ?? normalized;
  }

  static int? hitDieFor({String? entryId, required String classSummary}) =>
      resolveClassRules(entryId: entryId, classSummary: classSummary).hitDie;

  // ── 过渡 shim：签名不变，内部改为查档案（任务 8 迁移调用方后删除） ──

  static Map<String, int> spellSlotMaximums({
    required String classSummary,
    required int level,
  }) => spellSlotMaximumsFromRules(
    rules: resolveClassRules(entryId: null, classSummary: classSummary),
    level: level,
  );

  static List<Dnd5eClassResource> classResources({
    required String classSummary,
    required int level,
    Map<String, Object?> abilities = const <String, Object?>{},
  }) => classResourcesFromRules(
    rules: resolveClassRules(entryId: null, classSummary: classSummary),
    level: level,
    abilities: abilities,
  );

  static bool usesPactMagic(String classSummary) =>
      resolveClassRules(entryId: null, classSummary: classSummary).usesPactMagic;

  /// 契约魔法法术位（环阶 → 数量）：由档案的 `pact` 原型提供，不再有硬编码表。
  static Map<String, int> pactSlotMaximums(int level) {
    final pact = profile.progression('pact');
    if (pact == null) return const {};
    if (level < pact.minimumLevel) return const {};
    return pact.slots?.at(level) ?? const {};
  }

  static int? preparedSpellMaximums({
    required String classSummary,
    required int level,
  }) => resolveClassRules(
    entryId: null,
    classSummary: classSummary,
  ).preparedLimit(level);

  /// `mode == 'none'`（含"未声明"）返回 null：不使用施法就没有施法属性（§3.6）。
  static String? spellcastingAbility(String classSummary) =>
      resolveClassRules(entryId: null, classSummary: classSummary).spellcastingAbility;

  /// 2024 官方核心表：各职业豁免熟练（档案只按 slug 精确对齐，未声明即空集）。
  static Set<String> classSavingThrows(String classSummary) =>
      resolveClassRules(entryId: null, classSummary: classSummary).savingThrowAbilities;

  static int? spellSaveDc({
    required String classSummary,
    required Map<String, Object?> abilities,
    required int level,
  }) {
    final ability = spellcastingAbility(classSummary);
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
    if (usesPactMagic(classSummary)) return const {};
    return Map<String, int>.unmodifiable(used);
  }

  // ── 资源 ──

  static Map<String, int> classResourceMaximums({
    required String classSummary,
    required int level,
  }) {
    return {
      for (final resource in classResources(
        classSummary: classSummary,
        level: level,
      ))
        resource.id: resource.maximum,
    };
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
    final die = resolveClassRules(entryId: null, classSummary: className).hitDie;
    if (die == null) {
      // 未声明生命骰：不猜，只按体质调整值计，且总生命至少 1。
      return (abilityModifier(constitution) * level.clamp(1, 20)).clamp(1, 1 << 30);
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

  static const _weaponProfiles = {
    '长弓': Dnd5eWeaponProfile(
      name: '长弓',
      ability: 'dex',
      damageDie: '1d8',
      damageType: '穿刺',
    ),
    'longbow': Dnd5eWeaponProfile(
      name: '长弓',
      ability: 'dex',
      damageDie: '1d8',
      damageType: '穿刺',
    ),
    '短剑': Dnd5eWeaponProfile(
      name: '短剑',
      ability: 'dex',
      damageDie: '1d6',
      damageType: '穿刺',
    ),
    'shortsword': Dnd5eWeaponProfile(
      name: '短剑',
      ability: 'dex',
      damageDie: '1d6',
      damageType: '穿刺',
    ),
    '匕首': Dnd5eWeaponProfile(
      name: '匕首',
      ability: 'dex',
      damageDie: '1d4',
      damageType: '穿刺',
    ),
    'dagger': Dnd5eWeaponProfile(
      name: '匕首',
      ability: 'dex',
      damageDie: '1d4',
      damageType: '穿刺',
    ),
    '长剑': Dnd5eWeaponProfile(
      name: '长剑',
      ability: 'str',
      damageDie: '1d8',
      damageType: '挥砍',
    ),
    'longsword': Dnd5eWeaponProfile(
      name: '长剑',
      ability: 'str',
      damageDie: '1d8',
      damageType: '挥砍',
    ),
    '法杖': Dnd5eWeaponProfile(
      name: '法杖',
      ability: 'str',
      damageDie: '1d6',
      damageType: '钝击',
    ),
    'quarterstaff': Dnd5eWeaponProfile(
      name: '法杖',
      ability: 'str',
      damageDie: '1d6',
      damageType: '钝击',
    ),
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
