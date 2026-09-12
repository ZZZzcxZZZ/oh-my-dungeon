class CharacterBuild {
  const CharacterBuild({
    required this.level,
    this.selections = const <String, String>{},
    this.choices = const <String, List<String>>{},
    this.abilities = const <String, int>{},
  });

  final int level;
  final Map<String, String> selections;
  final Map<String, List<String>> choices;

  /// `requires: {ability, minimum}` 的**唯一数据源**（决策 D4/D2）：入参基础属性，
  /// 不是结算后的有效属性——`kind: ability` 加值由选择产生，用结算值会让
  /// `requires` 与选择互相引用（求值不成不动点）。缺省空 map = "未记录属性"，
  /// 能力型 `requires` 一律判定为不满足（可见的 pending），绝不猜成 10。
  ///
  /// 只进 `data['build']` 的 JSON，不改 Drift 表结构（`schemaVersion` 保持 13）。
  final Map<String, int> abilities;

  Map<String, Object?> toJson() => {
    'level': level,
    'selections': selections,
    'choices': choices,
    if (abilities.isNotEmpty) 'abilities': abilities,
  };

  factory CharacterBuild.fromJson(Map<String, Object?> json) {
    final selections = json['selections'];
    final choices = json['choices'];
    final abilities = json['abilities'];
    return CharacterBuild(
      level: (json['level'] as num?)?.toInt() ?? 1,
      selections: selections is Map
          ? selections.map((key, value) => MapEntry('$key', '$value'))
          : const <String, String>{},
      choices: choices is Map
          ? choices.map(
              (key, value) => MapEntry(
                '$key',
                value is List
                    ? value.map((item) => '$item').toList(growable: false)
                    : const <String>[],
              ),
            )
          : const <String, List<String>>{},
      abilities: abilities is Map
          ? {
              for (final entry in abilities.entries)
                if (entry.value is num)
                  '${entry.key}': (entry.value as num).toInt(),
            }
          : const <String, int>{},
    );
  }
}

class CharacterRuntime {
  const CharacterRuntime({
    required this.currentHp,
    this.temporaryHp = 0,
    this.inspiration = false,
    this.conditions = const <String>[],
    this.deathSaveSuccesses = 0,
    this.deathSaveFailures = 0,
    this.spellSlotsUsed = const <String, int>{},
    this.classResourcesUsed = const <String, int>{},
  });

  final int currentHp;
  final int temporaryHp;
  final bool inspiration;
  final List<String> conditions;
  final int deathSaveSuccesses;
  final int deathSaveFailures;
  final Map<String, int> spellSlotsUsed;
  final Map<String, int> classResourcesUsed;

  factory CharacterRuntime.fromJson(Map<String, Object?> json) {
    final deathSaves = _runtimeMap(json['deathSaves']);
    return CharacterRuntime(
      currentHp: _runtimeInt(json['currentHp']),
      temporaryHp: _runtimeInt(json['temporaryHp']),
      inspiration: json['inspiration'] == true,
      conditions: json['conditions'] is List
          ? (json['conditions'] as List)
                .map((item) => '$item')
                .toList(growable: false)
          : const <String>[],
      deathSaveSuccesses: _runtimeInt(deathSaves['successes']),
      deathSaveFailures: _runtimeInt(deathSaves['failures']),
      spellSlotsUsed: _runtimeIntMap(json['spellSlotsUsed']),
      classResourcesUsed: _runtimeIntMap(json['classResourcesUsed']),
    );
  }

  Map<String, Object?> toJson() => {
    'currentHp': currentHp,
    'temporaryHp': temporaryHp,
    'inspiration': inspiration,
    'conditions': conditions,
    'deathSaves': {
      'successes': deathSaveSuccesses,
      'failures': deathSaveFailures,
    },
    'spellSlotsUsed': spellSlotsUsed,
    'classResourcesUsed': classResourcesUsed,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterRuntime &&
          currentHp == other.currentHp &&
          temporaryHp == other.temporaryHp &&
          inspiration == other.inspiration &&
          _runtimeListEquals(conditions, other.conditions) &&
          deathSaveSuccesses == other.deathSaveSuccesses &&
          deathSaveFailures == other.deathSaveFailures &&
          _runtimeMapEquals(spellSlotsUsed, other.spellSlotsUsed) &&
          _runtimeMapEquals(classResourcesUsed, other.classResourcesUsed);

  @override
  int get hashCode => Object.hash(
    currentHp,
    temporaryHp,
    inspiration,
    Object.hashAll(conditions),
    deathSaveSuccesses,
    deathSaveFailures,
    Object.hashAllUnordered(spellSlotsUsed.entries),
    Object.hashAllUnordered(classResourcesUsed.entries),
  );
}

Map<String, Object?> _runtimeMap(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

Map<String, int> _runtimeIntMap(Object? value) {
  return {
    for (final entry in _runtimeMap(value).entries)
      entry.key: _runtimeInt(entry.value),
  };
}

int _runtimeInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

bool _runtimeListEquals(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _runtimeMapEquals(Map<String, int> left, Map<String, int> right) {
  if (left.length != right.length) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}
