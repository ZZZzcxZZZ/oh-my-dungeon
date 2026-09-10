class Dnd5eRules {
  const Dnd5eRules._();

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

  static int abilityModifier(int score) => ((score - 10) / 2).floor();

  static String formatModifier(int modifier) {
    return modifier >= 0 ? '+$modifier' : '$modifier';
  }

  static int proficiencyBonus(int level) {
    final clamped = level.clamp(1, 20);
    return ((clamped - 1) ~/ 4) + 2;
  }

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

  static Dnd5eWeaponProfile? weaponProfile(String itemName) {
    final normalized = itemName.toLowerCase();
    for (final entry in _weaponProfiles.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String? spellcastingAbility(String classSummary) {
    final normalized = classSummary.toLowerCase();
    // 2024 战士/游荡者的施法子职业使用智力（奥法骑士 / 诡术师）。
    if (_usesThirdCasterProgression(normalized)) return 'int';
    if (normalized.contains('法师') || normalized.contains('wizard')) {
      return 'int';
    }
    if (normalized.contains('牧师') ||
        normalized.contains('德鲁伊') ||
        normalized.contains('游侠') ||
        normalized.contains('cleric') ||
        normalized.contains('druid') ||
        normalized.contains('ranger')) {
      return 'wis';
    }
    if (normalized.contains('吟游诗人') ||
        normalized.contains('圣武士') ||
        normalized.contains('术士') ||
        normalized.contains('邪术师') ||
        normalized.contains('bard') ||
        normalized.contains('paladin') ||
        normalized.contains('sorcerer') ||
        normalized.contains('warlock')) {
      return 'cha';
    }
    return null;
  }

  static int? spellSaveDc({
    required String classSummary,
    required Map<String, Object?> abilities,
    required int level,
  }) {
    final ability = spellcastingAbility(classSummary);
    if (ability == null) return null;
    return 8 + proficiencyBonus(level) + abilityBonus(abilities, ability);
  }

  /// 邪术师使用契约魔法：单一环阶、数量随等级、短休即恢复。
  static bool usesPactMagic(String classSummary) {
    final normalized = classSummary.toLowerCase();
    return normalized.contains('邪术师') || normalized.contains('warlock');
  }

  /// 契约魔法法术位表（环阶 → 数量）。
  static Map<String, int> pactSlotMaximums(int level) {
    final clamped = level.clamp(1, 20);
    if (clamped >= 17) return const {'5': 4};
    if (clamped >= 11) return const {'5': 3};
    if (clamped >= 9) return const {'5': 2};
    if (clamped >= 7) return const {'4': 2};
    if (clamped >= 5) return const {'3': 2};
    if (clamped >= 3) return const {'2': 2};
    if (clamped >= 2) return const {'1': 2};
    return const {'1': 1};
  }

  /// 休息后仍处于消耗状态的法术位：长休清空；邪术师短休同样清空（契约魔法）。
  static Map<String, int> spellSlotsAfterRest({
    required String classSummary,
    required Map<String, int> used,
    required bool longRest,
  }) {
    if (longRest) return const {};
    if (usesPactMagic(classSummary)) return const {};
    return Map<String, int>.unmodifiable(used);
  }

  static Map<String, int> spellSlotMaximums({
    required String classSummary,
    required int level,
  }) {
    if (usesPactMagic(classSummary)) {
      return pactSlotMaximums(level);
    }
    final casterProgression = _casterProgression(classSummary);
    if (casterProgression == null) return {};
    // 2024：奥法骑士 / 诡术师 3 级才获得法术位。
    if (casterProgression == _CasterProgression.third && level < 3) return {};
    final effectiveLevel = switch (casterProgression) {
      _CasterProgression.full => level,
      _CasterProgression.half => ((level + 1) ~/ 2),
      _CasterProgression.third => ((level + 2) ~/ 3),
    };
    return _fullCasterSlots[effectiveLevel.clamp(1, 20)] ?? {};
  }

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

  static List<Dnd5eClassResource> classResources({
    required String classSummary,
    required int level,
  }) {
    final normalized = classSummary.toLowerCase();
    final clampedLevel = level.clamp(1, 20).toInt();
    if (normalized.contains('战士') || normalized.contains('fighter')) {
      return [
        Dnd5eClassResource(
          id: 'second_wind',
          name: '第二气息',
          maximum: _secondWindUses(clampedLevel),
          // 2024：短休恢复 1 次，长休全部恢复。
          recovery: 'shortRestOne',
        ),
        if (clampedLevel >= 2)
          Dnd5eClassResource(
            id: 'action_surge',
            name: '动作如潮',
            // 2024：17 级起可用两次；短休/长休后全部恢复。
            maximum: clampedLevel >= 17 ? 2 : 1,
            recovery: 'shortRest',
          ),
      ];
    }
    if (normalized.contains('野蛮人') || normalized.contains('barbarian')) {
      return [
        Dnd5eClassResource(
          id: 'rage',
          name: '狂暴',
          maximum: _rageUses(clampedLevel),
          // 2024：短休恢复 1 次，长休全部恢复。
          recovery: 'shortRestOne',
        ),
      ];
    }
    return const [];
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
    return averageHitPointsForHitDie(
      hitDie: hitDie(className),
      level: level,
      constitution: abilityScore(abilities, 'con'),
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

  /// 2024 官方核心表：各职业生命骰面数。
  static int hitDie(String className) {
    final normalized = className.toLowerCase();
    for (final entry in _hitDice.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return 8;
  }

  /// 2024 官方核心表：各职业豁免熟练（无匹配时返回空集，不猜测）。
  static Set<String> classSavingThrows(String classSummary) {
    final normalized = classSummary.toLowerCase();
    for (final entry in _classSavingThrows.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return const <String>{};
  }

  /// 2024 官方逐级"准备法术"上限（不含属性调整值）。
  /// 返回 null 表示该职业不是准备施法者（或为非核心职业）。
  static int? preparedSpellMaximums({
    required String classSummary,
    required int level,
  }) {
    final table = _preparedSpellTable(classSummary);
    if (table == null) return null;
    return table[level.clamp(1, 20) - 1];
  }

  static List<int>? _preparedSpellTable(String classSummary) {
    // 契约魔法先判，避免与术士表混淆。
    if (usesPactMagic(classSummary)) return _preparedWarlock;
    final normalized = classSummary.toLowerCase();
    if (normalized.contains('法师') || normalized.contains('wizard')) {
      return _preparedWizard;
    }
    if (normalized.contains('术士') || normalized.contains('sorcerer')) {
      return _preparedSorcerer;
    }
    if (normalized.contains('牧师') ||
        normalized.contains('cleric') ||
        normalized.contains('德鲁伊') ||
        normalized.contains('druid') ||
        normalized.contains('吟游诗人') ||
        normalized.contains('bard')) {
      return _preparedDivine;
    }
    if (normalized.contains('圣武士') ||
        normalized.contains('paladin') ||
        normalized.contains('游侠') ||
        normalized.contains('ranger')) {
      return _preparedHalfCaster;
    }
    return null;
  }

  static int _secondWindUses(int level) {
    if (level >= 10) return 4;
    if (level >= 4) return 3;
    return 2;
  }

  static int _rageUses(int level) {
    if (level >= 17) return 6;
    if (level >= 12) return 5;
    if (level >= 6) return 4;
    if (level >= 3) return 3;
    return 2;
  }

  /// 2024 核心表：生命骰。邪术师为 d8。
  static const _hitDice = {
    '野蛮人': 12,
    'barbarian': 12,
    '战士': 10,
    'fighter': 10,
    '圣武士': 10,
    'paladin': 10,
    '游侠': 10,
    'ranger': 10,
    '吟游诗人': 8,
    'bard': 8,
    '牧师': 8,
    'cleric': 8,
    '德鲁伊': 8,
    'druid': 8,
    '武僧': 8,
    'monk': 8,
    '游荡者': 8,
    'rogue': 8,
    '邪术师': 8,
    'warlock': 8,
    '术士': 6,
    'sorcerer': 6,
    '法师': 6,
    'wizard': 6,
    // 施法子职业单独出现时也能解析到母职业生命骰。
    '奥法骑士': 10,
    'eldritch knight': 10,
    '诡术师': 8,
    'arcane trickster': 8,
  };

  /// 2024 核心表：豁免熟练。
  static const _classSavingThrows = <String, Set<String>>{
    '野蛮人': {'str', 'con'},
    'barbarian': {'str', 'con'},
    '吟游诗人': {'dex', 'cha'},
    'bard': {'dex', 'cha'},
    '牧师': {'wis', 'cha'},
    'cleric': {'wis', 'cha'},
    '德鲁伊': {'int', 'wis'},
    'druid': {'int', 'wis'},
    '战士': {'str', 'con'},
    'fighter': {'str', 'con'},
    '武僧': {'dex', 'wis'},
    'monk': {'dex', 'wis'},
    '圣武士': {'wis', 'cha'},
    'paladin': {'wis', 'cha'},
    '游侠': {'dex', 'str'},
    'ranger': {'dex', 'str'},
    '游荡者': {'dex', 'int'},
    'rogue': {'dex', 'int'},
    '术士': {'con', 'cha'},
    'sorcerer': {'con', 'cha'},
    '邪术师': {'wis', 'cha'},
    'warlock': {'wis', 'cha'},
    '法师': {'int', 'wis'},
    'wizard': {'int', 'wis'},
  };

  // 2024 官方 "Prepared Spells" 逐级表（1..20 级）。
  static const _preparedDivine = [
    4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22,
  ];
  static const _preparedSorcerer = [
    2, 4, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22,
  ];
  static const _preparedWizard = [
    4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 18, 19, 21, 22, 23, 24, 25,
  ];
  static const _preparedHalfCaster = [
    2, 3, 4, 5, 6, 6, 7, 7, 9, 9, 10, 10, 11, 11, 12, 12, 14, 14, 15, 15,
  ];
  static const _preparedWarlock = [
    2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15,
  ];

  static bool _usesThirdCasterProgression(String normalized) {
    return normalized.contains('奥法骑士') ||
        normalized.contains('eldritch knight') ||
        normalized.contains('诡术师') ||
        normalized.contains('arcane trickster');
  }

  static _CasterProgression? _casterProgression(String classSummary) {
    final normalized = classSummary.toLowerCase();
    // 2024：奥法骑士（战士）/ 诡术师（游荡者）为 1/3 施法者。
    if (_usesThirdCasterProgression(normalized)) {
      return _CasterProgression.third;
    }
    if (normalized.contains('野蛮人') ||
        normalized.contains('战士') ||
        normalized.contains('武僧') ||
        normalized.contains('游荡者') ||
        normalized.contains('barbarian') ||
        normalized.contains('fighter') ||
        normalized.contains('monk') ||
        normalized.contains('rogue')) {
      return null;
    }
    // 邪术师使用契约魔法，走独立进阶，不是全施法者。
    if (usesPactMagic(classSummary)) return null;
    if (normalized.contains('圣武士') ||
        normalized.contains('游侠') ||
        normalized.contains('paladin') ||
        normalized.contains('ranger')) {
      return _CasterProgression.half;
    }
    return spellcastingAbility(classSummary) == null
        ? null
        : _CasterProgression.full;
  }

  static const _fullCasterSlots = {
    1: {'1': 2},
    2: {'1': 3},
    3: {'1': 4, '2': 2},
    4: {'1': 4, '2': 3},
    5: {'1': 4, '2': 3, '3': 2},
    6: {'1': 4, '2': 3, '3': 3},
    7: {'1': 4, '2': 3, '3': 3, '4': 1},
    8: {'1': 4, '2': 3, '3': 3, '4': 2},
    9: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 1},
    10: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2},
    11: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1},
    12: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1},
    13: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1},
    14: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1},
    15: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1, '8': 1},
    16: {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1, '8': 1},
    17: {
      '1': 4,
      '2': 3,
      '3': 3,
      '4': 3,
      '5': 2,
      '6': 1,
      '7': 1,
      '8': 1,
      '9': 1,
    },
    18: {
      '1': 4,
      '2': 3,
      '3': 3,
      '4': 3,
      '5': 3,
      '6': 1,
      '7': 1,
      '8': 1,
      '9': 1,
    },
    19: {
      '1': 4,
      '2': 3,
      '3': 3,
      '4': 3,
      '5': 3,
      '6': 2,
      '7': 1,
      '8': 1,
      '9': 1,
    },
    20: {
      '1': 4,
      '2': 3,
      '3': 3,
      '4': 3,
      '5': 3,
      '6': 2,
      '7': 2,
      '8': 1,
      '9': 1,
    },
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

enum _CasterProgression { full, half, third }

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
