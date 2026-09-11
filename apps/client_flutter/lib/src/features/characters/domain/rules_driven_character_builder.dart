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
    final actions = ledger.grantsOfKind(RuleGrantKind.action).toList();
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
  /// `value` 累加；无 `target` 或非档案属性的授予被跳过（不是属性加值）。
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
