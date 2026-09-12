enum RuleGrantKind {
  feature,
  proficiency,
  spell,
  equipment,
  action,
  speed,
  armorClass,
  hitPoints,
  ability;

  static RuleGrantKind parse(String value) {
    return RuleGrantKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => throw FormatException('Unknown rule grant kind: $value'),
    );
  }
}

/// `value` 与 `formula` **二选一**的判据（契约 §3.5）：只有 `hitPoints` /
/// `ability` 两种授予在同一份定义里同时声明两者才是非法——其它 kind 的
/// `formula` 语义不同（如伤害骰），不受这条约束。
///
/// 这是该判据的**唯一实现点**：[RuleGrantDefinition.fromJson] 用它抛
/// [FormatException]，`ContentPackageImporter` 也用它（连同
/// [ruleGrantValueAndFormulaPath]）把同一份输入报成带精确 path 的整包 error。
/// 两处不得各写一份判据，否则"解析拒绝、导入放行"会再次分叉。
bool rejectsValueAndFormula(
  RuleGrantKind kind, {
  required Object? value,
  required Object? formula,
}) {
  return (kind == RuleGrantKind.hitPoints || kind == RuleGrantKind.ability) &&
      value != null &&
      formula != null;
}

/// 在条目原始 JSON 里定位第一处 `value` + `formula` 同时声明，返回精确到
/// `<rulesPath>[.progression[i].grants[j]]` 的路径；没有则返回 null。
///
/// 导入器需要这个路径，是因为解析层只能抛一条没有位置的 [FormatException]，
/// 而契约要求 error 的 path 精确到 `[i].formula`。判据仍只有
/// [rejectsValueAndFormula] 一份。
String? ruleGrantValueAndFormulaPath(
  Map<String, Object?> rulesJson,
  String rulesPath,
) {
  String? checkList(Object? raw, String path) {
    if (raw is! List) return null;
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) continue;
      final map = Map<String, Object?>.from(item);
      final kindValue = map['kind'];
      // 只比对两个受约束 kind 的字面名：非法 kind 由解析层用另一条 error 报出，
      // 这里不需要（也不应该）先解析再吞掉它的失败。
      if ((kindValue == 'hitPoints' || kindValue == 'ability') &&
          rejectsValueAndFormula(
            kindValue == 'ability'
                ? RuleGrantKind.ability
                : RuleGrantKind.hitPoints,
            value: map['value'],
            formula: map['formula'],
          )) {
        return '$path[$i].formula';
      }
      // 内联选项里的 grants 也带同一种定义（§3.10.2）。
      final options = map['options'];
      if (options is List) {
        for (var j = 0; j < options.length; j++) {
          final option = options[j];
          if (option is! Map) continue;
          final nested = checkList(
            option['grants'],
            '$path[$i].options[$j].grants',
          );
          if (nested != null) return nested;
        }
      }
    }
    return null;
  }

  final topLevel = checkList(rulesJson['grants'], '$rulesPath.grants');
  if (topLevel != null) return topLevel;
  final choices = checkList(rulesJson['choices'], '$rulesPath.choices');
  if (choices != null) return choices;
  final progression = rulesJson['progression'];
  if (progression is List) {
    for (var i = 0; i < progression.length; i++) {
      final step = progression[i];
      if (step is! Map) continue;
      final grants = checkList(
        step['grants'],
        '$rulesPath.progression[$i].grants',
      );
      if (grants != null) return grants;
      final stepChoices = checkList(
        step['choices'],
        '$rulesPath.progression[$i].choices',
      );
      if (stepChoices != null) return stepChoices;
    }
  }
  return null;
}

class RuleGrantDefinition {
  const RuleGrantDefinition({
    required this.id,
    required this.kind,
    required this.label,
    this.target,
    this.entryId,
    this.value,
    this.formula,
    this.data = const <String, Object?>{},
  });

  final String id;
  final RuleGrantKind kind;
  final String label;
  final String? target;
  final String? entryId;
  final num? value;
  final String? formula;
  final Map<String, Object?> data;

  factory RuleGrantDefinition.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final kind = json['kind'];
    if (id is! String || id.trim().isEmpty || kind is! String) {
      throw const FormatException('Rule grant requires id and kind');
    }
    final parsedKind = RuleGrantKind.parse(kind);
    final value = json['value'];
    final formula = json['formula'];
    // §3.5：`hitPoints` / `ability` 的 `value` 与 `formula` 是**二选一**。
    // 解析层直接拒绝，而不是留给运行期把两者相加：内置档案、程序化构造和
    // 导入路径都必须受同一条约束，否则"到底按哪个结算"会退化成运行期猜测。
    if (rejectsValueAndFormula(parsedKind, value: value, formula: formula)) {
      throw FormatException(
        'Rule grant "$id"（kind: ${parsedKind.name}）的 value 与 formula '
        '只能二选一，不能同时声明（invalidMaxSpec）',
      );
    }
    return RuleGrantDefinition(
      id: id,
      kind: parsedKind,
      label: json['label'] as String? ?? id,
      target: json['target'] as String?,
      entryId: json['entryId'] as String?,
      value: value as num?,
      formula: formula as String?,
      data: json['data'] is Map
          ? Map<String, Object?>.from(json['data'] as Map)
          : const <String, Object?>{},
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'label': label,
    if (target != null) 'target': target,
    if (entryId != null) 'entryId': entryId,
    if (value != null) 'value': value,
    if (formula != null) 'formula': formula,
    if (data.isNotEmpty) 'data': data,
  };
}

/// `countsToward` 的合法取值（契约 §3.10.2 表）。
///
/// 这是取值集合的**唯一实现点**：解析层用它抛 [FormatException]。导入期据它报
/// 精确到字段的 `invalidCountsToward` 属于**计划任务 10 接线**；接线前导入器仍对
/// `countsToward` 一律拒收，也不引用本集合。两处不得各写一份白名单。
const kCountsTowardPools = <String>{'spellbook', 'known', 'prepared'};

/// `null`（省略 = 不占上限）与三个池名合法；其它（含非字符串）非法。
bool isCountsTowardPool(Object? value) =>
    value == null || (value is String && kCountsTowardPools.contains(value));

/// 字符串简写**能推断** grants 的 `optionType`（契约 §3.10.2 的自动授予表）。
/// `skill` / `ability` 产出 grants；`language` / `damageType` / `weaponMastery` /
/// `value` 只记录选择（产出空 grants，不算"无法推断"）。
///
/// `RuleChoiceSemantics.autoGrantsFor` 的 `switch` 与它必须一一对应：运行期由
/// `autoGrantsFor` 真正产出。导入期据它判断"字符串简写能否推断 grants"（不能则报
/// `invalidAutoGrant`）属于**计划任务 10 接线**，接线前导入器不引用本集合。
/// 两处用同一个集合，避免"导入放行、运行期推断不出"。
const kAutoGrantOptionTypes = <String>{
  'skill',
  'ability',
  'language',
  'damageType',
  'weaponMastery',
  'value',
};

/// 一条前置依赖（契约 §3.10.2）：`{choice, option?}` 或 `{ability, minimum}`。
///
/// **形状的唯一入口**是 [RuleRequiresDefinition.fromJson]：两种形态混写、字段
/// 缺失、**按形态收紧白名单后的多余字段**（含另一形态的字段）、取值非法一律抛
/// [FormatException]，绝不静默丢弃或留给运行期猜测。const 构造器带 assert，
/// debug 下同样拒绝这些非法形状。本批次（计划 2 任务 1–2）只解析与提供判定纯
/// 函数；引擎/UI 的消费在任务 3–6。
class RuleRequiresDefinition {
  const RuleRequiresDefinition({
    this.choice,
    this.option,
    this.ability,
    this.minimum,
  }) : assert(
         (choice != null) != (ability != null),
         'requires 必须是 {choice, option?} 或 {ability, minimum} 之一',
       ),
       assert(
         ability == null || (minimum != null && minimum > 0),
         'requires 的 ability 形态必须带正整数 minimum',
       ),
       assert(
         choice == null || minimum == null,
         'requires 的 choice 形态不允许 minimum',
       ),
       assert(
         choice != null || option == null,
         'requires 的 ability 形态不允许 option',
       );

  final String? choice;
  final String? option;
  final String? ability;
  final int? minimum;

  bool get isChoiceForm => choice != null;
  bool get isAbilityForm => ability != null;

  factory RuleRequiresDefinition.fromJson(Map<String, Object?> json) {
    final choice = json['choice'];
    final option = json['option'];
    final ability = json['ability'];
    final minimum = json['minimum'];
    final hasChoice = choice != null;
    final hasAbility = ability != null;
    if (hasChoice == hasAbility) {
      throw const FormatException(
        'requires 必须是 {choice, option?} 或 {ability, minimum} 之一',
      );
    }
    // XOR 判定出形态后按形态收紧字段白名单：未知字段与另一形态的字段在此都是
    // 多余字段，一律抛 FormatException（§3.10.3-7「声明了但无效必须报错」），
    // 绝不静默丢弃 —— 静默丢弃会让 toJson 往返丢字段，也让下游把脏输入当可信。
    final allowed = hasChoice
        ? const <String>{'choice', 'option'}
        : const <String>{'ability', 'minimum'};
    final extra = json.keys.where((key) => !allowed.contains(key)).toList();
    if (extra.isNotEmpty) {
      throw FormatException('requires 出现未定义或形态不允许的字段：$extra');
    }
    if (hasChoice) {
      if (choice is! String || choice.trim().isEmpty) {
        throw const FormatException('requires.choice 必须是非空字符串');
      }
      if (option != null && (option is! String || option.trim().isEmpty)) {
        throw const FormatException('requires.option 必须是非空字符串');
      }
      return RuleRequiresDefinition(
        choice: choice.trim(),
        option: option is String ? option.trim() : null,
      );
    }
    if (ability is! String || ability.trim().isEmpty) {
      throw const FormatException('requires.ability 必须是非空字符串');
    }
    if (minimum is! num || minimum.toInt() <= 0) {
      throw const FormatException('requires.minimum 必须是正整数');
    }
    return RuleRequiresDefinition(
      ability: ability.trim(),
      minimum: minimum.toInt(),
    );
  }

  Map<String, Object?> toJson() => isChoiceForm
      ? {'choice': choice, if (option != null) 'option': option}
      : {'ability': ability, 'minimum': minimum};
}

/// `rules.choices[].options` 的内联选项（契约 §3.10.2）。
///
/// 字符串简写 `"察觉"` 等价于 `{id: "察觉", label: "察觉"}`（见
/// [_parseChoiceOptions]）；对象形态可另带 `description` / `data` / `grants` /
/// `requires`。字符串元素按 `optionType` 自动补 grants 属于**选择系统**的行为
/// （计划 2），不在解析层推断。
class RuleChoiceOption {
  const RuleChoiceOption({
    required this.id,
    required this.label,
    this.description,
    this.data = const <String, Object?>{},
    this.grants = const <RuleGrantDefinition>[],
    this.requires = const <RuleRequiresDefinition>[],
  });

  final String id;
  final String label;
  final String? description;
  final Map<String, Object?> data;
  final List<RuleGrantDefinition> grants;

  /// 该选项自身的前置依赖（决策 D6，契约 §3.10.2"隐藏该选择**或选项**"）。
  ///
  /// 本批次（计划 2 任务 1–2）只解析；判定走
  /// `RuleChoiceSemantics.candidateRequiresSatisfied`，UI 隐藏的消费在后续任务。
  final List<RuleRequiresDefinition> requires;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    if (description != null) 'description': description,
    if (data.isNotEmpty) 'data': data,
    if (grants.isNotEmpty)
      'grants': grants.map((grant) => grant.toJson()).toList(),
    if (requires.isNotEmpty)
      'requires': requires.map((requirement) => requirement.toJson()).toList(),
  };
}

/// **值类型**的 `optionType`（契约 §3.10.2）。另一半是"条目类型"
/// （`subclass` / `feat` / `spell` / `item` / `classFeature` / …，见内容 schema）。
///
/// 这是"值类型 vs 条目类型"判据的**唯一实现点**：导入期校验（值类型不得带
/// `optionEntryIds` / `optionTags`）与展示层（专门的技能选择器 vs 通用条目选项
/// 卡片）都必须读它，不得各自写一份中文字符串列表。
const kValueOptionTypes = <String>{
  'value',
  'skill',
  'ability',
  'language',
  'damageType',
  'weaponMastery',
};

/// 一个（可能是原始 JSON 值的）`optionType` 是否为**值类型**。
///
/// 这是该判据的**唯一实现点**：[RuleChoiceDefinition.isValueTypeChoice] 与导入器
/// 在原始 JSON 上的校验都调它，避免"解析后的对象"与"原始 map"两套写法分叉。
bool isValueOptionType(Object? optionType) =>
    optionType is String && kValueOptionTypes.contains(optionType);

/// `rules.choices[]` / `rules.progression[].choices[]` 的一条选择（契约 §3.10）。
///
/// 本类只把这些字段**解析成形状**并提供判定纯函数；运行期与 UI 的消费在
/// `RuleChoiceSemantics` / 创建向导 / 升级面（导入期放行见 §5.1）。
class RuleChoiceDefinition {
  static const allowedBuilderSteps = {
    'class',
    'origin',
    'abilities',
    'proficiencies',
    'equipment',
    'spells',
    'details',
  };

  /// `optionType: "skill"`：值类型选择，由「熟练」步骤的技能网格渲染。
  static const skillOptionType = 'skill';

  /// `optionType: "spell"`：由「法术」步骤的法术池渲染。
  static const spellOptionType = 'spell';

  /// 专用渲染器承担的 `optionType` → 创建向导步骤索引。
  ///
  /// **唯一实现点**：`skill` → 「熟练」步骤（4），`spell` → 「法术」步骤（6）。
  /// 专用 UI 选择的界面位置**只由 `optionType` 决定**（契约 §3.10.2）：声明里的
  /// `builderStep` 对它们只是提示并被**忽略**，写什么值（或干脆省略）都不改变
  /// 位置，也不会变成"第二种语义"。
  ///
  /// 位置一旦被 `builderStep` 改写，PHB 私有包的 `phb-2024:class/fighter` 技能选择
  /// （`optionType: "skill"` 且**不带** `builderStep`）就会落到步骤 0：通用卡片因
  /// [usesDedicatedOptionUi] 排除它、专用渲染器又按 4/6 过滤 → 哪里都不渲染却仍然
  /// 阻塞创建（"看不见却阻塞创建"的死锁，决策 D7 的同类缺陷）。
  static const dedicatedOptionSteps = <String, int>{
    skillOptionType: 4,
    spellOptionType: 6,
  };

  const RuleChoiceDefinition({
    required this.id,
    required this.label,
    required this.optionType,
    required this.minimum,
    required this.maximum,
    this.optionEntryIds = const <String>[],
    this.optionTags = const <String>[],
    this.options = const <RuleChoiceOption>[],
    this.maximumOptionLevel,
    this.recommendedEntryIds = const <String>[],
    this.builderStep,
    this.repeatable = false,
    this.countsToward,
    this.requires = const <RuleRequiresDefinition>[],
    this.group,
    this.help,
  });

  final String id;
  final String label;
  final String optionType;
  final int minimum;
  final int maximum;
  final List<String> optionEntryIds;
  final List<String> optionTags;

  /// 内联选项（契约 §3.10.2）：候选值直接写在条目里，不引用其它条目。
  final List<RuleChoiceOption> options;

  final int? maximumOptionLevel;
  final List<String> recommendedEntryIds;

  /// 创建向导里的步骤提示（[allowedBuilderSteps]）。
  ///
  /// 对**专用 UI 选择**（`optionType` ∈ [dedicatedOptionSteps]）**不参与**位置计算：
  /// 那是 [dedicatedOptionStep] 的职责，这里写的值被忽略（只是作者意图的提示）。
  /// 其余选择的位置由 `ruleChoiceBuilderStep` 映射到这里声明的名字。
  final String? builderStep;

  /// 同一选项是否可重复选取（契约 §3.10.2）。`true` 时 [maximum] 是**次数上限**。
  ///
  /// 消费：选中值规范化（`RuleChoiceSemantics.normalizeSelection`）、生效单元序号
  /// （`RuleChoiceGrantKey` 的 occurrence）、共享组件的"加一次 / 减一次"交互。
  final bool repeatable;

  /// 计入哪个数量池（契约 §3.10.2；合法值见 [kCountsTowardPools]）。
  ///
  /// `null` = 不占池，只受 [maximum] 约束。额度计算的唯一实现点是
  /// `RuleChoiceQuota.effectiveMaximum`。
  final String? countsToward;

  /// 该选择的前置依赖（契约 §3.10.2）。空列表 = 无前置。
  ///
  /// 判定纯函数是 `RuleChoiceSemantics.requiresSatisfied`（唯一实现点），引擎与
  /// 三处选择界面都调它；呈现层的原因文案由 `ruleChoiceBlockedReason` 一处产出。
  final List<RuleRequiresDefinition> requires;

  /// 选择面板里的分组标题（契约 §3.10.2）。`null` = 不分组。
  ///
  /// 归组的唯一实现点是 `groupRuleChoiceSections`（按首次声明顺序，无 group 的
  /// 排最后）；创建向导、编辑器升级队列与独立升级页三处都调它。
  final String? group;

  /// 选择面板里的帮助小字（契约 §3.10.2）。`null` = 无帮助文案。
  ///
  /// 由共享组件 `RuleChoiceSection` 与法术池渲染成标题下的小字。
  final String? help;

  /// 该选择是否由**专门渲染器**承担，因此不出现在通用选择卡片里。
  ///
  /// 判据（唯一实现点）：[dedicatedOptionSteps] 是否含 [optionType]——`skill` 由
  /// 创建向导「熟练」步骤的技能网格承担，`spell` 由「法术」步骤的法术池承担。
  ///
  /// 这是**渲染判据**，不是"免检"判据：候选合并
  /// （`RuleChoiceSemantics.candidatesFor`）让内联 `options` 与条目候选对通用卡片
  /// 同样可见后，选中值一律进 `build.choices`，校验 / 额度 / 升级判定都按普通选择
  /// 处理，不再有"值写在别处所以免检"的例外。
  ///
  /// **只决定"由谁画"，不决定"画在哪个步骤"**：步骤归 [dedicatedOptionStep]。
  bool get usesDedicatedOptionUi => dedicatedOptionStep != null;

  /// 该选择在创建向导里由专用渲染器认领的步骤（[dedicatedOptionSteps]）。
  ///
  /// `null` = 非专用选择，位置按 [builderStep] 走（`ruleChoiceBuilderStep`）。
  int? get dedicatedOptionStep => dedicatedOptionSteps[optionType];

  /// 技能值类型选择：由「熟练」步骤的技能网格渲染（[dedicatedOptionStep] == 4）。
  bool get isSkillChoice => optionType == skillOptionType;

  /// 显式法术选择（契约 §3.10.2）：由法术池渲染，候选经
  /// `RuleChoiceSemantics.candidatesFor`（`maximumOptionLevel` / `optionTags`），
  /// 上限经 `RuleChoiceQuota.effectiveMaximum`。
  bool get isSpellChoice => optionType == spellOptionType;

  /// 值类型选择的判据入口（实现点在 [isValueOptionType]）。
  bool get isValueTypeChoice => isValueOptionType(optionType);

  factory RuleChoiceDefinition.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final optionType = json['optionType'];
    final minimum = (json['minimum'] as num?)?.toInt() ?? 1;
    final maximum = (json['maximum'] as num?)?.toInt() ?? minimum;
    if (id is! String || id.trim().isEmpty || optionType is! String) {
      throw const FormatException('Rule choice requires id and optionType');
    }
    if (minimum < 0 || maximum < minimum) {
      throw FormatException('Invalid rule choice range: $minimum..$maximum');
    }
    final options = json['optionEntryIds'];
    final optionTags = json['optionTags'];
    final inlineOptions = json['options'];
    final recommended = json['recommendedEntryIds'];
    final maximumOptionLevel = (json['maximumOptionLevel'] as num?)?.toInt();
    final builderStep = json['builderStep'] as String?;
    if (maximumOptionLevel != null &&
        (maximumOptionLevel < 0 || maximumOptionLevel > 9)) {
      throw FormatException(
        'maximumOptionLevel must be between 0 and 9: $maximumOptionLevel',
      );
    }
    if (builderStep != null && builderStep.trim().isEmpty) {
      throw const FormatException('builderStep must not be empty');
    }
    if (builderStep != null && !allowedBuilderSteps.contains(builderStep)) {
      throw FormatException('Unknown builderStep: $builderStep');
    }
    final repeatable = json['repeatable'];
    if (repeatable != null && repeatable is! bool) {
      throw const FormatException('choice.repeatable must be a boolean');
    }
    final countsToward = json['countsToward'];
    if (!isCountsTowardPool(countsToward)) {
      throw FormatException(
        'countsToward 必须是 ${kCountsTowardPools.join(' / ')} 或省略：$countsToward',
      );
    }
    String? nonEmptyText(Object? raw, String field) {
      if (raw == null) return null;
      if (raw is! String || raw.trim().isEmpty) {
        throw FormatException('choice.$field must be a non-empty string');
      }
      return raw;
    }

    return RuleChoiceDefinition(
      id: id,
      label: json['label'] as String? ?? id,
      optionType: optionType,
      minimum: minimum,
      maximum: maximum,
      optionEntryIds: options is List
          ? options.map((item) => '$item').toList(growable: false)
          : const <String>[],
      optionTags: optionTags is List
          ? optionTags.map((item) => '$item').toList(growable: false)
          : const <String>[],
      options: _parseChoiceOptions(inlineOptions),
      maximumOptionLevel: maximumOptionLevel,
      recommendedEntryIds: recommended is List
          ? recommended.map((item) => '$item').toList(growable: false)
          : const <String>[],
      builderStep: builderStep,
      repeatable: repeatable as bool? ?? false,
      countsToward: countsToward as String?,
      requires: _parseRequires(json['requires'], 'choice.requires'),
      group: nonEmptyText(json['group'], 'group'),
      help: nonEmptyText(json['help'], 'help'),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'optionType': optionType,
    'minimum': minimum,
    'maximum': maximum,
    if (optionEntryIds.isNotEmpty) 'optionEntryIds': optionEntryIds,
    if (optionTags.isNotEmpty) 'optionTags': optionTags,
    if (options.isNotEmpty)
      'options': options.map((option) => option.toJson()).toList(),
    if (maximumOptionLevel != null) 'maximumOptionLevel': maximumOptionLevel,
    if (recommendedEntryIds.isNotEmpty)
      'recommendedEntryIds': recommendedEntryIds,
    if (builderStep != null) 'builderStep': builderStep,
    if (repeatable) 'repeatable': repeatable,
    if (countsToward != null) 'countsToward': countsToward,
    if (requires.isNotEmpty)
      'requires': requires.map((requirement) => requirement.toJson()).toList(),
    if (group != null) 'group': group,
    if (help != null) 'help': help,
  };
}

class RuleProgressionDefinition {
  const RuleProgressionDefinition({
    required this.levels,
    this.grants = const <RuleGrantDefinition>[],
    this.choices = const <RuleChoiceDefinition>[],
  });

  /// 该步生效的角色等级（1..20）。一个步骤可以一次覆盖多个等级；
  /// 至少一项、无重复、按升序排列（[fromJson] 规范化后保证）。
  final List<int> levels;
  final List<RuleGrantDefinition> grants;
  final List<RuleChoiceDefinition> choices;

  factory RuleProgressionDefinition.fromJson(Map<String, Object?> json) {
    if (json.containsKey('level')) {
      throw const FormatException(
        'Rule progression requires "levels": [..]，不再接受 "level"',
      );
    }
    final raw = json['levels'];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException(
        'Rule progression requires a non-empty "levels" array',
      );
    }
    final levels = <int>[];
    for (final item in raw) {
      if (item is! num) {
        throw FormatException('Rule progression level must be 1..20: $item');
      }
      final level = item.toInt();
      if (level < 1 || level > 20) {
        throw FormatException('Rule progression level must be 1..20: $level');
      }
      if (levels.contains(level)) {
        throw FormatException('Rule progression levels must be unique: $level');
      }
      levels.add(level);
    }
    levels.sort();
    return RuleProgressionDefinition(
      levels: List<int>.unmodifiable(levels),
      grants: _parseList(json['grants'], RuleGrantDefinition.fromJson),
      choices: _parseList(json['choices'], RuleChoiceDefinition.fromJson),
    );
  }

  Map<String, Object?> toJson() => {
    'levels': levels,
    if (grants.isNotEmpty)
      'grants': grants.map((grant) => grant.toJson()).toList(),
    if (choices.isNotEmpty)
      'choices': choices.map((choice) => choice.toJson()).toList(),
  };
}

class CharacterRuleDefinition {
  const CharacterRuleDefinition({
    this.grants = const <RuleGrantDefinition>[],
    this.choices = const <RuleChoiceDefinition>[],
    this.progression = const <RuleProgressionDefinition>[],
  });

  final List<RuleGrantDefinition> grants;
  final List<RuleChoiceDefinition> choices;
  final List<RuleProgressionDefinition> progression;

  /// 条目自身是否声明了 [optionType] 类型的选择（契约 §3.10）：
  /// `rules.choices` ∪ `rules.progression[].choices`，**与等级无关**——导入期校验
  /// 看的是"作者声明过这种选择吗"，不是"当前角色够不够等级"。
  ///
  /// 这是"条目里有没有这类选择"的**唯一遍历点**：两层列表的遍历顺序与存在性判断
  /// 只在这里写一次，调用方不得各自重写。
  bool declaresChoiceOfType(String optionType) {
    for (final choice in choices) {
      if (choice.optionType == optionType) return true;
    }
    for (final step in progression) {
      for (final choice in step.choices) {
        if (choice.optionType == optionType) return true;
      }
    }
    return false;
  }

  factory CharacterRuleDefinition.fromJson(Map<String, Object?> json) {
    return CharacterRuleDefinition(
      grants: _parseList(json['grants'], RuleGrantDefinition.fromJson),
      choices: _parseList(json['choices'], RuleChoiceDefinition.fromJson),
      progression: _parseList(
        json['progression'],
        RuleProgressionDefinition.fromJson,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    if (grants.isNotEmpty)
      'grants': grants.map((grant) => grant.toJson()).toList(),
    if (choices.isNotEmpty)
      'choices': choices.map((choice) => choice.toJson()).toList(),
    if (progression.isNotEmpty)
      'progression': progression.map((step) => step.toJson()).toList(),
  };
}

List<T> _parseList<T>(
  Object? value,
  T Function(Map<String, Object?> json) parser,
) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('Rule field must be a list');
  return value
      .map((item) {
        if (item is! Map) {
          throw const FormatException('Rule list item must be an object');
        }
        return parser(Map<String, Object?>.from(item));
      })
      .toList(growable: false);
}

/// 内联选项的两态解析（契约 §3.10.2）：字符串简写 `"察觉"` 等价于
/// `{id: "察觉", label: "察觉"}`；对象形态要求非空 `id`，`label` 缺省等于 `id`。
/// 形状非法一律 fail-fast（与 [RuleChoiceDefinition.fromJson] 其余字段一致），
/// 不静默丢选项。
List<RuleChoiceOption> _parseChoiceOptions(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Rule choice options must be a list');
  }
  return value
      .map((item) {
        if (item is String) {
          final text = item.trim();
          if (text.isEmpty) {
            throw const FormatException('Rule choice option must not be empty');
          }
          return RuleChoiceOption(id: text, label: text);
        }
        if (item is! Map) {
          throw const FormatException(
            'Rule choice option must be a string or an object',
          );
        }
        final json = Map<String, Object?>.from(item);
        final id = json['id'];
        if (id is! String || id.trim().isEmpty) {
          throw const FormatException(
            'Rule choice option requires a non-empty id',
          );
        }
        final label = json['label'];
        final grants = json['grants'];
        return RuleChoiceOption(
          id: id,
          label: label is String && label.trim().isNotEmpty ? label : id,
          description: json['description'] as String?,
          data: json['data'] is Map
              ? Map<String, Object?>.from(json['data'] as Map)
              : const <String, Object?>{},
          grants: grants is List
              ? _parseList(grants, RuleGrantDefinition.fromJson)
              : const <RuleGrantDefinition>[],
          requires: _parseRequires(
            json['requires'],
            'choice.options[].requires',
          ),
        );
      })
      .toList(growable: false);
}

/// `requires` 数组的唯一形状入口（[RuleRequiresDefinition.fromJson] 的批量包装）：
/// 非列表、元素非对象、元素形状非法一律抛 [FormatException]。
List<RuleRequiresDefinition> _parseRequires(Object? value, String path) {
  if (value == null) return const <RuleRequiresDefinition>[];
  if (value is! List) {
    throw FormatException('$path must be a list');
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw FormatException('$path item must be an object');
        }
        return RuleRequiresDefinition.fromJson(
          Map<String, Object?>.from(item),
        );
      })
      .toList(growable: false);
}
