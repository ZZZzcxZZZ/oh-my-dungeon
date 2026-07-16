import 'character_edit_draft.dart';
import 'dnd5e_rules.dart';

class QuickBuildSelection {
  const QuickBuildSelection({
    required this.name,
    required this.className,
    required this.species,
    required this.background,
    required this.level,
    this.spellRefs = const [],
    this.itemRefs = const [],
    this.abilities,
    this.skillProficiencies,
    this.classEntryId,
    this.speciesEntryId,
    this.backgroundEntryId,
    this.ruleChoices = const <String, List<String>>{},
  });

  final String name;
  final String className;
  final String species;
  final String background;
  final int level;
  final List<String> spellRefs;
  final List<String> itemRefs;
  final Map<String, int>? abilities;
  final List<String>? skillProficiencies;
  final String? classEntryId;
  final String? speciesEntryId;
  final String? backgroundEntryId;
  final Map<String, List<String>> ruleChoices;
}

class QuickBuildService {
  const QuickBuildService._();

  static CharacterEditDraft build(QuickBuildSelection selection) {
    final abilities = selection.abilities ?? _abilities(selection.className);
    final maxHp = Dnd5eRules.averageHitPoints(
      className: selection.className,
      level: selection.level,
      abilities: abilities,
    );
    final classResources = Dnd5eRules.classResources(
      classSummary: selection.className,
      level: selection.level,
    );

    return CharacterEditDraft(
      name: selection.name.trim(),
      level: selection.level,
      classSummary: selection.className,
      raceSummary: selection.species,
      currentHp: maxHp,
      maxHp: maxHp,
      armorClass: Dnd5eRules.baseArmorClass(abilities),
      speed: 30,
      initiativeBonus: Dnd5eRules.initiativeBonus(abilities),
      abilities: abilities.map((key, value) => MapEntry(key, value as int)),
      saves: _saves(selection.className),
      skills: _skills(
        selection.background,
        skillProficiencies: selection.skillProficiencies,
      ),
      inventory: [
        ..._inventory(selection.className),
        for (final item in selection.itemRefs)
          if (item.trim().isNotEmpty) {'name': item.trim(), 'quantity': 1},
      ],
      currency: const {'cp': 0, 'sp': 0, 'ep': 0, 'gp': 10, 'pp': 0},
      notes:
          'D&D 2024 快速创建：${selection.species} / ${selection.background} / ${selection.className}。',
      data: {
        'contentRefs': {
          'spells': [
            for (final spell in selection.spellRefs)
              if (spell.trim().isNotEmpty) spell.trim(),
          ],
          'items': [
            for (final item in selection.itemRefs)
              if (item.trim().isNotEmpty) item.trim(),
          ],
          'features': <String>[],
        },
        if (classResources.isNotEmpty) ...{
          'classResources': [
            for (final resource in classResources)
              {
                'id': resource.id,
                'name': resource.name,
                'maximum': resource.maximum,
              },
          ],
          'runtime': {
            'classResourcesUsed': {
              for (final resource in classResources) resource.id: 0,
            },
          },
        },
      },
    );
  }

  static Map<String, Object?> _abilities(String className) {
    final normalized = className.toLowerCase();
    if (normalized.contains('法师') || normalized.contains('wizard')) {
      return {'str': 8, 'dex': 14, 'con': 14, 'int': 16, 'wis': 12, 'cha': 10};
    }
    if (normalized.contains('游荡者') || normalized.contains('rogue')) {
      return {'str': 8, 'dex': 16, 'con': 14, 'int': 12, 'wis': 10, 'cha': 14};
    }
    if (normalized.contains('牧师') || normalized.contains('cleric')) {
      return {'str': 10, 'dex': 12, 'con': 14, 'int': 8, 'wis': 16, 'cha': 14};
    }
    return {'str': 16, 'dex': 14, 'con': 14, 'int': 10, 'wis': 12, 'cha': 8};
  }

  static Map<String, bool> _saves(String className) {
    final saves = {for (final key in Dnd5eRules.abilityLabels.keys) key: false};
    final normalized = className.toLowerCase();
    if (normalized.contains('法师') || normalized.contains('wizard')) {
      saves['int'] = true;
      saves['wis'] = true;
    } else if (normalized.contains('游荡者') || normalized.contains('rogue')) {
      saves['dex'] = true;
      saves['int'] = true;
    } else if (normalized.contains('牧师') || normalized.contains('cleric')) {
      saves['wis'] = true;
      saves['cha'] = true;
    } else {
      saves['str'] = true;
      saves['con'] = true;
    }
    return saves;
  }

  static Map<String, bool> _skills(
    String background, {
    List<String>? skillProficiencies,
  }) {
    final skills = {for (final skill in Dnd5eRules.skills) skill.name: false};
    if (skillProficiencies != null) {
      for (final skillName in skillProficiencies) {
        final trimmed = skillName.trim();
        if (skills.containsKey(trimmed)) {
          skills[trimmed] = true;
        }
      }
      return skills;
    }

    final normalized = background.toLowerCase();
    if (normalized.contains('贤者') || normalized.contains('sage')) {
      skills['奥秘'] = true;
      skills['历史'] = true;
    } else if (normalized.contains('罪犯') || normalized.contains('criminal')) {
      skills['欺瞒'] = true;
      skills['隐匿'] = true;
    } else if (normalized.contains('侍祭') ||
        normalized.contains('侍僧') ||
        normalized.contains('acolyte')) {
      skills['洞悉'] = true;
      skills['宗教'] = true;
    } else {
      skills['运动'] = true;
      skills['威吓'] = true;
    }
    return skills;
  }

  static List<Map<String, Object>> _inventory(String className) {
    final normalized = className.toLowerCase();
    if (normalized.contains('法师') || normalized.contains('wizard')) {
      return [
        {'name': '法术书', 'quantity': 1},
        {'name': '匕首', 'quantity': 1},
      ];
    }
    if (normalized.contains('游荡者') || normalized.contains('rogue')) {
      return [
        {'name': '短剑', 'quantity': 1},
        {'name': '盗贼工具', 'quantity': 1},
      ];
    }
    if (normalized.contains('牧师') || normalized.contains('cleric')) {
      return [
        {'name': '圣徽', 'quantity': 1},
        {'name': '治疗药水', 'quantity': 1},
      ];
    }
    return [
      {'name': '长剑', 'quantity': 1},
      {'name': '盾牌', 'quantity': 1},
    ];
  }
}
