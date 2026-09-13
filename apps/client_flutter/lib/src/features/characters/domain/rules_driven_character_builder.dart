import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_build.dart';
import '../../rules/domain/character_rule_definition.dart';
import '../../rules/domain/character_rules_engine.dart';
import '../../rules/domain/rule_choice_quota.dart';
import '../../rules/domain/rule_choice_semantics.dart';
import '../../rules/domain/rule_math.dart' as rule_math;
import '../../rules/domain/rule_override_conflict.dart';
import '../../rules/domain/rule_override_declaration.dart';
import '../../rules/domain/rule_profile.dart';
import '../../rules/domain/rule_values.dart';
import 'character_content_reference.dart';
import 'character_edit_draft.dart';
import 'declared_levels.dart';
import 'dnd5e_rules.dart';
import 'equipment_bundle_items.dart';
import 'rule_override_index.dart';
import 'structured_class_rules.dart';

/// 角色表默认步行速度（尺）：`speed` grant 的加值累加到它之上（契约 §3.5）。
const int kBaseWalkingSpeed = 30;

class RulesDrivenCharacterBuilder {
  RulesDrivenCharacterBuilder({
    required this.entries,
    Map<String, int> packagePriorities = const <String, int>{},
    this.disabledOriginIds = const <String>{},
    this.pinnedOrigins = const <String, String>{},
  }) : _packagePriorities = packagePriorities,
       _overrides = RuleOverrideIndex.fromEntries(
         entries.values,
         packagePriorities,
       ),
       _engine = CharacterRulesEngine(entries: entries);

  final Map<String, ContentEntry> entries;

  /// 包 id → priority（决策 D2）：既用来给索引里的声明定 tier，也用来给角色
  /// **自己那条**条目定 `entryPriority`（否则它恒为 tier 100，会被低 priority 的
  /// 勘误压过）。
  final Map<String, int> _packagePriorities;

  /// 跨包职业规则声明索引（决策 D3）。
  final RuleOverrideIndex _overrides;

  /// 用户显式关掉的覆盖来源 / 为某列显式选定的来源（决策 D6）。构造时从角色读一次，
  /// `build` 与 [baseAbilitiesFrom] 共用同一份——两处各读一次会让"属性加值的逆运算"
  /// 与派生账看到不同的规则。
  final Set<String> disabledOriginIds;
  final Map<String, String> pinnedOrigins;

  final CharacterRulesEngine _engine;

  CharacterEditDraft build({
    required String name,
    required CharacterBuild build,
    required Map<String, int> abilities,
    String notes = '',
    String? avatarUrl,
    List<String> extraSpellRefs = const <String>[],
    List<String> extraItemRefs = const <String>[],
    List<String> skillProficiencies = const <String>[],
    /// 只有**展示名**、资料库里没有对应条目时的兜底（向导允许先选名字）。
    /// 条目存在时一律以条目为准（§3.6：条目身份优先）；条目不存在且没有兜底才留空。
    /// 背景条目也可能带 `rules`（决策 D10 的熟练授予），因此"有任意条目带 rules 就走
    /// 本构建器"的门禁在只有背景条目时同样成立——那时职业展示名只能来自这里。
    String? classSummaryFallback,
    String? raceSummaryFallback,
  }) {
    final classEntry = _selectedEntry(build, 'class');
    final speciesEntry = _selectedEntry(build, 'species');
    final backgroundEntry = _selectedEntry(build, 'background');
    // 职业数值的唯一入口：条目身份优先，`structured.classRules` 覆盖档案（§3.6、§3.7）。
    // 与 [baseAbilitiesFrom] 共用 [_classRulesFor]，避免两处各写一份三参数调用。
    final classRules = _classRulesFor(
      build,
      classSummaryFallback: classSummaryFallback,
    );
    final gateBuild = _gateBuildFor(build, abilities);
    final ledger = _engine.evaluate(
      gateBuild,
      poolLimits: RuleChoiceQuota.limitsFor(
        rules: classRules,
        level: build.level,
      ),
    );
    // `abilities` 是**入参基础属性**（决策 D4），原样持久化：结算后的
    // [effectiveAbilities] 绝不回写，否则下次再派生会把 `kind: ability` 加值
    // 当成基础值再叠加一遍（缺陷 4）。
    final effectiveBuild = CharacterBuild(
      level: build.level,
      selections: build.selections,
      choices: ledger.resolvedChoices,
      abilities: build.abilities,
    );
    // 属性加值（`kind: ability`）必须在**任何派生之前**叠加：HP / AC / 豁免 /
    // 技能 / 法术 DC 全部读 [effectiveAbilities]，不再读入参 [abilities]。
    // `kind: ability` **只接受 `value`**（导入期拒绝 `formula`，见契约 §3.5），
    // 因此叠加只依赖 [abilities] 本身，`baseAbilitiesFrom` 的逆运算精确。
    // `kind: hitPoints` / `classResources` 的 `formula` 则拿**叠加后**的
    // [effectiveAbilities] 求值（下面 `_hitPointGrantBonus` 与
    // `classResourcesFromRules` 传入的正是这份值）。
    // 属性键集合与 [Dnd5eRules.profile] 的 `abilities` **同源**（§3.1）：
    // 导入期按档案 `abilities` 放行 `kind: ability` 的 `target`，运行期必须用
    // 同一份集合，否则"导入放行、运行期静默丢弃"就会悄悄发生。
    final effectiveAbilities = <String, int>{...abilities};
    _abilityGrantBonuses(ledger).forEach((key, value) {
      effectiveAbilities[key] = (effectiveAbilities[key] ?? 10) + value;
    });
    final saves = {for (final key in Dnd5eRules.profile.abilities) key: false};
    final skills = {for (final skill in Dnd5eRules.skills) skill.name: false};

    for (final grant in ledger.grantsOfKind(RuleGrantKind.proficiency)) {
      final target = grant.target;
      if (target == null) continue;
      if (target.startsWith('save:')) {
        final key = target.substring('save:'.length);
        if (saves.containsKey(key)) saves[key] = true;
      } else if (target.startsWith('skill:')) {
        final key = target.substring('skill:'.length);
        if (skills.containsKey(key)) skills[key] = true;
      }
    }

    for (final ability in classRules.savingThrowAbilities) {
      if (saves.containsKey(ability)) saves[ability] = true;
    }
    for (final skill in skillProficiencies) {
      if (skills.containsKey(skill)) skills[skill] = true;
    }
    final featureRefs = {
      ..._entryRefs(ledger, RuleGrantKind.feature),
      ..._choiceEntryRefs(ledger, const {'classFeature', 'feature', 'feat'}),
    }.toList(growable: false);
    final spellRefs = {
      ..._entryRefs(ledger, RuleGrantKind.spell),
      ..._choiceEntryRefs(ledger, const {'spell'}),
      ...extraSpellRefs.where(entries.containsKey),
    }.toList(growable: false);
    final itemRefs = {
      ..._entryRefs(ledger, RuleGrantKind.equipment),
      ..._choiceEntryRefs(ledger, const {'equipment', 'item'}),
      ...extraItemRefs.where(entries.containsKey),
    }.toList(growable: false);
    // 法术位与职业资源一律来自新契约的职业规则（条目声明 ∪ 档案）：
    // `resource` / `spellSlot:` 授予已在任务 9 移除，数值只由 classRules 提供。
    final spellSlots = classRules.spellSlots(build.level);
    final classResources = Dnd5eRules.classResourcesFromRules(
      rules: classRules,
      level: build.level,
      abilities: effectiveAbilities,
    );
    final actions = _actionRows(ledger);
    final armorBonus = ledger
        .grantsOfKind(RuleGrantKind.armorClass)
        .fold<num>(0, (sum, grant) => sum + (grant.value ?? 0))
        .toInt();
    // `speed` 与 `armorClass` 同一口径：**加值**，累加到角色表的基础速度上
    // （§3.5）。绝对值会把角色表里用户可编辑的速度静默覆盖掉——样例包写
    // "速度 +10 尺" 时，旧实现会把速度变成 10 而不是 40。
    final speedBonus = ledger
        .grantsOfKind(RuleGrantKind.speed)
        .fold<num>(0, (sum, grant) => sum + (grant.value ?? 0))
        .toInt();
    final maxHp = _averageHitPoints(
      hitDie: classRules.hitDie,
      level: build.level,
      constitution: effectiveAbilities['con'] ?? 10,
      bonus: _hitPointGrantBonus(ledger, level: build.level, abilities: effectiveAbilities),
    );
    final contentReferences = _contentReferences(
      effectiveBuild,
      ledger,
      extraEntryIds: {...extraSpellRefs, ...extraItemRefs},
    );
    // **全部**规则选择的落库镜像：与 `build.choices` 同形（键 = 生效单元键），
    // 含条目选择与记录型值类型选择；**不做数值派生**。
    //
    // 读取方：`recordedRuleChoices`（`characters/domain/recorded_rule_choices.dart`）
    // 把它渲染成角色卡的「规则选择」卡——这样**记录型选择**（值选项、不产生 grant
    // 的风格选择）在角色卡上可见；数值派生仍只由本构建器负责，两件事不混。
    final recordedChoices = <String, List<String>>{
      for (final entry in ledger.resolvedChoices.entries) entry.key: entry.value,
    };
    // 语言落到**既有存储** `data['profile']['languages']`（决策 D6）：
    // `CharacterProfile.fromCharacter` 读的就是它，`data['languages']` 没有读取方。
    // 再派生只**嵌套合并**这一个键（`CharacterProfile.mergeLanguages`），不得整份
    // 覆盖 `profile`——那会删掉同 map 的 appearance / backstory。
    final languagePicks = _languagePicks(ledger);
    // 装备方案 A/B（`optionType: "equipmentBundle"` 的选中值）：物品与货币的解析
    // 只有 `EquipmentBundleItems.from` 一处，`inventory` / `currency` 都读它。
    final equipmentBundles = _equipmentBundles(ledger);
    // 显式法术选择的镜像（契约 §3.11 A3）：选中的法术**全部**进
    // `alwaysPreparedEntryIds`（选择派生的"自动准备"）；`preparedEntryIds` 是
    // **用户手动准备**的专属存储，派生一律不写（否则再派生会覆盖用户操作）。
    // 判定与去重只有 `_spellChoicePreparedPicks` 一处。
    final spellPicks = _spellChoicePreparedPicks(ledger);

    return CharacterEditDraft(
      name: name.trim(),
      level: build.level,
      classSummary: classEntry?.name ?? classSummaryFallback ?? '',
      raceSummary: speciesEntry?.name ?? raceSummaryFallback ?? '',
      currentHp: maxHp,
      maxHp: maxHp,
      armorClass: Dnd5eRules.baseArmorClass(effectiveAbilities) + armorBonus,
      speed: kBaseWalkingSpeed + speedBonus,
      initiativeBonus: Dnd5eRules.initiativeBonus(effectiveAbilities),
      abilities: Map<String, int>.from(effectiveAbilities),
      saves: saves,
      skills: skills,
      inventory: _inventoryRows(itemRefs, equipmentBundles),
      currency: _currencyTotals(equipmentBundles),
      notes: notes.isEmpty
          ? 'D&D 2024 引导创建：${backgroundEntry?.name ?? ''} / ${speciesEntry?.name ?? ''} / ${classEntry?.name ?? ''}。'
          : notes,
      avatarUrl: avatarUrl,
      contentReferences: contentReferences,
      data: {
        'build': effectiveBuild.toJson(),
        'choices': recordedChoices,
        if (languagePicks.isNotEmpty) 'profile': {'languages': languagePicks},
        // **无条件**写法术镜像（P2-11）：只在非空时写会让"取消全部法术选择后再
        // 派生"永远清不掉旧镜像。镜像只有 `alwaysPreparedEntryIds` 一份
        // （`preparedEntryIds` 属用户手动存储，派生不碰）。
        'manualOverrides': {
          'spells': {'alwaysPreparedEntryIds': spellPicks},
        },
        'contentRefs': {
          'features': featureRefs,
          'spells': spellRefs,
          'items': itemRefs,
        },
        'ruleSnapshots': {
          for (final reference in contentReferences)
            reference.entryKey: reference.snapshot,
        },
        'resolvedGrants': [
          for (final grant in ledger.grants)
            {
              'id': grant.id,
              'kind': grant.kind.name,
              'label': grant.label,
              'sourceEntryId': grant.sourceEntryId,
              'sourceEntryName': grant.sourceEntryName,
              if (grant.sourceLevel != null) 'sourceLevel': grant.sourceLevel,
              if (grant.entryId != null) 'entryId': grant.entryId,
              if (grant.target != null) 'target': grant.target,
              if (grant.value != null) 'value': grant.value,
              if (grant.data.isNotEmpty) 'data': grant.data,
            },
        ],
        'pendingChoices': [
          for (final choice in ledger.pendingChoices)
            {
              'key': choice.key,
              'label': choice.label,
              'minimum': choice.minimum,
              'maximum': choice.maximum,
              'selected': choice.selected,
              // "为什么没生效"的唯一枚举（`RuleChoicePendingReason`）。落库时
              // **不丢原因**：重新载入的角色卡也必须能说明"已选但未生效"的原因，
              // 否则 `reason == null` 与"某个具体原因"无法区分。
              'reason': choice.reason?.name,
            },
        ],
        'classIdentity': {
          'entryId': classEntry?.id,
          // 身份口径与运行期**同源**：条目 id 末段（[Dnd5eRules.resolveClassSlug]，
          // 与 `resolveClassRules` / 导入器保护键 / `QuickBuildService` 同一入口），
          // **不是**条目的展示字段 `slug`——后者允许为空串，会让
          // `CharacterSheet.classResources` 误判"没有职业身份"而提前返回空。
          'slug': Dnd5eRules.resolveClassSlug(
            entryId: classEntry?.id,
            classSummary: classEntry?.name ?? '',
          ),
          'name': classEntry?.name,
          // 没有职业条目即"未声明"：界面显示"未声明"而不是 0。
          'declared': classEntry != null,
          // §3.12：部分声明是一等功能，声明范围随角色持久化，供所有界面共用。
          // 唯一口径来自 [DeclaredLevels.fromEntry]（条目 progression ∪ 条目各表
          // ∪ 内置档案同 slug 职业），与创建向导读的是同一个函数。
          'declaredLevels': DeclaredLevels.fromEntry(classEntry).toData(),
        },
        'hitDie': classRules.hitDie,
        'savingThrowAbilities': classRules.savingThrowAbilities.toList(),
        // S3 决策 D6：列级来源与"同 tier 多来源抢同一列"的冲突随角色持久化。
        // 形状归一化 / 排序各只有一处（RuleFieldSourceMap / RuleOverrideConflicts），
        // 页面与再派生都读这两个键。
        'classRuleSources': RuleFieldSourceMap.toData(classRules.fieldSources),
        'classRuleConflicts': RuleOverrideConflicts.toData(classRules.conflicts),
        // 派生快照**无条件写入**（H）：只在有值时才写会让"关闭来源后再派生"留下
        // 旧包的数值（`hitDie` 变 null 而 `spellSlots` 还是旧值），来源与数值自相
        // 矛盾。派生结果为空也要显式清空（空表 `{}` / 空列表 `[]` / 无值 `null`），
        // 消费方据此按**键是否存在**判断"是否已派生"，绝不按"值是否非空"回退。
        'spellSlots': spellSlots,
        'spellcastingAbility': classRules.spellcastingAbility,
        'preparedSpellLimit': classRules.preparedLimit(build.level),
        'startingEquipmentMaximum': switch (
          StructuredClassRules.startingEquipmentChoice(classEntry)
        ) {
          final StartingEquipmentChoice equipmentChoice => equipmentChoice.maximum,
          _ => null,
        },
        'classResources': [
          for (final resource in classResources)
            {
              'id': resource.id,
              'name': resource.name,
              'maximum': resource.maximum,
              'recovery': resource.recovery,
            },
        ],
        'actions': [
          for (final action in actions)
            {
              'id': action.id,
              'name': action.label,
              if (action.entryId != null) 'entryId': action.entryId,
              if (action.formula != null) 'formula': action.formula,
            },
        ],
        'runtime': {
          if (classResources.isNotEmpty)
            'classResourcesUsed': {
              for (final resource in classResources) resource.id: 0,
            },
        },
      },
    );
  }

  /// 再派生的**唯一**换算点：把角色卡上的"最终属性值"（已含 `kind: ability`
  /// 授予的加值）换算回 [build] 对应的**基础属性**（= 最终值 − 加值）。
  ///
  /// 加值由"条目 + 等级 + 选择"确定性算出，因此该换算本身可重复执行而不累积；
  /// `character_upgrade_planner` / `character_rule_projector` / 编辑器在选择
  /// "再次派生"时必须调用这里，**不要**各自再写一遍减法（缺陷 4）。
  ///
  /// 精确性依赖 §3.5 的约束：`kind: ability` 只接受 `value`（导入期拒绝
  /// `formula`）。加值因此与 [finalAbilities] 无关，一遍减法就是精确逆；
  /// 自引用 / 链式 `formula` 不再是可达状态（此前两遍求值不是不动点，会把属性
  /// 每次再派生都抬高一份）。
  ///
  /// [finalAbilities] 通常是 `CharacterSheet.abilityMap`；[build] 必须是**角色卡上
  /// 那份已经生效的构建**（等级 = `character.level`），否则会把"本等级新增的加值"
  /// 也当成已含的值减掉。
  Map<String, int> baseAbilitiesFrom(
    Map<String, Object?> finalAbilities,
    CharacterBuild build,
  ) {
    final normalized = <String, int>{
      for (final key in Dnd5eRules.defaultAbilities.keys)
        key: Dnd5eRules.abilityScore(finalAbilities, key),
    };
    // `countsToward` 的池上限与 [build] **同口径**：池被占满时进 `invalidSelected`
    // 的选择同样不产出 grants，减加值必须看到同一份账，否则减法不是精确逆。
    final classRules = _classRulesFor(build);
    final ledger = _engine.evaluate(
      // **与 [build] 同一份门禁输入**（见 [_gateBuildFor]）：两条路径的门槛判据一旦
      // 分叉，"减法"就不是精确逆——一边按门槛发出 `kind: ability` 加值、另一边按空
      // 门槛不发，旧存档再派生就会每次多叠一份。
      _gateBuildFor(build, normalized),
      poolLimits: RuleChoiceQuota.limitsFor(
        rules: classRules,
        level: build.level,
      ),
    );
    return _subtract(normalized, _abilityGrantBonuses(ledger));
  }

  /// `requires` 门禁输入的唯一解析（决策 D4）。
  ///
  /// 门槛读的是**基础属性**，但对**旧存档**（`data['build']` 没有 `abilities`）来说，
  /// 角色卡上的当前属性是唯一可用真相：那时回退到调用方传进来的属性表。全新派生时
  /// 二者相同，因此只有"旧存档 + 门槛型选择"这一条路径受影响，结果从"静默丢失加值"
  /// 变成"按当前属性判定"。
  ///
  /// [build] 与 [baseAbilitiesFrom] **必须**用同一份输入：否则减加值与叠加加值用的
  /// 不是同一份账，再派生会重复叠加。
  CharacterBuild _gateBuildFor(
    CharacterBuild build,
    Map<String, Object?> abilities,
  ) {
    if (build.abilities.isNotEmpty) return build;
    return CharacterBuild(
      level: build.level,
      selections: build.selections,
      choices: build.choices,
      abilities: <String, int>{
        for (final key in Dnd5eRules.defaultAbilities.keys)
          key: Dnd5eRules.abilityScore(abilities, key),
      },
    );
  }

  /// [build] 所选职业的解析后职业规则（角色自身条目 ∪ 跨包声明 ∪ 档案），供额度池
  /// 等数值使用。唯一入口仍是 [Dnd5eRules.resolveClassRules]；本方法只是把同一份
  /// 调用收口，避免 `build` / `baseAbilitiesFrom` 各写一遍。
  ///
  /// `entryPriority` 取角色**自己那条**条目所属包的 priority——它与索引里的其它
  /// 声明参与同一套 tier 排序（决策 D2/D3）；`disabledOriginIds` / `pinnedOrigins`
  /// 来自构造时读取的角色数据（[CharacterRuleOverrides]）。
  ResolvedClassRules _classRulesFor(
    CharacterBuild build, {
    String? classSummaryFallback,
  }) {
    final classEntry = _selectedEntry(build, 'class');
    final entryId = classEntry?.id;
    return Dnd5eRules.resolveClassRules(
      entryId: entryId,
      classSummary: classEntry?.name ?? classSummaryFallback ?? '',
      structured: classEntry?.structured ?? const <String, Object?>{},
      overrides: _overrides,
      entryPriority:
          _packagePriorities[RuleOverrideDeclaration.packageIdOf(entryId ?? '')] ??
          0,
      disabledOriginIds: disabledOriginIds,
      pinnedOrigins: pinnedOrigins,
    );
  }

  /// 基础属性 = 最终值 − 加值。**下限 0 / 上限 30**：脏存档（最终值低于授予
  /// 加值，或高于属性硬上限）不得反推出负基础值——负值会在下一次 `build` 里
  /// 变成 `abilityModifier` 的负调整值，把 AC / HP / 豁免一起带偏。上限取 30 是
  /// D&D 5e 属性值的绝对上限（魔法/传奇恩惠也只到这个数），下限取 0 是因为属性
  /// 没有合法负值；`_abilityGrantBonuses` 只累加正值授予，合法输入永不触界。
  Map<String, int> _subtract(Map<String, int> values, Map<String, int> bonuses) {
    return <String, int>{
      for (final entry in values.entries)
        entry.key: (entry.value - (bonuses[entry.key] ?? 0)).clamp(0, 30),
    };
  }

  /// `kind: action` 的运行时行：动作身份是 `entryId + grant.id`，**没有随等级
  /// 变化的语义**，而多等级步骤（`levels`）会把同一份动作定义逐级展开成 N 个
  /// 生效单元。这里按身份只保留最早生效的那条，避免 `data['actions']` 出现 N 条
  /// 完全相同的动作行（与 `hitPoints` / `speed` / `armorClass` 的"多等级 → 多条"
  /// 情形不同：那三者是可累加的数值，必须逐条结算）。
  ///
  /// 顺序保持 ledger 的产出顺序（选择遍历顺序稳定），不额外排序。
  List<ResolvedRuleGrant> _actionRows(CharacterGrantLedger ledger) {
    final rows = <String, ResolvedRuleGrant>{};
    for (final grant in ledger.grantsOfKind(RuleGrantKind.action)) {
      rows.putIfAbsent(
        ruleActionKey(grant.sourceEntryId, grant.id),
        () => grant,
      );
    }
    return rows.values.toList(growable: false);
  }

  ContentEntry? _selectedEntry(CharacterBuild build, String slot) {
    final id = build.selections[slot];
    return id == null ? null : entries[id];
  }

  /// 库存行：`rules.grants` / 条目选择带出的物品在前（带 `entryId`），选中的装备
  /// 方案物品按声明顺序追加（无 `entryId`，`itemTemplate` 被忽略）。
  List<Map<String, Object>> _inventoryRows(
    List<String> itemRefs,
    List<EquipmentBundleItems> bundles,
  ) {
    final rows = <Map<String, Object>>[
      for (final entryId in itemRefs)
        {
          'entryId': entryId,
          'name': entries[entryId]?.name ?? entryId,
          'quantity': 1,
        },
    ];
    for (final bundle in bundles) {
      rows.addAll(bundle.items);
    }
    return rows;
  }

  /// 显式法术选择（`optionType: "spell"`）的选中值 → 已准备 / 始终准备两份镜像。
  ///
  /// 语义（契约 §3.11 A3）：**所有**显式法术选择的选中法术都进 `prepared`；
  /// `countsToward == null` 的那些**额外**进 `alwaysPrepared`（不占数量池，
  /// 只用于展示"始终准备"标记）。
  ///
  /// **唯一实现点**：选择键的解析只有 `RuleChoiceSemantics.definitionForKey`、
  /// 法术选择判据只有 `RuleChoiceDefinition.isSpellChoice`（"专门 UI"判据的
  /// `spell` 分支）；两份镜像都在这里生成，
  /// **不得**再有第二个合并点。两份都是**去重**集合（决策 D9）：重复选取的次数
  /// 只保留在有序的 `build.choices` 里。
  /// 显式法术选择（`optionType: "spell"`）的**自动准备**镜像（契约 §3.11 A3）。
  ///
  /// 选中的法术**全部**进 `alwaysPreparedEntryIds`，按首次出现顺序去重（决策 D9：
  /// 重复选取的**次数**只保留在有序的 `build.choices` 里）；
  /// `preparedSpellEntryIds` 是**用户手动准备**的存储，这里**不产出**它。
  /// 判定与去重只有本方法一处。
  List<String> _spellChoicePreparedPicks(CharacterGrantLedger ledger) {
    final prepared = <String>[];
    for (final choice in ledger.resolvedChoices.entries) {
      final resolved = RuleChoiceSemantics.definitionForKey(
        choice.key,
        entries: entries,
      );
      if (resolved == null || !resolved.definition.isSpellChoice) continue;
      for (final id in choice.value) {
        if (!prepared.contains(id)) prepared.add(id);
      }
    }
    return prepared;
  }

  /// 装备方案 A/B：`optionType: "equipmentBundle"` 选择的选中值 → 逐条
  /// `EquipmentBundleItems`。
  ///
  /// **唯一实现点**：`structured.items` / `structured.currency` 的解析只在
  /// `EquipmentBundleItems.from`；本方法只负责按"选择的选中值"挑出方案条目
  /// （`rules.grants` 带出的方案条目不被当成库存物品，见
  /// `_choiceEntryRefs(..., {'equipment','item'})` 不含 `equipmentBundle`）。
  List<EquipmentBundleItems> _equipmentBundles(CharacterGrantLedger ledger) {
    final bundles = <EquipmentBundleItems>[];
    for (final selection in ledger.resolvedChoices.values) {
      for (final id in selection) {
        final entry = entries[id];
        if (entry == null || entry.type != 'equipmentBundle') continue;
        bundles.add(EquipmentBundleItems.from(entry.structured));
      }
    }
    return bundles;
  }

  /// 货币合计：币种键的**唯一**来源是 [EquipmentBundleItems.currencyKeys]
  /// （`lib` 内不再有任何 `'cp'` / `'pp'` 之类的字面量清单；编辑器面板、快速创建
  /// 与怪物模板的初始货币都读它），本方法只做累加。
  Map<String, int> _currencyTotals(List<EquipmentBundleItems> bundles) {
    final totals = <String, int>{
      for (final key in EquipmentBundleItems.currencyKeys) key: 0,
    };
    for (final bundle in bundles) {
      for (final entry in bundle.currency.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    return totals;
  }

  /// 记录型选择里的**语言**：`optionType == "language"` 的选中值 → 候选 label。
  ///
  /// **唯一实现点**：选择键的解析只有 `RuleChoiceSemantics.definitionForKey` 一处、
  /// 候选 label 只有 `RuleChoiceSemantics.candidatesFor` 一处；本方法只做"挑出
  /// language 选择 + 取 label + 去重"，不自己 split 键、不读 `entry.type`。
  List<String> _languagePicks(CharacterGrantLedger ledger) {
    final picks = <String>[];
    for (final choice in ledger.resolvedChoices.entries) {
      final resolved = RuleChoiceSemantics.definitionForKey(
        choice.key,
        entries: entries,
      );
      if (resolved == null ||
          resolved.definition.optionType != 'language') {
        continue;
      }
      final labels = {
        for (final candidate in RuleChoiceSemantics.candidatesFor(
          resolved.definition,
          entries: entries,
          sourceEntryId: resolved.sourceEntryId,
        ))
          candidate.id: candidate.label,
      };
      for (final id in choice.value) {
        final label = labels[id] ?? id;
        if (!picks.contains(label)) picks.add(label);
      }
    }
    return picks;
  }

  List<String> _entryRefs(CharacterGrantLedger ledger, RuleGrantKind kind) {
    return ledger
        .grantsOfKind(kind)
        .map((grant) => grant.entryId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }

  Iterable<String> _choiceEntryRefs(
    CharacterGrantLedger ledger,
    Set<String> entryTypes,
  ) sync* {
    for (final entryId in ledger.resolvedChoiceEntryIds) {
      if (entryTypes.contains(entries[entryId]?.type)) yield entryId;
    }
  }

  List<CharacterContentReference> _contentReferences(
    CharacterBuild build,
    CharacterGrantLedger ledger, {
    Set<String> extraEntryIds = const <String>{},
  }) {
    final references = <String, CharacterContentReference>{};
    for (final selection in build.selections.entries) {
      final entry = entries[selection.value];
      if (entry == null) continue;
      references[entry.id] = CharacterContentReference(
        slot: selection.key,
        entryKey: entry.id,
        sourceRevision: entry.revision,
        snapshot: _snapshot(entry),
      );
    }
    for (final choice in build.choices.entries) {
      for (final entryId in choice.value) {
        final entry = entries[entryId];
        if (entry == null || references.containsKey(entry.id)) continue;
        references[entry.id] = CharacterContentReference(
          slot: 'choice:${choice.key}',
          entryKey: entry.id,
          sourceRevision: entry.revision,
          snapshot: _snapshot(entry),
        );
      }
    }
    for (final grant in ledger.grants) {
      final entryId = grant.entryId;
      final entry = entryId == null ? null : entries[entryId];
      if (entry == null || references.containsKey(entry.id)) continue;
      references[entry.id] = CharacterContentReference(
        slot: grant.kind.name,
        entryKey: entry.id,
        sourceRevision: entry.revision,
        snapshot: _snapshot(entry),
      );
    }
    for (final entryId in extraEntryIds) {
      final entry = entries[entryId];
      if (entry == null || references.containsKey(entry.id)) continue;
      references[entry.id] = CharacterContentReference(
        slot: 'manual',
        entryKey: entry.id,
        sourceRevision: entry.revision,
        snapshot: _snapshot(entry),
      );
    }
    return references.values.toList(growable: false);
  }

  Map<String, Object?> _snapshot(ContentEntry entry) => <String, Object?>{
    'snapshotVersion': 1,
    ...entry.toJson(),
  };

  /// 生命骰来自职业规则（条目声明 ∪ 档案）。未声明生命骰（`hitDie == null`）
  /// 不猜：只按体质调整值计，且总生命至少 1（§3.6 第 3 步）。
  ///
  /// [bonus] 是 `kind: hitPoints` 授予结算出的固定加值（`value` + `formula`），
  /// 在基础生命值之上叠加；两者之和仍至少为 1。
  int _averageHitPoints({
    required int? hitDie,
    required int level,
    required int constitution,
    required int bonus,
  }) {
    final safeLevel = level.clamp(1, 20);
    final base = hitDie == null
        ? (rule_math.abilityModifier(constitution) * safeLevel).clamp(1, 1 << 30)
        : Dnd5eRules.averageHitPointsForHitDie(
            hitDie: hitDie,
            level: safeLevel,
            constitution: constitution,
          );
    return (base + bonus).clamp(1, 1 << 30);
  }

  /// `kind: ability` 授予的属性加值：`target` 是属性键（档案 `abilities` 之一），
  /// `value` 累加。无 `target` 或非档案属性的授予被跳过（不是属性加值）。
  ///
  /// 判据是 [Dnd5eRules.profile]`.abilities`，**不是**任何写死的键名单：
  /// [Dnd5eRules.abilityLabels] / [Dnd5eRules.defaultAbilities] 现在都由档案
  /// `abilities` 派生（键集合只有一处来源），本方法直接读档案，绝不硬编码。
  /// 导入期 `RuleProfileResolver.validateEntryClassRules` 按档案 `abilities`
  /// 放行 `target`，两边**同源**，不会出现"导入放行、运行期静默丢弃加值"。
  ///
  /// `formula` **不被读取**：§3.5 规定 `kind: ability` 只接受 `value`，
  /// [`ContentPackageImporter`] 在导入期就拒绝 `formula`（含自引用 `ability:<自身
  /// target>` 与链式引用），因为它们让 `baseAbilitiesFrom` 的减法没有精确逆、
  /// 每次再派生都会把属性抬高一份。这里因此不存在"非法 formula 静默按 0"的分支：
  /// 导入拦不住的（程序化构造）走 `RuleGrantDefinition.fromJson` 的二选一拒绝；
  /// 两者都绕过的极少数情况按 0 处理，与 `_hitPointGrantBonus` 的"不猜"一致。
  Map<String, int> _abilityGrantBonuses(CharacterGrantLedger ledger) {
    final abilities = Dnd5eRules.profile.abilities;
    final bonuses = <String, int>{};
    for (final grant in ledger.grantsOfKind(RuleGrantKind.ability)) {
      final target = grant.target;
      if (target == null || !abilities.contains(target)) {
        continue;
      }
      final value = grant.value?.toInt() ?? 0;
      if (value == 0) continue;
      bonuses[target] = (bonuses[target] ?? 0) + value;
    }
    return bonuses;
  }

  /// `kind: hitPoints` 授予结算为固定加值：`value` 直接累加；`formula` 经
  /// `MaxSpec.tryParse` + `resolve`（封闭语法，`level` 用职业等级）求值。
  /// 非法的 `formula` 按未声明处理（`tryParse` 返回 null），不猜。
  int _hitPointGrantBonus(
    CharacterGrantLedger ledger, {
    required int level,
    required Map<String, int> abilities,
  }) {
    var total = 0;
    for (final grant in ledger.grantsOfKind(RuleGrantKind.hitPoints)) {
      total += grant.value?.toInt() ?? 0;
      final formula = grant.formula;
      if (formula == null) continue;
      final spec = MaxSpec.tryParse(<String, Object?>{'formula': formula});
      final resolved = spec?.resolve(level: level, abilities: abilities);
      if (resolved != null) total += resolved;
    }
    return total;
  }
}
