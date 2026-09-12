import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_build.dart';
import 'character.dart';
import 'character_content_reference.dart';
import 'declared_levels.dart';
import 'dnd5e_rules.dart';
import 'rules_driven_character_builder.dart';

/// Recomputes derived rule snapshots for characters saved before rules existed.
class CharacterRuleProjector {
  const CharacterRuleProjector({required this.entries});

  final Map<String, ContentEntry> entries;

  CharacterSheet project(CharacterSheet character) {
    final rawBuild = character.dataMap['build'];
    if (rawBuild is! Map || entries.isEmpty) {
      return _withClassIdentity(character);
    }
    final savedBuild = CharacterBuild.fromJson(
      Map<String, Object?>.from(rawBuild),
    );
    if (savedBuild.selections.values.every((id) => !entries.containsKey(id))) {
      return _withClassIdentity(character);
    }

    final builder = RulesDrivenCharacterBuilder(entries: entries);
    // 再派生必须用**基础属性**：角色卡上的 `abilities` 已含生效中的
    // `kind: ability` 加值，直接回传会每次派生都再叠加一遍（缺陷 4）。
    // 减加值的唯一实现在 [RulesDrivenCharacterBuilder.baseAbilitiesFrom]。
    // 「前置不满足的选择不生效」这条门禁读的是 `build.abilities`（决策 D4），
    // 所以**反推的账与重派生的账必须看到同一份输入**，否则减掉的是"没生效的加值"
    // 或漏减了"生效中的加值"，HP / AC 会漂移、再派生也不再幂等。下面这份
    // `ledgerAbilities` 就是那**唯一一份**输入：先给 `baseAbilitiesFrom`，再给
    // `build`。
    final ledgerAbilities = savedBuild.abilities.isNotEmpty
        ? savedBuild.abilities
        // 旧存档没有 `data['build']['abilities']`：先用"无能力记录"求一次基础属性
        // （无记录 = 门槛不满足 = 只有无条件加值被减掉），把它当作门禁输入。
        : builder.baseAbilitiesFrom(
            character.abilityMap,
            CharacterBuild(
              level: character.level,
              selections: savedBuild.selections,
              choices: savedBuild.choices,
            ),
          );
    final stateBuild = CharacterBuild(
      level: character.level,
      selections: savedBuild.selections,
      choices: savedBuild.choices,
      abilities: ledgerAbilities,
    );
    final baseAbilities = builder.baseAbilitiesFrom(
      character.abilityMap,
      stateBuild,
    );
    final build = CharacterBuild(
      level: character.level,
      selections: savedBuild.selections,
      choices: savedBuild.choices,
      // 旧存档没有 `data['build']['abilities']`：这次派生**自愈**回填基础属性
      // 输入，否则能力型 `requires` 会永远判为不满足（决策 D4 的可见 pending）。
      // 回填的是**门禁输入**（上面那一份），不是角色卡上的最终值——`requires`
      // 的口径如此。
      abilities: ledgerAbilities,
    );
    final derived = builder.build(
      name: character.name,
      build: build,
      abilities: baseAbilities,
      notes: character.notes,
    );
    final oldData = character.dataMap;
    final derivedData = derived.data;
    final mergedData = Map<String, Object?>.from(oldData);
    for (final key in const [
      'build',
      'choices',
      'resolvedGrants',
      'pendingChoices',
      'spellSlots',
      'spellcastingAbility',
      'preparedSpellLimit',
      'hitDie',
      'savingThrowAbilities',
      'classResources',
      'actions',
    ]) {
      if (derivedData.containsKey(key)) mergedData[key] = derivedData[key];
    }
    mergedData['contentRefs'] = _mergeContentRefs(
      oldData['contentRefs'],
      derivedData['contentRefs'],
    );
    mergedData['ruleSnapshots'] = _mergeMaps(
      oldData['ruleSnapshots'],
      derivedData['ruleSnapshots'],
    );

    mergedData['classIdentity'] = _classIdentity(
      Map<String, Object?>.from(
        (derivedData['classIdentity'] as Map?) ?? const <String, Object?>{},
      ),
      character,
    );

    return character.copyWith(
      data: mergedData,
      contentReferences: _mergeReferences(
        character.contentReferences,
        derived.contentReferences,
      ),
    );
  }

  /// 老角色回填 `data.classIdentity`（契约 §3.12：声明范围随角色持久化）。
  ///
  /// - 优先用派生结果（条目身份 + 条目声明的 `declaredLevels`）；
  /// - 派生结果里 `entryId` 为空（原始存档没有 `build.selections.class`）时，
  ///   按 **slug / name / aliases 精确匹配**回填（[Dnd5eRules.resolveClassSlug]
  ///   只做精确相等或 `<别名><分隔符>` 前缀，**禁止裸子串**）；
  /// - 匹配不到就显式标记 `declared: false`（"未声明"），界面据此不显示 0。
  ///
  /// 声明范围**不在这里手写形状**：拿不到条目（没有 `build.selections.class`）时
  /// 走 [Dnd5eRules.resolveClassRules] + [DeclaredLevels.fromResolvedClassRules]，
  /// 也就是与 Builder / 向导同一个权威口径（内置档案同 slug 职业的范围）。
  /// 老角色 `吟游诗人` 因此拿到档案的 1–20，而不是被写成 `{min: null, max: null}`
  /// 让角色卡误报"该职业未声明该等级的内容"。
  Map<String, Object?> _classIdentity(
    Map<String, Object?> derivedIdentity,
    CharacterSheet character,
  ) {
    final entryId = '${derivedIdentity['entryId'] ?? ''}'.trim();
    if (entryId.isNotEmpty) return derivedIdentity;

    final slug = Dnd5eRules.resolveClassSlug(
      classSummary: character.classSummary,
    );
    final declaredLevels = DeclaredLevels.fromResolvedClassRules(
      Dnd5eRules.resolveClassRules(
        entryId: null,
        classSummary: character.classSummary,
      ),
    );
    return <String, Object?>{
      'entryId': null,
      'slug': slug.isEmpty ? null : slug,
      'name': character.classSummary,
      'declaredLevels': declaredLevels.toData(),
      'declared': slug.isNotEmpty,
    };
  }

  CharacterSheet _withClassIdentity(CharacterSheet character) {
    final identity = _classIdentity(const <String, Object?>{}, character);
    final existing = character.dataMap['classIdentity'];
    if (existing is Map &&
        '${existing['slug'] ?? ''}' == '${identity['slug'] ?? ''}' &&
        existing['declared'] == identity['declared']) {
      return character;
    }
    final data = Map<String, Object?>.from(character.dataMap)
      ..['classIdentity'] = identity;
    return character.copyWith(data: data);
  }

  Map<String, Object?> _mergeContentRefs(Object? current, Object? derived) {
    final oldRefs = current is Map
        ? Map<String, Object?>.from(current)
        : const <String, Object?>{};
    final newRefs = derived is Map
        ? Map<String, Object?>.from(derived)
        : const <String, Object?>{};
    return {
      ...oldRefs,
      for (final key in const ['features', 'spells', 'items'])
        key: {
          ..._stringList(oldRefs[key]),
          ..._stringList(newRefs[key]),
        }.toList(growable: false),
    };
  }

  Map<String, Object?> _mergeMaps(Object? current, Object? derived) => {
    if (current is Map) ...Map<String, Object?>.from(current),
    if (derived is Map) ...Map<String, Object?>.from(derived),
  };

  List<CharacterContentReference> _mergeReferences(
    List<CharacterContentReference> current,
    List<CharacterContentReference> derived,
  ) {
    final byKey = <String, CharacterContentReference>{
      for (final reference in current) reference.entryKey: reference,
      for (final reference in derived) reference.entryKey: reference,
    };
    return byKey.values.toList(growable: false);
  }

  Iterable<String> _stringList(Object? value) {
    return value is List
        ? value.map((item) => '$item').where((item) => item.isNotEmpty)
        : const <String>[];
  }
}
