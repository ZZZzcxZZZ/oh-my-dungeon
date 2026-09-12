import 'character.dart';

class CharacterManualOverrides {
  const CharacterManualOverrides({
    this.addedFeatureEntryIds = const <String>[],
    this.hiddenGrantKeys = const <String>[],
    this.customFeatures = const <Map<String, Object?>>[],
    this.addedSpellEntryIds = const <String>[],
    this.removedSpellEntryIds = const <String>[],
    this.preparedSpellEntryIds = const <String>[],
    this.alwaysPreparedEntryIds = const <String>[],
    this.customSpells = const <Map<String, Object?>>[],
    this.customActions = const <Map<String, Object?>>[],
  });

  factory CharacterManualOverrides.fromCharacter(CharacterSheet character) {
    final raw = character.dataMap['manualOverrides'];
    return raw is Map
        ? CharacterManualOverrides.fromJson(Map<String, Object?>.from(raw))
        : const CharacterManualOverrides();
  }

  factory CharacterManualOverrides.fromJson(Map<String, Object?> json) {
    final features = _map(json['features']);
    final spells = _map(json['spells']);
    final actions = _map(json['actions']);
    return CharacterManualOverrides(
      addedFeatureEntryIds: _strings(features['addedEntryIds']),
      hiddenGrantKeys: _strings(features['hiddenGrantKeys']),
      customFeatures: _maps(features['custom']),
      addedSpellEntryIds: _strings(spells['addedEntryIds']),
      removedSpellEntryIds: _strings(spells['removedEntryIds']),
      preparedSpellEntryIds: _strings(spells['preparedEntryIds']),
      alwaysPreparedEntryIds: _strings(spells['alwaysPreparedEntryIds']),
      customSpells: _maps(spells['custom']),
      customActions: _maps(actions['custom']),
    );
  }

  final List<String> addedFeatureEntryIds;
  final List<String> hiddenGrantKeys;
  final List<Map<String, Object?>> customFeatures;
  final List<String> addedSpellEntryIds;
  final List<String> removedSpellEntryIds;
  final List<String> preparedSpellEntryIds;

  /// `countsToward == null` 的**显式法术选择**（`optionType: "spell"`）选中的法术：
  /// 它们不占数量池，额外记一份用于展示"始终准备"标记（契约 §3.11 A3）。
  ///
  /// 与 [preparedSpellEntryIds] 一样是**去重集合**（决策 D9）：重复选取的**次数**
  /// 只保留在有序的 `build.choices` 里。
  final List<String> alwaysPreparedEntryIds;

  final List<Map<String, Object?>> customSpells;
  final List<Map<String, Object?>> customActions;

  CharacterManualOverrides copyWith({
    List<String>? addedFeatureEntryIds,
    List<String>? hiddenGrantKeys,
    List<Map<String, Object?>>? customFeatures,
    List<String>? addedSpellEntryIds,
    List<String>? removedSpellEntryIds,
    List<String>? preparedSpellEntryIds,
    List<String>? alwaysPreparedEntryIds,
    List<Map<String, Object?>>? customSpells,
    List<Map<String, Object?>>? customActions,
  }) {
    return CharacterManualOverrides(
      addedFeatureEntryIds: addedFeatureEntryIds ?? this.addedFeatureEntryIds,
      hiddenGrantKeys: hiddenGrantKeys ?? this.hiddenGrantKeys,
      customFeatures: customFeatures ?? this.customFeatures,
      addedSpellEntryIds: addedSpellEntryIds ?? this.addedSpellEntryIds,
      removedSpellEntryIds: removedSpellEntryIds ?? this.removedSpellEntryIds,
      preparedSpellEntryIds:
          preparedSpellEntryIds ?? this.preparedSpellEntryIds,
      alwaysPreparedEntryIds:
          alwaysPreparedEntryIds ?? this.alwaysPreparedEntryIds,
      customSpells: customSpells ?? this.customSpells,
      customActions: customActions ?? this.customActions,
    );
  }

  /// 用一次规则派生产出的**显式法术选择镜像**更新准备状态（契约 §3.11 A3）。
  ///
  /// **唯一合并点**：只改 `preparedSpellEntryIds` / `alwaysPreparedEntryIds`
  /// （builder 的 `data['manualOverrides']` 就带这两份），其余字段——自定义法术、
  /// 手动添加 / 移除的法术、隐藏的授予——一律原样保留。升级与再派生都必须走它，
  /// 不得各自写一份"覆盖式"合并。
  CharacterManualOverrides copyWithSpellPicksFrom(
    CharacterManualOverrides picks,
  ) {
    return copyWith(
      preparedSpellEntryIds: picks.preparedSpellEntryIds,
      alwaysPreparedEntryIds: picks.alwaysPreparedEntryIds,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'features': <String, Object?>{
      'addedEntryIds': _unique(addedFeatureEntryIds),
      'hiddenGrantKeys': _unique(hiddenGrantKeys),
      'custom': _immutableMaps(customFeatures),
    },
    'spells': <String, Object?>{
      'addedEntryIds': _unique(addedSpellEntryIds),
      'removedEntryIds': _unique(removedSpellEntryIds),
      'preparedEntryIds': _unique(preparedSpellEntryIds),
      'alwaysPreparedEntryIds': _unique(alwaysPreparedEntryIds),
      'custom': _immutableMaps(customSpells),
    },
    'actions': <String, Object?>{'custom': _immutableMaps(customActions)},
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CharacterManualOverrides &&
            _deepEquals(toJson(), other.toJson());
  }

  @override
  int get hashCode => _deepHash(toJson());
}

Map<String, Object?> _map(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : <String, Object?>{};
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return _unique(value.whereType<String>());
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.unmodifiable(item))
      .toList(growable: false);
}

List<String> _unique(Iterable<String> values) => values
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toSet()
    .toList(growable: false);

List<Map<String, Object?>> _immutableMaps(
  Iterable<Map<String, Object?>> values,
) => values
    .map((value) => Map<String, Object?>.unmodifiable(value))
    .toList(growable: false);

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final key in left.keys) {
      if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

int _deepHash(Object? value) {
  if (value is List) return Object.hashAll(value.map(_deepHash));
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return Object.hashAll(
      keys.map((key) => Object.hash(key, _deepHash(value[key]))),
    );
  }
  return value.hashCode;
}
