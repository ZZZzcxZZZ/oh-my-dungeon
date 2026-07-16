enum RuleGrantKind {
  feature,
  proficiency,
  spell,
  equipment,
  resource,
  action,
  conditionResistance,
  speed,
  armorClass,
  hitPoints,
  ability,
  note;

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
    if (maximumOptionLevel != null) 'maximumOptionLevel': maximumOptionLevel,
    if (recommendedEntryIds.isNotEmpty)
      'recommendedEntryIds': recommendedEntryIds,
    if (builderStep != null) 'builderStep': builderStep,
  };
}

class RuleProgressionDefinition {
  const RuleProgressionDefinition({
    required this.level,
    this.grants = const <RuleGrantDefinition>[],
    this.choices = const <RuleChoiceDefinition>[],
  });

  final int level;
  final List<RuleGrantDefinition> grants;
  final List<RuleChoiceDefinition> choices;

  factory RuleProgressionDefinition.fromJson(Map<String, Object?> json) {
    final level = (json['level'] as num?)?.toInt();
    if (level == null || level < 1 || level > 20) {
      throw FormatException('Rule progression level must be 1..20: $level');
    }
    return RuleProgressionDefinition(
      level: level,
      grants: _parseList(json['grants'], RuleGrantDefinition.fromJson),
      choices: _parseList(json['choices'], RuleChoiceDefinition.fromJson),
    );
  }

  Map<String, Object?> toJson() => {
    'level': level,
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
