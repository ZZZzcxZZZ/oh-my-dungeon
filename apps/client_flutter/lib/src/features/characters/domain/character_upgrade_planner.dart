import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_build.dart';
import '../../rules/domain/character_rules_engine.dart';
import '../../rules/domain/rule_choice_quota.dart';
import 'character.dart';
import 'character_content_reference.dart';
import 'character_manual_overrides.dart';
import 'declared_levels.dart';
import 'dnd5e_rules.dart';
import 'rules_driven_character_builder.dart';

class CharacterUpgradePlan {
  const CharacterUpgradePlan({
    required this.currentLevel,
    required this.targetLevel,
    required this.build,
    required this.newGrants,
    required this.choices,
    required this.missingEntryIds,
    required this.declaredLevels,
  });

  final int currentLevel;
  final int targetLevel;
  final CharacterBuild build;
  final List<ResolvedRuleGrant> newGrants;
  final List<ActiveRuleChoice> choices;
  final List<String> missingEntryIds;

  /// 角色的职业声明范围（§3.12）。
  final DeclaredLevels declaredLevels;

  /// 目标等级是否落在声明范围之外（低于最早声明等级、或高于最后声明等级）。
  /// 界面据此提示"该职业未声明…，你仍可继续（数值按未声明处理）"。
  ///
  /// "完全没有等级声明"（[DeclaredLevels.isEmpty]，即 `max == null`）也算范围之外：
  /// 没有任何 min/max 可比较，界面此时展示的是 [DeclaredLevels.rangeLabel] 的
  /// "该职业未声明任何等级内容"，而不是把"不知道"当成"已覆盖"。
  bool get beyondDeclaredLevel =>
      declaredLevels.isEmpty ||
      declaredLevels.isBeyond(targetLevel) ||
      declaredLevels.isBelow(targetLevel);

  /// 本级选择必须**真的完成**（数量 + `requires`，见 [ActiveRuleChoice.isValid]）。
  ///
  /// "专门 UI"判据（选择是否由专门渲染器承担）只决定渲染位置，不再是"免检"
  /// 例外：升级页
  /// 用共享组件渲染本级新增的每一条选择，所以"要求完成"不会变成死锁——反而是
  /// 免检会让本级新增的专门 UI 选择被静默跳过（§3.10.3-7）。
  bool get isComplete =>
      missingEntryIds.isEmpty && choices.every((choice) => choice.isValid);
}

class CharacterUpgradePlanner {
  CharacterUpgradePlanner({required this.entries})
    : _engine = CharacterRulesEngine(entries: entries);

  final Map<String, ContentEntry> entries;
  final CharacterRulesEngine _engine;

  CharacterUpgradePlan plan(CharacterSheet character) {
    if (character.level >= 20) {
      throw StateError('This character has already reached level 20.');
    }
    final savedBuild = _savedBuild(character);
    final targetLevel = character.level + 1;
    final build = CharacterBuild(
      level: targetLevel,
      selections: savedBuild.selections,
      choices: savedBuild.choices,
      abilities: _baseAbilities(character, savedBuild),
    );
    return _evaluate(
      character.level,
      build,
      declaredLevels: DeclaredLevels.fromCharacter(character),
    );
  }

  CharacterUpgradePlan select(
    CharacterSheet character,
    CharacterUpgradePlan plan,
    String choiceKey,
    List<String> entryIds,
  ) {
    final choices = <String, List<String>>{
      ...plan.build.choices,
      choiceKey: List<String>.unmodifiable(entryIds),
    };
    return _evaluate(
      character.level,
      CharacterBuild(
        level: plan.targetLevel,
        selections: plan.build.selections,
        choices: choices,
        // `requires` 的能力门槛读**同一份基础属性**（决策 D4）：换选择不改属性，
        // 沿用计划里的那份即可（[plan] 由 `plan()` 用 `_baseAbilities` 建出）。
        abilities: plan.build.abilities,
      ),
      declaredLevels: plan.declaredLevels,
    );
  }

  CharacterSheet apply(CharacterSheet character, CharacterUpgradePlan plan) {
    if (!plan.isComplete) {
      throw StateError(
        'Resolve all level-up choices before applying the plan.',
      );
    }
    if (plan.currentLevel != character.level ||
        plan.targetLevel != character.level + 1) {
      throw StateError('The level-up plan is stale.');
    }

    final builder = RulesDrivenCharacterBuilder(entries: entries);
    final derived = builder.build(
      name: character.name,
      build: plan.build,
      // 再派生必须用**基础属性**：角色卡上的 `abilities` 已含此前等级生效的
      // `kind: ability` 加值，直接回传会让同一份授予再叠加一次（缺陷 4）。
      // 减加值的唯一实现点在 [RulesDrivenCharacterBuilder.baseAbilitiesFrom]；
      // 减的是"角色卡当前等级"那份构建的加值，新增等级的那份由本次派生叠加。
      abilities: builder.baseAbilitiesFrom(
        character.abilityMap,
        _currentBuild(character),
      ),
      notes: character.notes,
    );
    final oldData = character.dataMap;
    final mergedData = Map<String, Object?>.from(oldData);
    for (final key in const <String>[
      'build',
      'choices',
      'contentRefs',
      'resolvedGrants',
      'pendingChoices',
      'spellSlots',
      'spellcastingAbility',
      'classResources',
      'actions',
    ]) {
      if (derived.data.containsKey(key)) mergedData[key] = derived.data[key];
    }
    // 显式法术选择的"已准备 / 始终准备"镜像由 builder 产出（§3.11 A3）。
    // **合并**而不是覆盖：派生结果里只有这两份镜像，用户的自定义法术 / 手动
    // 添加或移除的法术必须原样保留。合并实现只有
    // `CharacterManualOverrides.copyWithSpellPicksFrom` 一处。
    if (derived.data['manualOverrides'] case final Map derivedOverrides) {
      mergedData['manualOverrides'] = CharacterManualOverrides.fromJson(
        Map<String, Object?>.from(
          (oldData['manualOverrides'] as Map?) ?? const <String, Object?>{},
        ),
      )
          .copyWithSpellPicksFrom(
            CharacterManualOverrides.fromJson(
              Map<String, Object?>.from(derivedOverrides),
            ),
          )
          .toJson();
    }
    mergedData['ruleSnapshots'] = _mergeMaps(
      oldData['ruleSnapshots'],
      derived.data['ruleSnapshots'],
    );
    mergedData['runtime'] = oldData['runtime'] ?? derived.data['runtime'];

    final hpIncrease = derived.maxHp - character.maxHp;
    return character.copyWith(
      level: plan.targetLevel,
      classSummary: derived.classSummary,
      raceSummary: derived.raceSummary,
      currentHp: (character.currentHp + hpIncrease).clamp(0, derived.maxHp),
      maxHp: derived.maxHp,
      armorClass: derived.armorClass,
      speed: derived.speed,
      initiativeBonus: derived.initiativeBonus,
      // 派生结果里的属性是"最终值"（基础值 + 本等级为止的全部 ability 加值），
      // 必须写回，否则下一次再派生会把同一份加值重复叠加（缺陷 4）。
      abilities: derived.abilities,
      saves: derived.saves,
      skills: derived.skills,
      inventory: _mergeInventory(character.inventoryList, derived.inventory),
      data: mergedData,
      contentReferences: _mergeReferences(
        character.contentReferences,
        derived.contentReferences,
      ),
    );
  }

  CharacterUpgradePlan _evaluate(
    int currentLevel,
    CharacterBuild build, {
    required DeclaredLevels declaredLevels,
  }) {
    final ledger = _engine.evaluate(build, poolLimits: _poolLimits(build));
    return CharacterUpgradePlan(
      currentLevel: currentLevel,
      targetLevel: build.level,
      build: CharacterBuild(
        level: build.level,
        selections: build.selections,
        choices: ledger.resolvedChoices,
        abilities: build.abilities,
      ),
      newGrants: ledger.grants
          .where((grant) => grant.sourceLevel == build.level)
          .toList(growable: false),
      choices: ledger.activeChoices
          .where((choice) => choice.sourceLevel == build.level)
          .toList(growable: false),
      missingEntryIds: ledger.missingEntryIds,
      declaredLevels: declaredLevels,
    );
  }

  CharacterBuild _savedBuild(CharacterSheet character) {
    final raw = character.dataMap['build'];
    if (raw is! Map) {
      throw StateError('This character has no rules-driven build data.');
    }
    return CharacterBuild.fromJson(Map<String, Object?>.from(raw));
  }

  /// 角色卡上"当前已生效"的构建：等级以 [CharacterSheet.level] 为准，
  /// 选择沿用存档里的 `build`。用于反推基础属性。
  CharacterBuild _currentBuild(CharacterSheet character) {
    final saved = _savedBuild(character);
    return CharacterBuild(
      level: character.level,
      selections: saved.selections,
      choices: saved.choices,
      abilities: saved.abilities,
    );
  }

  /// `requires` 门槛要用的**基础属性**（决策 D4）。
  ///
  /// 优先读存档里的 `build.abilities`；旧存档没有它时用
  /// [RulesDrivenCharacterBuilder.baseAbilitiesFrom] 现算一次（与项目器同一个
  /// 唯一实现点，不另写减法）。缺属性时返回空 map = "未记录"：能力型
  /// `requires` 会判为不满足并进 pending，绝不猜成 10。
  Map<String, int> _baseAbilities(CharacterSheet character, CharacterBuild build) {
    if (build.abilities.isNotEmpty) return build.abilities;
    return RulesDrivenCharacterBuilder(
      entries: entries,
    ).baseAbilitiesFrom(character.abilityMap, build);
  }

  /// `countsToward` 的池上限（决策 D3）：数值来源只有
  /// [RuleChoiceQuota.limitsFor] 一处；这里负责把 [build] 所选职业解析出来。
  Map<String, int> _poolLimits(CharacterBuild build) {
    final classEntry = entries[build.selections['class']];
    return RuleChoiceQuota.limitsFor(
      rules: Dnd5eRules.resolveClassRules(
        entryId: classEntry?.id,
        classSummary: classEntry?.name ?? '',
        structured: classEntry?.structured ?? const <String, Object?>{},
      ),
      level: build.level,
    );
  }
}

Map<String, Object?> _mergeMaps(Object? current, Object? derived) => {
  if (current is Map) ...Map<String, Object?>.from(current),
  if (derived is Map) ...Map<String, Object?>.from(derived),
};

List<Map<String, Object?>> _mergeInventory(
  List<Object?> current,
  List<Map<String, Object>> derived,
) {
  final result = current
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: true);
  final knownEntryIds = result
      .map((item) => item['entryId'])
      .whereType<String>()
      .toSet();
  for (final item in derived) {
    final entryId = item['entryId'];
    if (entryId is String && knownEntryIds.add(entryId)) {
      result.add(Map<String, Object?>.from(item));
    }
  }
  return result;
}

List<CharacterContentReference> _mergeReferences(
  List<CharacterContentReference> current,
  List<CharacterContentReference> derived,
) {
  final references = <String, CharacterContentReference>{
    for (final reference in current) reference.entryKey: reference,
    for (final reference in derived) reference.entryKey: reference,
  };
  return references.values.toList(growable: false);
}
