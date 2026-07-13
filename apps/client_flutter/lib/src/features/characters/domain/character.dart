import 'character_content_reference.dart';
import 'dnd5e_rules.dart';

class CharacterSheet {
  const CharacterSheet({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.avatarUrl,
    required this.system,
    required this.level,
    required this.classSummary,
    required this.raceSummary,
    required this.currentHp,
    required this.maxHp,
    required this.armorClass,
    required this.speed,
    required this.initiativeBonus,
    required this.abilities,
    required this.saves,
    required this.skills,
    required this.inventory,
    required this.currency,
    required this.notes,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.contentReferences = const <CharacterContentReference>[],
  });

  factory CharacterSheet.local({
    required String id,
    required String name,
    required int level,
    List<CharacterContentReference> contentReferences = const <
        CharacterContentReference>[],
    String notes = '',
    String classSummary = '',
    String raceSummary = '',
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return CharacterSheet(
      id: id,
      ownerUserId: 'local',
      name: name,
      avatarUrl: null,
      system: 'dnd5e-2024',
      level: level,
      classSummary: classSummary,
      raceSummary: raceSummary,
      currentHp: 0,
      maxHp: 0,
      armorClass: 10,
      speed: 30,
      initiativeBonus: 0,
      abilities: null,
      saves: null,
      skills: null,
      inventory: null,
      currency: null,
      notes: notes,
      data: null,
      createdAt: now,
      updatedAt: now,
      contentReferences: contentReferences,
    );
  }

  final String id;
  final String ownerUserId;
  final String name;
  final String? avatarUrl;
  final String system;
  final int level;
  final String classSummary;
  final String raceSummary;
  final int currentHp;
  final int maxHp;
  final int armorClass;
  final int speed;
  final int initiativeBonus;
  final Object? abilities;
  final Object? saves;
  final Object? skills;
  final Object? inventory;
  final Object? currency;
  final String notes;
  final Object? data;
  final String createdAt;
  final String updatedAt;
  final List<CharacterContentReference> contentReferences;

  Map<String, Object?> get abilityMap => _asMap(abilities);
  Map<String, Object?> get saveMap => _asMap(saves);
  Map<String, Object?> get skillMap => _asMap(skills);
  Map<String, Object?> get currencyMap => _asMap(currency);
  List<Object?> get inventoryList => _asList(inventory);
  Map<String, Object?> get dataMap => _asMap(data);
  Map<String, Object?> get runtimeMap => _asMap(dataMap['runtime']);
  int get temporaryHp => _intValue(runtimeMap['temporaryHp']);
  bool get inspiration => runtimeMap['inspiration'] == true;
  List<String> get conditions => _asList(
    runtimeMap['conditions'],
  ).whereType<String>().toList(growable: false);
  int get deathSaveSuccesses {
    return _intValue(_asMap(runtimeMap['deathSaves'])['successes']);
  }

  int get deathSaveFailures {
    return _intValue(_asMap(runtimeMap['deathSaves'])['failures']);
  }

  Map<String, int> get spellSlotsUsed {
    return {
      for (final entry in _asMap(runtimeMap['spellSlotsUsed']).entries)
        entry.key: _intValue(entry.value),
    };
  }

  Map<String, int> get classResourcesUsed {
    return {
      for (final entry in _asMap(runtimeMap['classResourcesUsed']).entries)
        entry.key: _intValue(entry.value),
    };
  }

  List<CharacterClassResource> get classResources {
    final explicitResources = _asList(dataMap['classResources'])
        .map((item) => _asMap(item))
        .where((item) => item['id'] != null && item['name'] != null)
        .map(
          (item) => CharacterClassResource(
            id: '${item['id']}',
            name: '${item['name']}',
            maximum: _intValue(item['maximum']),
          ),
        )
        .where((item) => item.maximum > 0)
        .toList(growable: false);
    if (explicitResources.isNotEmpty) return explicitResources;
    return Dnd5eRules.classResources(classSummary: classSummary, level: level)
        .map(
          (item) => CharacterClassResource(
            id: item.id,
            name: item.name,
            maximum: item.maximum,
          ),
        )
        .toList(growable: false);
  }

  List<String> get spellRefs {
    return _asList(
      _asMap(dataMap['contentRefs'])['spells'],
    ).map((item) => '$item').where((item) => item.trim().isNotEmpty).toList();
  }

  factory CharacterSheet.fromJson(Map<String, Object?> json) {
    final refsRaw = json['contentReferences'];
    final contentReferences = refsRaw is List
        ? refsRaw
            .map((item) => CharacterContentReference.fromJson(
                  Map<String, Object?>.from(item as Map),
                ))
            .toList(growable: false)
        : const <CharacterContentReference>[];
    return CharacterSheet(
      id: json['id']! as String,
      ownerUserId: json['ownerUserId']! as String,
      name: json['name']! as String,
      avatarUrl: json['avatarUrl'] as String?,
      system: json['system']! as String,
      level: (json['level'] as num).toInt(),
      classSummary: json['classSummary']! as String,
      raceSummary: json['raceSummary']! as String,
      currentHp: (json['currentHp'] as num).toInt(),
      maxHp: (json['maxHp'] as num).toInt(),
      armorClass: (json['armorClass'] as num).toInt(),
      speed: (json['speed'] as num).toInt(),
      initiativeBonus: (json['initiativeBonus'] as num).toInt(),
      abilities: json['abilities'],
      saves: json['saves'],
      skills: json['skills'],
      inventory: json['inventory'],
      currency: json['currency'],
      notes: json['notes']! as String,
      data: json['data'],
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      contentReferences: contentReferences,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'ownerUserId': ownerUserId,
        'name': name,
        'avatarUrl': avatarUrl,
        'system': system,
        'level': level,
        'classSummary': classSummary,
        'raceSummary': raceSummary,
        'currentHp': currentHp,
        'maxHp': maxHp,
        'armorClass': armorClass,
        'speed': speed,
        'initiativeBonus': initiativeBonus,
        'abilities': abilities,
        'saves': saves,
        'skills': skills,
        'inventory': inventory,
        'currency': currency,
        'notes': notes,
        'data': data,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'contentReferences':
            contentReferences.map((ref) => ref.toJson()).toList(),
      };

  CharacterSheet copyWith({
    String? name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
    Object? abilities,
    Object? saves,
    Object? skills,
    Object? inventory,
    Object? currency,
    String? notes,
    Object? data,
    List<CharacterContentReference>? contentReferences,
  }) {
    return CharacterSheet(
      id: id,
      ownerUserId: ownerUserId,
      name: name ?? this.name,
      avatarUrl: avatarUrl,
      system: system,
      level: level ?? this.level,
      classSummary: classSummary ?? this.classSummary,
      raceSummary: raceSummary ?? this.raceSummary,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      armorClass: armorClass ?? this.armorClass,
      speed: speed ?? this.speed,
      initiativeBonus: initiativeBonus ?? this.initiativeBonus,
      abilities: abilities ?? this.abilities,
      saves: saves ?? this.saves,
      skills: skills ?? this.skills,
      inventory: inventory ?? this.inventory,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      data: data ?? this.data,
      createdAt: createdAt,
      updatedAt: updatedAt,
      contentReferences: contentReferences ?? this.contentReferences,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CharacterSheet &&
            id == other.id &&
            ownerUserId == other.ownerUserId &&
            name == other.name &&
            avatarUrl == other.avatarUrl &&
            system == other.system &&
            level == other.level &&
            classSummary == other.classSummary &&
            raceSummary == other.raceSummary &&
            currentHp == other.currentHp &&
            maxHp == other.maxHp &&
            armorClass == other.armorClass &&
            speed == other.speed &&
            initiativeBonus == other.initiativeBonus &&
            notes == other.notes &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            _listEquals(contentReferences, other.contentReferences);
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerUserId,
    name,
    avatarUrl,
    system,
    level,
    classSummary,
    raceSummary,
    currentHp,
    maxHp,
    armorClass,
    speed,
    initiativeBonus,
    notes,
    createdAt,
    updatedAt,
    Object.hashAll(contentReferences),
  );
}

class CharacterClassResource {
  const CharacterClassResource({
    required this.id,
    required this.name,
    required this.maximum,
  });

  final String id;
  final String name;
  final int maximum;
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return {};
}

List<Object?> _asList(Object? value) {
  if (value is List<Object?>) return value;
  if (value is List) return List<Object?>.from(value);
  return [];
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return 0;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class CharacterCampaignBinding {
  const CharacterCampaignBinding({
    required this.id,
    required this.campaignId,
    required this.characterId,
    required this.userId,
    required this.visibility,
    required this.status,
    required this.dmNotes,
    required this.joinedAt,
    required this.updatedAt,
    this.character,
  });

  final String id;
  final String campaignId;
  final String characterId;
  final String userId;
  final String visibility;
  final String status;
  final String dmNotes;
  final String joinedAt;
  final String updatedAt;
  final CharacterSheet? character;

  factory CharacterCampaignBinding.fromJson(Map<String, Object?> json) {
    return CharacterCampaignBinding(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      characterId: json['characterId']! as String,
      userId: json['userId']! as String,
      visibility: json['visibility']! as String,
      status: json['status']! as String,
      dmNotes: json['dmNotes']! as String,
      joinedAt: json['joinedAt']! as String,
      updatedAt: json['updatedAt']! as String,
      character: json['character'] == null
          ? null
          : CharacterSheet.fromJson(json['character']! as Map<String, Object?>),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CharacterCampaignBinding &&
            id == other.id &&
            campaignId == other.campaignId &&
            characterId == other.characterId &&
            userId == other.userId &&
            visibility == other.visibility &&
            status == other.status &&
            dmNotes == other.dmNotes &&
            joinedAt == other.joinedAt &&
            updatedAt == other.updatedAt &&
            character == other.character;
  }

  @override
  int get hashCode => Object.hash(
    id,
    campaignId,
    characterId,
    userId,
    visibility,
    status,
    dmNotes,
    joinedAt,
    updatedAt,
    character,
  );
}
