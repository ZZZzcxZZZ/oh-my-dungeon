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
          recovery: 'shortRest',
        ),
        if (clampedLevel >= 2)
          Dnd5eClassResource(
            id: 'action_surge',
            name: '动作如潮',
            // 2024：17 级起可用两次。
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
          recovery: 'longRest',
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

  static int averageHitPoints({
    required String className,
    required int level,
    required Map<String, Object?> abilities,
  }) {
    final hitDie = _hitDie(className);
    final conBonus = abilityBonus(abilities, 'con');
    final clampedLevel = level.clamp(1, 20);
    final laterLevelAverage = (hitDie ~/ 2) + 1;
    // 规则：升级时每级至少获得 1 点生命（负体质调整值不可使收益为 0 或负）。
    final perLevelGain = (laterLevelAverage + conBonus).clamp(1, 1 << 30);
    return hitDie + conBonus + (clampedLevel - 1) * perLevelGain;
  }

  static int _hitDie(String className) {
    final normalized = className.toLowerCase();
    for (final entry in _hitDice.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    if (normalized.contains('barbarian')) return 12;
    if (normalized.contains('fighter') || normalized.contains('paladin')) {
      return 10;
    }
    if (normalized.contains('ranger')) return 10;
    if (normalized.contains('bard') ||
        normalized.contains('cleric') ||
        normalized.contains('druid') ||
        normalized.contains('monk') ||
        normalized.contains('rogue')) {
      return 8;
    }
    if (normalized.contains('wizard') ||
        normalized.contains('sorcerer') ||
        normalized.contains('warlock')) {
      return 6;
    }
    return 8;
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

  static const _hitDice = {
    '野蛮人': 12,
    '战士': 10,
    '圣武士': 10,
    '游侠': 10,
    '吟游诗人': 8,
    '牧师': 8,
    '德鲁伊': 8,
    '武僧': 8,
    '游荡者': 8,
    '法师': 6,
    '术士': 6,
    '邪术师': 6,
  };

  static _CasterProgression? _casterProgression(String classSummary) {
    final normalized = classSummary.toLowerCase();
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
