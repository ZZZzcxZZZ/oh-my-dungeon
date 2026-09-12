import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_build.dart';
import '../../rules/domain/character_rule_definition.dart';
import '../../rules/domain/character_rules_engine.dart';
import '../../rules/domain/rule_math.dart' as rule_math;
import '../../rules/domain/rule_values.dart';
import 'character_content_reference.dart';
import 'character_edit_draft.dart';
import 'declared_levels.dart';
import 'dnd5e_rules.dart';
import 'structured_class_rules.dart';

class RulesDrivenCharacterBuilder {
  RulesDrivenCharacterBuilder({required this.entries})
    : _engine = CharacterRulesEngine(entries: entries);

  final Map<String, ContentEntry> entries;
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
  }) {
    final classEntry = _selectedEntry(build, 'class');
    final speciesEntry = _selectedEntry(build, 'species');
    final backgroundEntry = _selectedEntry(build, 'background');
    // 职业数值的唯一入口：条目身份优先，`structured.classRules` 覆盖档案（§3.6、§3.7）。
    final classRules = Dnd5eRules.resolveClassRules(
      entryId: classEntry?.id,
      classSummary: classEntry?.name ?? '',
      structured: classEntry?.structured ?? const <String, Object?>{},
    );
    final ledger = _engine.evaluate(build);
    final effectiveBuild = CharacterBuild(
      level: build.level,
      selections: build.selections,
      choices: ledger.resolvedChoices,
    );
    // 属性加值（`kind: ability`）必须在**任何派生之前**叠加：HP / AC / 豁免 /
    // 技能 / 法术 DC 全部读 [effectiveAbilities]，不再读入参 [abilities]。
    // `kind: ability` **只接受 `value`**（导入期拒绝 `formula`，见契约 §3.5），
    // 因此叠加只依赖 [abilities] 本身，`baseAbilitiesFrom` 的逆运算精确。
    // `kind: hitPoints` / `classResources` 的 `formula` 则拿**叠加后**的
    // [effectiveAbilities] 求值（下面 `_hitPointGrantBonus` 与
    // `classResourcesFromRules` 传入的正是这份值）。
    final effectiveAbilities = <String, int>{...abilities};
    _abilityGrantBonuses(ledger).forEach((key, value) {
      effectiveAbilities[key] = (effectiveAbilities[key] ?? 10) + value;
    });
    final saves = {for (final key in Dnd5eRules.abilityLabels.keys) key: false};
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
    final speedGrant = ledger.grantsOfKind(RuleGrantKind.speed).lastOrNull;
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

    return CharacterEditDraft(
      name: name.trim(),
      level: build.level,
      classSummary: classEntry?.name ?? '',
      raceSummary: speciesEntry?.name ?? '',
      currentHp: maxHp,
      maxHp: maxHp,
      armorClass: Dnd5eRules.baseArmorClass(effectiveAbilities) + armorBonus,
      speed: speedGrant?.value?.toInt() ?? 30,
      initiativeBonus: Dnd5eRules.initiativeBonus(effectiveAbilities),
      abilities: Map<String, int>.from(effectiveAbilities),
      saves: saves,
      skills: skills,
      inventory: [
        for (final entryId in itemRefs)
          {
            'entryId': entryId,
            'name': entries[entryId]?.name ?? entryId,
            'quantity': 1,
          },
      ],
      currency: const {'cp': 0, 'sp': 0, 'ep': 0, 'gp': 0, 'pp': 0},
      notes: notes.isEmpty
          ? 'D&D 2024 引导创建：${backgroundEntry?.name ?? ''} / ${speciesEntry?.name ?? ''} / ${classEntry?.name ?? ''}。'
          : notes,
      avatarUrl: avatarUrl,
      contentReferences: contentReferences,
      data: {
        'build': effectiveBuild.toJson(),
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
            },
        ],
        'classIdentity': {
          'entryId': classEntry?.id,
          'slug': classEntry?.slug,
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
        if (spellSlots.isNotEmpty) 'spellSlots': spellSlots,
        if (classRules.spellcastingAbility case final String ability)
          'spellcastingAbility': ability,
        if (classRules.preparedLimit(build.level) case final int preparedLimit)
          'preparedSpellLimit': preparedLimit,
        if (StructuredClassRules.startingEquipmentChoice(classEntry)
            case final StartingEquipmentChoice equipmentChoice)
          'startingEquipmentMaximum': equipmentChoice.maximum,
        if (classResources.isNotEmpty)
          'classResources': [
            for (final resource in classResources)
              {
                'id': resource.id,
                'name': resource.name,
                'maximum': resource.maximum,
                'recovery': resource.recovery,
              },
          ],
        if (actions.isNotEmpty)
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
    final ledger = _engine.evaluate(build);
    return _subtract(normalized, _abilityGrantBonuses(ledger));
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
  /// 完全相同的动作行（`speed` 走 `lastOrNull` 已是单条，两者的"一条"口径在此统一）。
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
  /// `formula` **不被读取**：§3.5 规定 `kind: ability` 只接受 `value`，
  /// [`ContentPackageImporter`] 在导入期就拒绝 `formula`（含自引用 `ability:<自身
  /// target>` 与链式引用），因为它们让 `baseAbilitiesFrom` 的减法没有精确逆、
  /// 每次再派生都会把属性抬高一份。这里因此不存在"非法 formula 静默按 0"的分支：
  /// 导入拦不住的（程序化构造）走 `RuleGrantDefinition.fromJson` 的二选一拒绝；
  /// 两者都绕过的极少数情况按 0 处理，与 `_hitPointGrantBonus` 的"不猜"一致。
  Map<String, int> _abilityGrantBonuses(CharacterGrantLedger ledger) {
    final bonuses = <String, int>{};
    for (final grant in ledger.grantsOfKind(RuleGrantKind.ability)) {
      final target = grant.target;
      if (target == null || !Dnd5eRules.abilityLabels.containsKey(target)) {
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

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
