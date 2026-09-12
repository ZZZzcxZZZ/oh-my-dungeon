// 选择系统校验的**唯一实现点**（计划 2 任务 12/13 的搬家式重构）：
// `importer` 只做编排（遍历条目、决定何时调用、汇总 error），本文件承担
// "原始 JSON 形状/取值"与"解析后的引用语义"两遍诊断。
//
// 契约：`docs/specs/2026-09-10-rules-contract-design.md` §5.1；
// `docs/README.md` §7.7 选择对象字段全集。
//
// 本文件里的函数都是**无状态纯函数**：只读入参（原始 JSON / `entries` /
// `sourceEntryId` / `entryIds`），只往传入的 `errors` 追加诊断，不读任何全局或
// importer 状态，因此可以被单测直接驱动。
import '../../../characters/domain/dnd5e_rules.dart';
import '../../../rules/domain/character_rule_definition.dart';
import '../../../rules/domain/rule_choice_resolver.dart';
import '../../../rules/domain/rule_choice_semantics.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_import_report.dart';
import '../../domain/content_schema_registry.dart';

/// `optionType` 的合法取值 = 内容 schema 的**条目类型** ∪ 值类型
/// （[kValueOptionTypes]，契约 §3.10.2）。
///
/// 不能拿 `ContentSchemaRegistry.normalizeType` 判断"是否已知"——它把任何未知
/// 类型都降级成 `custom`，永远返回一个合法类型。schema 的类型集合是唯一权威。
final Set<String> _knownOptionTypes = {
  for (final schema in ContentSchemaRegistry.defaults.schemas) schema.type,
  ...kValueOptionTypes,
};

/// 在解析 [ContentEntry] **之前**对条目原始 `rules` JSON 做形状/参照校验，
/// 返回本条目是否已经产出**精确到字段**的 error。
///
/// 为什么要有这一遍：解析层
/// （[RuleGrantDefinition.fromJson] / [RuleChoiceDefinition.fromJson] /
/// [RuleProgressionDefinition.fromJson]）只抛一条**没有位置**的
/// [FormatException]；若原样降级成 `invalid entry: …`（path 只到条目），作者
/// 拿不到出错字段，违反 §5.1 与 §10 第 5 条。这里的每条 error 都指向原始 JSON
/// 的具体字段。
///
/// 返回值的用途：调用方在 `catch` 里据此**不再**追加笼统的 `invalid entry`，
/// 避免同一条输入报两次、淹没精确位置。
///
/// 覆盖范围（§5.1）：`unknownGrantKind`、`unknownOptionType`、
/// `invalidChoiceRange`、`duplicateOptionId`、`invalidValueOption`、
/// `invalidAutoGrant`（条目类型的字符串元素）、`countsToward` 取值
/// （`invalidCountsToward`）、`requires` 的形状/取值（`invalidRequires`）、
/// 选择对象的未知字段（`unknownField`）。
///
/// **不覆盖**（仍走解析层笼统的 `invalid entry`，因为 §5.1 没有对应 code、
/// 或属于"列表本身不是数组 / 元素不是对象"这类结构错误）：`rules.grants` /
/// `rules.choices` / `progression[].grants` / `progression[].choices` 不是数组、
/// grant 项不是对象或缺 `id`、`maximumOptionLevel` 越界（0..9）、未知
/// `builderStep`、`repeatable` 非布尔、`group`/`help` 非非空字符串。
///
/// **值类型候选的语义校验**（`unknownSkill` / `invalidSkillCount` /
/// `unknownAbility` / `invalidAutoGrant`）不在这一遍：它们必须按
/// [RuleChoiceSemantics.candidatesFor]（UI 与引擎的**唯一候选枚举点**）判定，
/// 因此放在解析成功之后的 [validateRuleReferences]。
bool validateRawEntryRules(
  Map<String, Object?> entryJson,
  String entryPath,
  List<ContentValidationError> errors,
) {
  final rawRules = entryJson['rules'];
  if (rawRules is! Map) return false;
  final rules = Map<String, Object?>.from(rawRules);
  final rulesPath = '$entryPath.rules';
  final before = errors.length;

  void checkChoices(Object? raw, String path) {
    if (raw is! List) return;
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      if (item is! Map) continue;
      validateRawChoice(
        Map<String, Object?>.from(item),
        '$path[$index]',
        errors,
      );
    }
  }

  validateRawGrantKinds(rules['grants'], '$rulesPath.grants', errors);
  checkChoices(rules['choices'], '$rulesPath.choices');

  final progression = rules['progression'];
  if (progression == null) return errors.length > before;
  if (progression is! List) {
    errors.add(
      ContentValidationError(
        path: '$rulesPath.progression',
        message: 'progression 必须是数组（invalidTable）',
      ),
    );
    return errors.length > before;
  }
  for (var index = 0; index < progression.length; index++) {
    final step = progression[index];
    if (step is! Map) continue;
    final stepPath = '$rulesPath.progression[$index]';
    if (step.containsKey('level')) {
      errors.add(
        ContentValidationError(
          path: '$stepPath.level',
          message: 'progression 统一用 levels 数组声明等级，不再接受 level'
              '（unknownField）',
        ),
      );
    }
    validateRawProgressionLevels(step['levels'], '$stepPath.levels', errors);
    validateRawGrantKinds(step['grants'], '$stepPath.grants', errors);
    checkChoices(step['choices'], '$stepPath.choices');
  }
  return errors.length > before;
}

/// 所有 grants 的 `kind` 必须在 [RuleGrantKind] 枚举内（§3.5、§5.1
/// `unknownGrantKind`），path 精确到出错的 `kind` 字段。
void validateRawGrantKinds(
  Object? raw,
  String path,
  List<ContentValidationError> errors,
) {
  if (raw is! List) return;
  final allowed = RuleGrantKind.values.map((kind) => kind.name).toList();
  for (var index = 0; index < raw.length; index++) {
    final item = raw[index];
    if (item is! Map) continue;
    final kind = item['kind'];
    if (kind is String &&
        RuleGrantKind.values.any((candidate) => candidate.name == kind)) {
      continue;
    }
    final hint = kind == 'resource' ? '，职业资源请改用 classRules.resources' : '';
    errors.add(
      ContentValidationError(
        path: '$path[$index].kind',
        message: '未知 grant kind "$kind"$hint，合法值：${allowed.join(' / ')}'
            '（unknownGrantKind）',
      ),
    );
  }
}

/// `progression[].levels` 的形状（§5.1 `invalidTable`：1..20、非空、不重复）。
void validateRawProgressionLevels(
  Object? raw,
  String path,
  List<ContentValidationError> errors,
) {
  if (raw is! List || raw.isEmpty) {
    errors.add(
      ContentValidationError(
        path: path,
        message: 'progression.levels 必须是非空数组，元素为 1..20 的整数（invalidTable）',
      ),
    );
    return;
  }
  final seen = <int>{};
  for (var index = 0; index < raw.length; index++) {
    final item = raw[index];
    final level = item is num ? item.toInt() : null;
    if (level == null || level < 1 || level > 20) {
      errors.add(
        ContentValidationError(
          path: '$path[$index]',
          message: 'progression 等级必须是 1..20 的整数：$item（invalidTable）',
        ),
      );
    } else if (!seen.add(level)) {
      errors.add(
        ContentValidationError(
          path: '$path[$index]',
          message: 'progression 等级不能重复：$level（invalidTable）',
        ),
      );
    }
  }
}

/// `invalidAutoGrant` 的**唯一产生点**（§5.1，决策 D1）。
///
/// 判据与运行时**同源**：字符串简写能否推断 grants 完全由
/// [RuleChoiceSemantics.autoGrantsFor] 决定（返回 `null` = 无法推断）。调用方
/// 有两处，但都只是"哪个 optionType/选项要走这条路"的入口，判据与错误构造
/// 只有这里一份：
/// - [validateRawChoice]：**条目类型**的字符串元素（决策 D1 的落点）；
/// - [validateRuleReferences] 的 `validateValueChoiceCandidates`：值类型候选
///   **没有显式 grants** 时（例如 `ability` 选项写了非正整数的 `data.value`）。
({List<RuleGrantDefinition>? grants, ContentValidationError? error})
autoGrantsForOption({
  required String optionType,
  required String optionId,
  required Map<String, Object?> data,
  required String path,
}) {
  final grants = RuleChoiceSemantics.autoGrantsFor(
    optionType: optionType,
    optionId: optionId,
    data: data,
  );
  if (grants != null) return (grants: grants, error: null);
  return (
    grants: null,
    error: ContentValidationError(
      path: path,
      message: 'optionType "$optionType" 的选项 "$optionId" 缺少 grants，'
          '且无法自动推断（invalidAutoGrant）',
    ),
  );
}

/// 一条选择的形状/取值校验（§5.1），在**解析之前**对原始 JSON 执行，因此
/// `repeatable` / `group` / `help` / 内联选项 `grants` 一律放行（它们已有真实
/// 运行时语义）；这里只保留"声明了但取值/形状无效"的精确诊断：
/// `unknownField`、`unknownOptionType`、`invalidChoiceRange`、
/// `invalidValueOption`、`duplicateOptionId`、`invalidAutoGrant`、
/// `invalidCountsToward`、`invalidRequires`（形状/取值）。
void validateRawChoice(
  Map<String, Object?> choice,
  String path,
  List<ContentValidationError> errors,
) {
  // §5.1 `unknownField`：字段名拼错（例如 `grup`）在解析期被静默忽略——解析层
  // 只读白名单键。这里在原始 JSON 上按 [kRuleChoiceFields]（选择对象字段全集）
  // 显式报错，path 精确到该键，不静默。
  for (final key in choice.keys) {
    if (kRuleChoiceFields.contains(key)) continue;
    errors.add(
      ContentValidationError(
        path: '$path.$key',
        message: '未知字段 $path.$key（unknownField）',
      ),
    );
  }

  final optionType = choice['optionType'];
  final isValueType = isValueOptionType(optionType);
  if (optionType is! String || !_knownOptionTypes.contains(optionType)) {
    errors.add(
      ContentValidationError(
        path: '$path.optionType',
        message: '未知选项类型 "$optionType"，条目类型见内容 schema，值类型：'
            '${kValueOptionTypes.join(' / ')}（unknownOptionType）',
      ),
    );
  }

  // 畸形输入（`"minimum": "2"` / `{}` / 显式 `null`）不得让这里抛 `_TypeError`：
  // 调用点在解析 `try` 之外，UI 只接 `FormatException`，一次强转就会把导入变成
  // 未捕获异常。改为安全取值 + 精确到字段的诊断。
  final rawMinimum = choice['minimum'];
  final rawMaximum = choice['maximum'];
  if (choice.containsKey('minimum') && rawMinimum is! num) {
    errors.add(
      ContentValidationError(
        path: '$path.minimum',
        message: 'minimum 必须是数字：$rawMinimum（invalidChoiceRange）',
      ),
    );
  }
  if (choice.containsKey('maximum') && rawMaximum is! num) {
    errors.add(
      ContentValidationError(
        path: '$path.maximum',
        message: 'maximum 必须是数字：$rawMaximum（invalidChoiceRange）',
      ),
    );
  }
  final minimum = rawMinimum is num ? rawMinimum.toInt() : 1;
  final maximum = rawMaximum is num ? rawMaximum.toInt() : minimum;
  if (maximum < minimum) {
    errors.add(
      ContentValidationError(
        path: '$path.maximum',
        message: 'maximum 不能小于 minimum（invalidChoiceRange）',
      ),
    );
  } else if (minimum < 0) {
    errors.add(
      ContentValidationError(
        path: '$path.minimum',
        message: 'minimum 不能为负（invalidChoiceRange）',
      ),
    );
  }

  final rawEntryIds = choice['optionEntryIds'];
  final entryIds = rawEntryIds is List
      ? rawEntryIds.map((item) => '$item').toSet()
      : const <String>{};
  final rawTags = choice['optionTags'];
  final tags = rawTags is List
      ? rawTags.map((item) => '$item').toList(growable: false)
      : const <String>[];
  // §5.1 `invalidValueOption` 的两个方向里，这里只实现**值类型侧**：值类型
  // 只允许内联 `options`（§3.10.3-2），写 `optionEntryIds` / `optionTags` 或
  // 干脆没有 `options` 都算"声明了用不了"。
  //
  // **不**把"条目类型选择 `options` 与 `optionEntryIds` 同时为空"一律判错：
  // 条目类型可以靠 `optionTags`（法术选择）或 `relations`（子职选择，见
  // `RuleChoiceResolver._isSubclassOf`）拿候选，契约 §3.10.2 的
  // `equipmentBundle` 示例本身也没有任何候选载体——按字面实现会拒绝内置
  // 包里的 12 条子职选择。
  if (isValueType) {
    if (entryIds.isNotEmpty) {
      errors.add(
        ContentValidationError(
          path: '$path.optionEntryIds',
          message: '值类型选择不允许 optionEntryIds，候选必须写在 options'
              '（invalidValueOption）',
        ),
      );
    }
    if (tags.isNotEmpty) {
      errors.add(
        ContentValidationError(
          path: '$path.optionTags',
          message: '值类型选择不允许 optionTags，候选必须写在 options'
              '（invalidValueOption）',
        ),
      );
    }
    if (choice['options'] == null) {
      errors.add(
        ContentValidationError(
          path: '$path.options',
          message: '值类型选择必须用内联 options 声明候选（invalidValueOption）',
        ),
      );
    }
  }

  final rawOptions = choice['options'];
  if (rawOptions != null) {
    if (rawOptions is! List) {
      errors.add(
        ContentValidationError(
          path: '$path.options',
          message: 'options 必须是数组（invalidValueOption）',
        ),
      );
    } else {
      final seenIds = <String>{};
      for (var index = 0; index < rawOptions.length; index++) {
        final item = rawOptions[index];
        final itemPath = '$path.options[$index]';
        String? id;
        var idPath = itemPath;
        if (item is String) {
          final text = item.trim();
          if (text.isEmpty) {
            errors.add(
              ContentValidationError(
                path: itemPath,
                message: '选项不能为空（invalidValueOption）',
              ),
            );
            continue;
          }
          id = text;
          // §5.1 `invalidAutoGrant`（决策 D1）：**条目类型**的字符串元素没有
          // 可推断的 grants，作者必须写成对象显式给 grants。判据与运行时同源
          // （[RuleChoiceSemantics.autoGrantsFor] 返回 null）；值类型永远能推断
          // （`language` / `damageType` / `weaponMastery` / `value` 返回空列表，
          // 属"只记录选择"，不算无法推断）。
          if (optionType is String) {
            final inferred = autoGrantsForOption(
              optionType: optionType,
              optionId: text,
              data: const <String, Object?>{},
              path: itemPath,
            );
            if (inferred.error != null) errors.add(inferred.error!);
          }
        } else if (item is Map) {
          final option = Map<String, Object?>.from(item);
          final rawId = option['id'];
          idPath = '$itemPath.id';
          if (rawId is! String || rawId.trim().isEmpty) {
            errors.add(
              ContentValidationError(
                path: idPath,
                message: '选项必须有非空 id（invalidValueOption）',
              ),
            );
          } else {
            id = rawId.trim();
          }
          if (option.containsKey('grants')) {
            // §3.10.2 内联选项的 grants 是**真实生效**的授予来源（
            // `RuleChoiceSemantics.grantsForSelection` 展开）；这里只做 kind 枚举
            // 校验，formula/属性键的校验在 `validateGrantFormulas`。
            validateRawGrantKinds(option['grants'], '$itemPath.grants', errors);
          }
        } else {
          errors.add(
            ContentValidationError(
              path: itemPath,
              message: '选项必须是字符串或对象（invalidValueOption）',
            ),
          );
          continue;
        }
        if (id != null) {
          if (!seenIds.add(id)) {
            errors.add(
              ContentValidationError(
                path: idPath,
                message: '选项 id "$id" 重复（duplicateOptionId）',
              ),
            );
          } else if (entryIds.contains(id)) {
            errors.add(
              ContentValidationError(
                path: idPath,
                message: '选项 id "$id" 与 optionEntryIds 冲突'
                    '（duplicateOptionId）',
              ),
            );
          }
        }
      }
    }
  }

  // `countsToward` 的取值校验（§5.1 `invalidCountsToward`）：合法值是具名额度池
  // 或省略。判据的唯一实现点是 [isCountsTowardPool]（解析层同源）。
  final countsToward = choice['countsToward'];
  if (!isCountsTowardPool(countsToward)) {
    errors.add(
      ContentValidationError(
        path: '$path.countsToward',
        message: 'countsToward 必须是 ${kCountsTowardPools.join(' / ')} 或省略'
            '（invalidCountsToward）',
      ),
    );
  }

  // `requires` 的**形状/取值**校验（§5.1 `invalidRequires`）。判据本体是
  // [validateRuleRequiresJson]（解析层 `RuleRequiresDefinition.fromJson` 调用
  // **同一个**纯函数），这里只负责把 `issue.field` 拼成精确 path——两处因此
  // 不可能分叉。`ability` 形态缺 `minimum`、跨形态字段（choice 形态写 minimum /
  // ability 形态写 option）、未知字段都在这里报错，不再降级成解析层的
  // `$.entries[i]` + `invalid entry`。**引用**（`choice` / `option` 是否存在、
  // `ability` 键是否在档案内）在第二遍 [validateRuleReferences] 里校验，那里有
  // 全部条目与 `relations` 祖先链。
  if (choice.containsKey('requires')) {
    final rawRequires = choice['requires'];
    if (rawRequires is! List) {
      errors.add(
        ContentValidationError(
          path: '$path.requires',
          message: 'requires 必须是数组（invalidRequires）',
        ),
      );
    } else {
      for (var index = 0; index < rawRequires.length; index++) {
        final item = rawRequires[index];
        final itemPath = '$path.requires[$index]';
        if (item is! Map) {
          errors.add(
            ContentValidationError(
              path: itemPath,
              message: 'requires 的元素必须是对象（invalidRequires）',
            ),
          );
          continue;
        }
        final issue = validateRuleRequiresJson(
          Map<String, Object?>.from(item),
        );
        if (issue == null) continue;
        final field = issue.field;
        errors.add(
          ContentValidationError(
            path: field == null ? itemPath : '$itemPath.$field',
            message: '${issue.message}（invalidRequires）',
          ),
        );
      }
    }
  }
}

/// `requires` 的**引用/取值语义**校验（§5.1 `invalidRequires`），在解析成功之后
/// 对 [CharacterRuleDefinition] 执行。
///
/// 作用域链的遍历**唯一**走 [RuleChoiceSemantics.scopeEntryIdsFor]（与运行期
/// 同源，导入器不得自己重写一遍 `relations` 遍历）；`option` 的存在性判定 =
/// 该选择的候选集（[RuleChoiceSemantics.candidatesFor]，决策 D3/D5：`option`
/// 指的是**选中值**，内联选项 id 与条目 id 都算）。
void validateRuleReferences(
  String sourceEntryId,
  CharacterRuleDefinition rules,
  Set<String> entryIds,
  Map<String, ContentEntry> entries,
  String path,
  List<ContentValidationError> errors,
) {
  void validateGrants(List<RuleGrantDefinition> grants, String grantsPath) {
    for (var i = 0; i < grants.length; i++) {
      final entryId = grants[i].entryId;
      if (entryId != null && !entryIds.contains(entryId)) {
        errors.add(
          ContentValidationError(
            path: '$grantsPath[$i].entryId',
            message: 'rule entry reference "$entryId" does not exist',
          ),
        );
      }
    }
  }

  // 档案是属性键 / 技能名的**唯一权威**（与运行期 `skills.containsKey` 同源）。
  // `late` 让没有值类型选择、没有 `requires` 的条目完全不付这份代价。
  late final Set<String> abilityKeys = Dnd5eRules.profile.abilities;
  late final Set<String> skillNames = Dnd5eRules.skills
      .map((skill) => skill.name)
      .toSet();

  /// `requires` 的**引用/取值语义**校验（§5.1 `invalidRequires`）。
  ///
  /// 作用域链的遍历**唯一**走 [RuleChoiceSemantics.scopeEntryIdsFor]（与运行期
  /// 同源，导入器不得自己重写一遍 `relations` 遍历）；`option` 的存在性判定 =
  /// 该选择的候选集（[RuleChoiceSemantics.candidatesFor]，决策 D3/D5：`option`
  /// 指的是**选中值**，内联选项 id 与条目 id 都算）。
  void validateRequires(
    List<RuleRequiresDefinition> requires,
    String requiresPath,
  ) {
    for (var index = 0; index < requires.length; index++) {
      final requirement = requires[index];
      final itemPath = '$requiresPath[$index]';
      if (requirement.isAbilityForm) {
        final ability = requirement.ability;
        if (ability != null && !abilityKeys.contains(ability)) {
          errors.add(
            ContentValidationError(
              path: '$itemPath.ability',
              message: 'requires 引用的属性键 "$ability" 不在档案 abilities 内'
                  '（invalidRequires）',
            ),
          );
        }
        continue;
      }
      final choiceId = requirement.choice;
      if (choiceId == null) continue;
      // 作用域内**所有**同 `choiceId` 的定义（不是首个命中）。选择键是
      // `<entryId>#<choiceId>`，运行期 [RuleChoiceSemantics.requiresSatisfied]
      // 经 `_selectedOptions` 把作用域内所有同 choiceId 键的选中值取**并集**；
      // 导入期若只取首个命中，当同一条选择 id 同时出现在条目与其
      // `featureOf` / `subclassOf` 祖先时，祖先定义的合法 option 会被误拒
      // （导入口径比运行期更严 = 假阴性）。
      final definitions =
          <({RuleChoiceDefinition definition, String sourceEntryId})>[];
      for (final scopeId in RuleChoiceSemantics.scopeEntryIdsFor(
        sourceEntryId,
        entries,
      )) {
        final found = RuleChoiceSemantics.definitionForKey(
          '$scopeId#$choiceId',
          entries: entries,
        );
        if (found != null) {
          definitions.add((
            definition: found.definition,
            sourceEntryId: found.sourceEntryId,
          ));
        }
      }
      if (definitions.isEmpty) {
        errors.add(
          ContentValidationError(
            path: '$itemPath.choice',
            message: 'requires 引用的选择 "$choiceId" 不存在于本条目及其祖先'
                '（invalidRequires）',
          ),
        );
        continue;
      }
      final option = requirement.option;
      if (option == null) continue;
      final candidateIds = <String>{
        for (final found in definitions)
          ...RuleChoiceSemantics.candidatesFor(
            found.definition,
            entries: entries,
            sourceEntryId: found.sourceEntryId,
          ).map((candidate) => candidate.id),
      };
      if (!candidateIds.contains(option)) {
        errors.add(
          ContentValidationError(
            path: '$itemPath.option',
            message: 'requires 引用的选项 "$option" 不在选择 "$choiceId" 的候选集内'
                '（invalidRequires）',
          ),
        );
      }
    }
  }

  /// **值类型选择候选校验的唯一实现点**（§5.1 `unknownSkill` /
  /// `unknownAbility` / `invalidSkillCount` / `invalidAutoGrant`）。
  ///
  /// 候选枚举只走 [RuleChoiceSemantics.candidatesFor]，自动授予只走
  /// [RuleChoiceSemantics.autoGrantsFor]——与 UI、引擎同一份判据。这样"导入期
  /// 校验 label、运行期使用 id"的分叉不会再让"声明了但静默无效"通过：运行期
  /// 由自动授予把 `candidate.id` 变成 `skill:<id>` / `ability:<id>`，所以只有
  /// `id` 落在档案 `skills` / `abilities` 内才算真的可用。
  ///
  /// 显式写了 `grants` 的候选不在这里校验（`validateGrantFormulas` 管它们的
  /// formula / 属性键），因为它不经过自动推断路径。
  void validateValueChoiceCandidates(
    RuleChoiceDefinition choice,
    String choicePath,
  ) {
    if (!choice.isValueTypeChoice) return;
    final candidates = RuleChoiceSemantics.candidatesFor(
      choice,
      entries: entries,
      sourceEntryId: sourceEntryId,
    );
    for (final candidate in candidates) {
      final optionIndex = choice.options.indexWhere(
        (option) => option.id == candidate.id,
      );
      if (optionIndex < 0) continue;
      final optionPath = '$choicePath.options[$optionIndex]';
      if (candidate.grants.isNotEmpty) continue;
      final inferred = autoGrantsForOption(
        optionType: choice.optionType,
        optionId: candidate.id,
        data: candidate.data,
        path: optionPath,
      );
      if (inferred.error != null) {
        errors.add(inferred.error!);
        continue;
      }
      for (final grant in inferred.grants!) {
        final target = grant.target;
        if (target == null) continue;
        if (grant.kind == RuleGrantKind.proficiency &&
            target.startsWith('skill:') &&
            !skillNames.contains(target.substring('skill:'.length))) {
          errors.add(
            ContentValidationError(
              path: optionPath,
              message: '未知技能 "${candidate.id}"（unknownSkill）',
            ),
          );
        } else if (grant.kind == RuleGrantKind.ability &&
            !abilityKeys.contains(target)) {
          errors.add(
            ContentValidationError(
              path: optionPath,
              message: '未知属性键 "${candidate.id}"，可用：'
                  '${abilityKeys.join(', ')}（unknownAbility）',
            ),
          );
        }
      }
    }
    if (choice.optionType == RuleChoiceDefinition.skillOptionType) {
      final candidateCount = candidates.length;
      if (choice.minimum > candidateCount) {
        errors.add(
          ContentValidationError(
            path: '$choicePath.minimum',
            message: '技能选择的数量必须为 0..$candidateCount（invalidSkillCount）',
          ),
        );
      }
      if (choice.maximum > candidateCount) {
        errors.add(
          ContentValidationError(
            path: '$choicePath.maximum',
            message: '技能选择的数量必须为 0..$candidateCount（invalidSkillCount）',
          ),
        );
      }
    }
  }

  void validateChoices(
    List<RuleChoiceDefinition> choices,
    String choicesPath,
  ) {
    final resolver = RuleChoiceResolver(entries: entries);
    for (var i = 0; i < choices.length; i++) {
      for (var j = 0; j < choices[i].optionEntryIds.length; j++) {
        final entryId = choices[i].optionEntryIds[j];
        if (!entryIds.contains(entryId)) {
          errors.add(
            ContentValidationError(
              path: '$choicesPath[$i].optionEntryIds[$j]',
              message: 'rule choice option "$entryId" does not exist'
                  '（invalidOptionRef）',
            ),
          );
        } else if (!resolver.allows(
          choices[i],
          entryId,
          sourceEntryId: sourceEntryId,
        )) {
          errors.add(
            ContentValidationError(
              path: '$choicesPath[$i].optionEntryIds[$j]',
              message: 'rule choice option "$entryId" does not satisfy its type, '
                  'tag, or level filters（invalidOptionRef）',
            ),
          );
        }
      }
      for (var j = 0; j < choices[i].recommendedEntryIds.length; j++) {
        final entryId = choices[i].recommendedEntryIds[j];
        if (!entryIds.contains(entryId)) {
          errors.add(
            ContentValidationError(
              path: '$choicesPath[$i].recommendedEntryIds[$j]',
              message: 'recommended rule choice "$entryId" does not exist'
                  '（invalidOptionRef）',
            ),
          );
        } else if (!resolver.allows(
          choices[i],
          entryId,
          sourceEntryId: sourceEntryId,
        )) {
          errors.add(
            ContentValidationError(
              path: '$choicesPath[$i].recommendedEntryIds[$j]',
              message: 'recommended rule choice "$entryId" does not satisfy its '
                  'type, tag, or level filters（invalidOptionRef）',
            ),
          );
        }
      }
      // §3.10 选择系统的取值/引用语义：值类型候选（skill / ability / …）与
      // `requires` 的引用，一律在这里按**解析后的定义**校验（值类型候选的
      // 唯一口径是解析层导出的 `RuleChoiceSemantics.candidatesFor`）。
      validateValueChoiceCandidates(choices[i], '$choicesPath[$i]');
      validateRequires(choices[i].requires, '$choicesPath[$i].requires');
      for (var j = 0; j < choices[i].options.length; j++) {
        validateRequires(
          choices[i].options[j].requires,
          '$choicesPath[$i].options[$j].requires',
        );
      }
    }
  }

  validateGrants(rules.grants, '$path.grants');
  validateChoices(rules.choices, '$path.choices');
  for (var i = 0; i < rules.progression.length; i++) {
    final step = rules.progression[i];
    validateGrants(step.grants, '$path.progression[$i].grants');
    validateChoices(step.choices, '$path.progression[$i].choices');
  }
}
