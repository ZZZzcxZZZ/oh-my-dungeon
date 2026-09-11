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
    return RuleGrantDefinition(
      id: id,
      kind: RuleGrantKind.parse(kind),
      label: json['label'] as String? ?? id,
      target: json['target'] as String?,
      entryId: json['entryId'] as String?,
      value: json['value'] as num?,
      formula: json['formula'] as String?,
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
