import 'equipment_bundle_items.dart';
import '../../content/domain/content_entry.dart';
import '../../rules/domain/rule_override_conflict.dart';
import '../../rules/domain/rule_override_declaration.dart';
import '../../rules/domain/rule_profile.dart';
import 'background_grants.dart';
import 'character_edit_draft.dart';
import 'declared_levels.dart';
import 'dnd5e_rules.dart';
import 'rule_override_index.dart';

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
    this.classEntry,
    this.classEntryId,
    this.speciesEntryId,
    this.backgroundEntryId,
    this.ruleChoices = const <String, List<String>>{},
    this.avatarUrl,
    this.appearance = '',
    this.personalityTraits = '',
    this.ideals = '',
    this.bonds = '',
    this.flaws = '',
    this.backstory = '',
    this.privateNotes = '',
    this.customSpells = const <Map<String, Object?>>[],
    this.entries = const <String, ContentEntry>{},
    this.packagePriorities = const <String, int>{},
    this.disabledOriginIds = const <String>{},
    this.pinnedOrigins = const <String, String>{},
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

  /// 职业条目（有内容资料库时传进来）。
  ///
  /// 规则数值与声明范围必须与创建向导**同源**：带上它就等于带上
  /// `structured.classRules` 与 `progression[].levels`（[DeclaredLevels.fromEntry]），
  /// 否则只剩展示名 → 档案 slug 一条路，会出现"向导显示 1–5 级、落库 max=null"
  /// 这种同一角色两处数字不同的缺陷。
  final ContentEntry? classEntry;

  final String? classEntryId;
  final String? speciesEntryId;
  final String? backgroundEntryId;
  final Map<String, List<String>> ruleChoices;
  final String appearance;
  final String personalityTraits;
  final String ideals;
  final String bonds;
  final String flaws;
  final String backstory;
  final String privateNotes;
  final List<Map<String, Object?>> customSpells;

  /// 全部候选条目（键 = 条目 id）：跨包职业规则声明索引要用它建
  /// （`RuleOverrideIndex.fromEntries`），否则勘误包声明的列在这条路径上看不见。
  ///
  /// 与 [packagePriorities] / [disabledOriginIds] / [pinnedOrigins] 一起保证
  /// "向导显示的数值"与"落库的数值"来自**同一份**规则解析：这条路径
  /// （`hasStructuredRules == false`：条目只有 `structured.classRules`、没有 `rules` 块）
  /// 曾经不带 priority / 索引，同 slug 两包时会出现"向导显示 d8、落库 d12"。
  final Map<String, ContentEntry> entries;
  final Map<String, int> packagePriorities;
  final Set<String> disabledOriginIds;
  final Map<String, String> pinnedOrigins;

  Map<String, Object?> get storyData => {
    'appearance': appearance.trim(),
    'personalityTraits': personalityTraits.trim(),
    'ideals': ideals.trim(),
    'bonds': bonds.trim(),
    'flaws': flaws.trim(),
    'backstory': backstory.trim(),
    'privateNotes': privateNotes.trim(),
  };

  Map<String, Object?> get manualOverridesData => {
    'features': {
      'addedEntryIds': <String>[],
      'hiddenGrantKeys': <String>[],
      'custom': <Map<String, Object?>>[],
    },
    'spells': {
      'addedEntryIds': <String>[],
      'removedEntryIds': <String>[],
      'preparedEntryIds': <String>[],
      'custom': customSpells,
    },
    'actions': {'custom': <Map<String, Object?>>[]},
  };

  /// 角色头像（data URL 或本地文件路径）。规范 §头像来源：本地角色头像
  /// 离线保存在客户端，绑定战役后自动上传。
  final String? avatarUrl;
}

class QuickBuildService {
  const QuickBuildService._();

  static CharacterEditDraft build(QuickBuildSelection selection) {
    // 职业身份只有一个来源：有条目就用条目 id，否则用调用方给的 id。
    final classEntryId = selection.classEntry?.id ?? selection.classEntryId;
    final classRules = _classRules(
      entry: selection.classEntry,
      entryId: selection.classEntryId,
      classSummary: selection.className,
      entries: selection.entries,
      packagePriorities: selection.packagePriorities,
      disabledOriginIds: selection.disabledOriginIds,
      pinnedOrigins: selection.pinnedOrigins,
    );
    final abilities =
        selection.abilities ??
        abilityPresetFor(
          classEntryId: classEntryId,
          className: selection.className,
        );
    final maxHp = _averageHitPoints(
      hitDie: classRules.hitDie,
      level: selection.level,
      abilities: abilities,
    );
    final classResources = Dnd5eRules.classResourcesFromRules(
      rules: classRules,
      level: selection.level,
      abilities: abilities,
    );
    final saves = {for (final key in Dnd5eRules.abilityLabels.keys) key: false};
    for (final ability in classRules.savingThrowAbilities) {
      if (saves.containsKey(ability)) saves[ability] = true;
    }
    final slug = Dnd5eRules.resolveClassSlug(
      entryId: classEntryId,
      classSummary: selection.className,
    );
    // §3.12：声明范围与 Builder / 向导同源。有职业条目就整体走
    // [DeclaredLevels.fromEntry]（条目 `progression[].levels` ∪ 条目各表 ∪ 档案）；
    // 只有展示名时没有 progression 可并，但仍是同一个口径函数，来源是档案侧。
    final declaredLevels = selection.classEntry != null
        ? DeclaredLevels.fromEntry(selection.classEntry)
        : DeclaredLevels.fromResolvedClassRules(classRules);

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
      abilities: Map<String, int>.from(abilities),
      saves: saves,
      skills: _skills(selection),
      inventory: [
        ..._inventory(slug),
        for (final item in selection.itemRefs)
          if (item.trim().isNotEmpty) {'name': item.trim(), 'quantity': 1},
      ],
      // 币种键的唯一实现点是 `EquipmentBundleItems.currencyKeys`；初始货币只有
      // 这里的 gp 10（快速创建的历史行为）。
      currency: {
        for (final key in EquipmentBundleItems.currencyKeys)
          key: key == 'gp' ? 10 : 0,
      },
      notes:
          'D&D 2024 快速创建：${selection.species} / ${selection.background} / ${selection.className}。',
      avatarUrl: selection.avatarUrl,
      data: {
        'story': selection.storyData,
        if (selection.customSpells.isNotEmpty)
          'manualOverrides': selection.manualOverridesData,
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
        // 职业身份以条目为准；只有展示名时记下解析出的 slug，规则数值仍来自档案。
        'classIdentity': {
          'entryId': classEntryId,
          if (slug.isNotEmpty) 'slug': slug,
          'name': selection.className,
          // 展示名解析不到档案 slug 即"未声明"。
          'declared': slug.isNotEmpty,
          'declaredLevels': declaredLevels.toData(),
        },
        'hitDie': classRules.hitDie,
        'savingThrowAbilities': classRules.savingThrowAbilities.toList(),
        // 列级来源与冲突：本路径现在与 `RulesDrivenCharacterBuilder` 用**同一套**
        // 输入（entries + priority + 覆盖）解析，因此也必须写下同一份来源快照，
        // 否则快速创建出来的角色在再次派生之前，角色页每一列都显示"来源未知"，
        // 用户无法判断某个数值来自内置档案还是某个勘误包。
        'classRuleSources': RuleFieldSourceMap.toData(classRules.fieldSources),
        'classRuleConflicts': RuleOverrideConflicts.toData(classRules.conflicts),
        // 派生快照与 `RulesDrivenCharacterBuilder` **同一口径**：无条件写入
        // （空表 / 空列表 / null 也写），消费方按键是否存在判断"是否已派生"。
        'spellSlots': classRules.spellSlots(selection.level),
        'spellcastingAbility': classRules.spellcastingAbility,
        'preparedSpellLimit': classRules.preparedLimit(selection.level),
        'classResources': [
          for (final resource in classResources)
            {
              'id': resource.id,
              'name': resource.name,
              'maximum': resource.maximum,
              'recovery': resource.recovery,
            },
        ],
        // `runtime.classResourcesUsed` 是**运行期状态**（不是派生快照）：只在确实
        // 有资源时初始化，不写空表。
        if (classResources.isNotEmpty)
          'runtime': {
            'classResourcesUsed': {
              for (final resource in classResources) resource.id: 0,
            },
          },
      },
    );
  }

  /// 展示名 / 条目 id → 档案规则（唯一入口，UI 不再按职业名分支）。
  ///
  /// 有条目时把 `structured.classRules` 一并带上：快速创建与创建向导读到的
  /// 数值因此完全一致（列级合并的唯一实现在 [Dnd5eRules.resolveClassRules]）。
  ///
  /// **必须带上 `entries` / `packagePriorities` / 覆盖输入**：本方法服务的是
  /// `hasStructuredRules == false`（条目只有 `structured.classRules`、没有 `rules` 块）
  /// 的路径，而"哪一份声明赢"由包 priority 与跨包索引决定。不带它们时同 slug 两个包
  /// 会给出不同数值（向导预览 d8、落库 d12，反之亦然），与 `RulesDrivenCharacterBuilder`
  /// 分叉——那条路径的输入是同一套（决策 D2/D3）。
  static ResolvedClassRules _classRules({
    required ContentEntry? entry,
    required String? entryId,
    required String classSummary,
    required Map<String, ContentEntry> entries,
    required Map<String, int> packagePriorities,
    required Set<String> disabledOriginIds,
    required Map<String, String> pinnedOrigins,
  }) {
    final resolvedEntryId = entry?.id ?? entryId;
    return Dnd5eRules.resolveClassRules(
      entryId: resolvedEntryId,
      classSummary: entry?.name ?? classSummary,
      structured: entry?.structured ?? const <String, Object?>{},
      overrides: entries.isEmpty
          ? null
          : RuleOverrideIndex.fromEntries(
              entries.values,
              packagePriorities,
            ),
      entryPriority:
          packagePriorities[RuleOverrideDeclaration.packageIdOf(
            resolvedEntryId ?? '',
          )] ??
          0,
      disabledOriginIds: disabledOriginIds,
      pinnedOrigins: pinnedOrigins,
    );
  }

  /// 未声明生命骰（自制职业）时只按体质调整值计，且总生命至少 1（§3.6 第 3 步）。
  static int _averageHitPoints({
    required int? hitDie,
    required int level,
    required Map<String, Object?> abilities,
  }) {
    final safeLevel = level.clamp(1, 20);
    final constitution = Dnd5eRules.abilityScore(abilities, 'con');
    if (hitDie == null) {
      return (Dnd5eRules.abilityModifier(constitution) * safeLevel).clamp(
        1,
        1 << 30,
      );
    }
    return Dnd5eRules.averageHitPointsForHitDie(
      hitDie: hitDie,
      level: safeLevel,
      constitution: constitution,
    );
  }

  /// 快速创建的属性预设：**按档案 slug 取键**，不再写死中文职业名。
  ///
  /// 键就是内置档案 `classes` 的 slug（`wizard` / `rogue` / `cleric` / …），
  /// 因此 `法师`、`法师 / Wizard`、`Wizard` 三种写法都命中同一份预设；
  /// 未识别的职业（含自制职业）回退到力量型默认值。
  ///
  /// 编辑器与快速创建共用这一个入口，保证两处的"推荐属性"一致。
  static Map<String, int> abilityPresetFor({
    String? classEntryId,
    required String className,
  }) {
    final slug = Dnd5eRules.resolveClassSlug(
      entryId: classEntryId,
      classSummary: className,
    );
    final preset = _classAbilityPresets[slug];
    if (preset == null) return Map<String, int>.from(_defaultAbilities);
    return Map<String, int>.from(preset);
  }

  static const _defaultAbilities = <String, int>{
    'str': 16,
    'dex': 14,
    'con': 14,
    'int': 10,
    'wis': 12,
    'cha': 8,
  };

  /// 编辑器"标准数组"步骤的推荐属性（购点友好：总和正好 27 点）。
  ///
  /// 与 [abilityPresetFor] 分开是因为两者约束不同：快速创建直接给 16 的主属性，
  /// 而编辑器的下一步是 27 点购点，必须给出一组**恰好用满预算**的可编辑初值。
  /// 键同样是档案 slug，不写死职业名。
  static Map<String, int> editorAbilityPresetFor({
    String? classEntryId,
    required String className,
  }) {
    final slug = Dnd5eRules.resolveClassSlug(
      entryId: classEntryId,
      classSummary: className,
    );
    final preset = _editorAbilityPresets[slug];
    if (preset == null) return Map<String, int>.from(_editorDefaultAbilities);
    return Map<String, int>.from(preset);
  }

  static const _editorDefaultAbilities = <String, int>{
    'str': 15,
    'dex': 14,
    'con': 13,
    'int': 10,
    'wis': 12,
    'cha': 8,
  };

  static const _editorAbilityPresets = <String, Map<String, int>>{
    'wizard': {'str': 8, 'dex': 13, 'con': 14, 'int': 15, 'wis': 12, 'cha': 10},
    'rogue': {'str': 8, 'dex': 15, 'con': 14, 'int': 12, 'wis': 10, 'cha': 13},
    'cleric': {'str': 10, 'dex': 12, 'con': 14, 'int': 8, 'wis': 15, 'cha': 13},
  };

  static const _classAbilityPresets = <String, Map<String, int>>{
    'wizard': {'str': 8, 'dex': 14, 'con': 14, 'int': 16, 'wis': 12, 'cha': 10},
    'rogue': {'str': 8, 'dex': 16, 'con': 14, 'int': 12, 'wis': 10, 'cha': 14},
    'cleric': {'str': 10, 'dex': 12, 'con': 14, 'int': 8, 'wis': 16, 'cha': 14},
    'bard': {'str': 8, 'dex': 14, 'con': 14, 'int': 10, 'wis': 10, 'cha': 16},
    'druid': {'str': 10, 'dex': 14, 'con': 14, 'int': 10, 'wis': 16, 'cha': 8},
    'monk': {'str': 10, 'dex': 16, 'con': 14, 'int': 8, 'wis': 16, 'cha': 8},
    'paladin': {
      'str': 16,
      'dex': 8,
      'con': 14,
      'int': 10,
      'wis': 10,
      'cha': 16,
    },
    'ranger': {'str': 12, 'dex': 16, 'con': 14, 'int': 10, 'wis': 14, 'cha': 8},
    'sorcerer': {
      'str': 8,
      'dex': 14,
      'con': 14,
      'int': 10,
      'wis': 10,
      'cha': 16,
    },
    'warlock': {
      'str': 8,
      'dex': 14,
      'con': 14,
      'int': 10,
      'wis': 10,
      'cha': 16,
    },
  };

  static Map<String, bool> _skills(
    QuickBuildSelection selection,
  ) {
    final skills = {for (final skill in Dnd5eRules.skills) skill.name: false};
    final explicit = selection.skillProficiencies;
    // 显式传入的优先（创建向导把技能选择与背景授予合并后传进来）；
    // 没传时按**背景条目自己的 rules** 取（决策 D10，唯一读取口径），
    // 不再按背景中文名硬编码、也不再给未知背景发一套士兵技能。
    final names = explicit ??
        backgroundSkillProficiencies(
          entries: selection.entries.values,
          backgroundEntryId: selection.backgroundEntryId,
        ).toList();
    for (final skillName in names) {
      final trimmed = skillName.trim();
      if (skills.containsKey(trimmed)) {
        skills[trimmed] = true;
      }
    }
    return skills;
  }

  /// 无内容资料库时的开局物品预设，同样**按 slug 取键**（不是按职业名子串）。
  static List<Map<String, Object>> _inventory(String slug) {
    return switch (slug) {
      'wizard' => [
        {'name': '法术书', 'quantity': 1},
        {'name': '匕首', 'quantity': 1},
      ],
      'rogue' => [
        {'name': '短剑', 'quantity': 1},
        {'name': '盗贼工具', 'quantity': 1},
      ],
      'cleric' => [
        {'name': '圣徽', 'quantity': 1},
        {'name': '治疗药水', 'quantity': 1},
      ],
      _ => [
        {'name': '长剑', 'quantity': 1},
        {'name': '盾牌', 'quantity': 1},
      ],
    };
  }
}
