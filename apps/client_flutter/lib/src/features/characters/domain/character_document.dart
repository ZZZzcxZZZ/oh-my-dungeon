const characterDocumentSchemaVersion = 2;

class CharacterDocument {
  const CharacterDocument({
    required this.hitPoints,
    required this.deathSaves,
    required this.resources,
    required this.conditions,
    required this.items,
    required this.extensions,
  });

  factory CharacterDocument.fromJson(Map<String, Object?> json) {
    final runtime = _map(json['runtime']);
    final hp = _map(json['hitPoints']);
    var maximum = _integer(hp['maximum'] ?? json['maxHp']);
    var current = _integer(
      hp['current'] ?? json['currentHp'] ?? runtime['currentHp'],
    );
    final legacyHp = json['hp'];
    if (legacyHp is String) {
      final match = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(legacyHp);
      if (match != null) {
        current = int.parse(match.group(1)!);
        maximum = int.parse(match.group(2)!);
      }
    }
    maximum = maximum.clamp(0, 1 << 31);
    final deathSaves = _map(json['deathSaves'] ?? runtime['deathSaves']);
    final extensions = _map(json['extensions'])
      ..removeWhere((key, _) => !key.contains('.'));
    return CharacterDocument(
      hitPoints: CharacterHitPoints(
        current: current.clamp(0, maximum),
        maximum: maximum,
        temporary: _integer(
          hp['temporary'] ?? runtime['temporaryHp'],
        ).clamp(0, 1 << 31),
      ),
      deathSaves: CharacterDeathSaves(
        successes: _integer(deathSaves['successes']).clamp(0, 3),
        failures: _integer(deathSaves['failures']).clamp(0, 3),
      ),
      resources: _list(json['resources'])
          .map(CharacterResource.fromJson)
          .whereType<CharacterResource>()
          .toList(growable: false),
      conditions: _list(json['conditions'] ?? runtime['conditions'])
          .map(CharacterCondition.fromJson)
          .whereType<CharacterCondition>()
          .toList(growable: false),
      items: _list(json['items'] ?? json['inventory'])
          .map(CharacterItem.fromJson)
          .whereType<CharacterItem>()
          .toList(growable: false),
      extensions: Map<String, Object?>.unmodifiable(extensions),
    );
  }

  final int schemaVersion = characterDocumentSchemaVersion;
  final CharacterHitPoints hitPoints;
  final CharacterDeathSaves deathSaves;
  final List<CharacterResource> resources;
  final List<CharacterCondition> conditions;
  final List<CharacterItem> items;
  final Map<String, Object?> extensions;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'hitPoints': hitPoints.toJson(),
    'deathSaves': deathSaves.toJson(),
    'resources': resources.map((item) => item.toJson()).toList(),
    'conditions': conditions.map((item) => item.toJson()).toList(),
    'items': items.map((item) => item.toJson()).toList(),
    'extensions': extensions,
  };

  @override
  bool operator ==(Object other) =>
      other is CharacterDocument && _deepEquals(toJson(), other.toJson());

  @override
  int get hashCode => toJson().toString().hashCode;
}

class CharacterHitPoints {
  const CharacterHitPoints({
    required this.current,
    required this.maximum,
    required this.temporary,
  });

  final int current;
  final int maximum;
  final int temporary;

  Map<String, Object?> toJson() => {
    'current': current,
    'maximum': maximum,
    'temporary': temporary,
  };

  @override
  bool operator ==(Object other) =>
      other is CharacterHitPoints &&
      current == other.current &&
      maximum == other.maximum &&
      temporary == other.temporary;

  @override
  int get hashCode => Object.hash(current, maximum, temporary);
}

class CharacterDeathSaves {
  const CharacterDeathSaves({required this.successes, required this.failures});

  final int successes;
  final int failures;

  Map<String, Object?> toJson() => {
    'successes': successes,
    'failures': failures,
  };

  @override
  bool operator ==(Object other) =>
      other is CharacterDeathSaves &&
      successes == other.successes &&
      failures == other.failures;

  @override
  int get hashCode => Object.hash(successes, failures);
}

class CharacterResource {
  const CharacterResource({
    required this.id,
    required this.name,
    required this.current,
    required this.maximum,
    required this.restoreOn,
    required this.sourceRef,
    required this.custom,
  });

  static CharacterResource? fromJson(Object? value) {
    final json = _map(value);
    final id = _text(json['id']);
    final name = _text(json['name']);
    if (id.isEmpty || name.isEmpty) return null;
    final maximum = _integer(json['maximum']).clamp(0, 1 << 31);
    final recovery = switch (json['restoreOn']) {
      'shortRest' || 'longRest' || 'none' => json['restoreOn']! as String,
      _ => 'longRest',
    };
    return CharacterResource(
      id: id,
      name: name,
      current: _integer(json['current'], maximum).clamp(0, maximum),
      maximum: maximum,
      restoreOn: recovery,
      sourceRef: _text(json['sourceRef']).nullIfEmpty,
      custom: json['custom'] == true,
    );
  }

  final String id;
  final String name;
  final int current;
  final int maximum;
  final String restoreOn;
  final String? sourceRef;
  final bool custom;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'current': current,
    'maximum': maximum,
    'restoreOn': restoreOn,
    'sourceRef': sourceRef,
    'custom': custom,
  };
}

class CharacterCondition {
  const CharacterCondition({
    required this.id,
    required this.type,
    required this.remaining,
    required this.metadata,
  });

  static CharacterCondition? fromJson(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return CharacterCondition(
        id: value.trim(),
        type: value.trim(),
        remaining: null,
        metadata: const {},
      );
    }
    final json = _map(value);
    final id = _text(json['id']);
    final type = _text(json['type']);
    if (id.isEmpty || type.isEmpty) return null;
    return CharacterCondition(
      id: id,
      type: type,
      remaining: json['remaining'] == null
          ? null
          : _integer(json['remaining']).clamp(0, 1 << 31),
      metadata: Map.unmodifiable(_map(json['metadata'])),
    );
  }

  final String id;
  final String type;
  final int? remaining;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'remaining': remaining,
    'metadata': metadata,
  };
}

class CharacterItem {
  const CharacterItem({
    required this.id,
    required this.name,
    required this.templateRef,
    required this.quantity,
    required this.equipped,
    required this.attuned,
    required this.instanceData,
  });

  static CharacterItem? fromJson(Object? value) {
    final json = _map(value);
    final id = _text(json['id']);
    final name = _text(json['name']);
    if (id.isEmpty || name.isEmpty) return null;
    return CharacterItem(
      id: id,
      name: name,
      templateRef: _text(json['templateRef']).nullIfEmpty,
      quantity: _integer(json['quantity'], 1).clamp(0, 1 << 31),
      equipped: json['equipped'] == true,
      attuned: json['attuned'] == true,
      instanceData: Map.unmodifiable(_map(json['instanceData'])),
    );
  }

  final String id;
  final String name;
  final String? templateRef;
  final int quantity;
  final bool equipped;
  final bool attuned;
  final Map<String, Object?> instanceData;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'templateRef': templateRef,
    'quantity': quantity,
    'equipped': equipped,
    'attuned': attuned,
    'instanceData': instanceData,
  };
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.map((key, item) => MapEntry('$key', item)) : {};

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const [];

String _text(Object? value) => value is String ? value.trim() : '';

int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

bool _deepEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    return left.entries.every(
      (entry) =>
          right.containsKey(entry.key) &&
          _deepEquals(entry.value, right[entry.key]),
    );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
