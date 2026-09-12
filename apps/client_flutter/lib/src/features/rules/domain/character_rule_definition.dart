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

/// `rules.choices[].options` 的内联选项（契约 §3.10.2）。
///
/// 字符串简写 `"察觉"` 等价于 `{id: "察觉", label: "察觉"}`（见
/// [_parseChoiceOptions]）；对象形态可另带 `description` / `data` / `grants`。
/// 字符串元素按 `optionType` 自动补 grants 属于**选择系统**的行为（计划 2），
/// 不在解析层推断。
class RuleChoiceOption {
  const RuleChoiceOption({
    required this.id,
    required this.label,
    this.description,
    this.data = const <String, Object?>{},
    this.grants = const <RuleGrantDefinition>[],
  });

  final String id;
  final String label;
  final String? description;
  final Map<String, Object?> data;
  final List<RuleGrantDefinition> grants;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    if (description != null) 'description': description,
    if (data.isNotEmpty) 'data': data,
    if (grants.isNotEmpty)
      'grants': grants.map((grant) => grant.toJson()).toList(),
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
/// 本轮只承载**形状与参照**：`repeatable` / `countsToward` / `requires` /
/// `group` / `help` 以及内联选项的 `grants` 的选择系统语义明确延后到计划 2，
/// 解析层不把它们变成"看似生效"的字段；导入期由
/// `ContentPackageImporter._validateRawEntryRules` 对原始 JSON 一律报 error
/// 拒收（§3.10.3-7：声明了但运行期用不了必须报错）。**计划 2 落地后，这些字段
/// 改为在此解析并实现，而不是继续拒绝**。
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
  final String? builderStep;

  /// 该选择是否由**通用条目选项卡片之外**的 UI 承担。
  ///
  /// 判据（唯一实现点）：只有当内联 `options` 是**唯一候选载体**时才成立。
  /// - 值类型（[kValueOptionTypes]）只允许内联 `options`（§3.10.3-2），由专门 UI
  ///   （技能选择器等）承担；
  /// - 条目类型选择写内联 `options` 时，只要还声明了 `optionEntryIds` 或
  ///   `optionTags`（§3.10.3-2 明确允许"条目引用 + 内联 `options`"并存），通用卡片
  ///   就能按条目引用/标签解析出候选，必须继续走通用卡片。把它们整条排除会同时
  ///   从渲染、`ruleChoicesAreValid`、`pendingChoices` 里消失：候选不可见、不选也
  ///   能创建（§3.10.3-7 的静默失效）。
  ///
  /// 通用卡片只解析**条目引用**（`RuleChoiceResolver.optionsFor` 按条目 id/标签
  /// 匹配），内联选项对它完全不可见，只有内联选项时渲染出来就是"资料库中缺少 X
  /// 选项"的假错误。选择系统的完整语义（含内联选项的合并展示）延后到计划 2；
  /// 在此之前只有"内联选项是唯一候选载体"的选择不进通用卡片。
  bool get usesDedicatedOptionUi =>
      isValueTypeChoice ||
      (options.isNotEmpty && optionEntryIds.isEmpty && optionTags.isEmpty);

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
        );
      })
      .toList(growable: false);
}
