import '../../content/domain/content_entry.dart';
import 'character_content_reference.dart';
import 'character_edit_draft.dart';
import 'dnd5e_rules.dart';

/// Converts a content-library monster template into the same editable draft
/// used by manually created characters and imported Character Markdown files.
class MonsterTemplateFactory {
  const MonsterTemplateFactory._();

  static CharacterEditDraft fromEntry(ContentEntry entry) {
    final template = _map(entry.structured['characterTemplate']);
    if (entry.type != 'monster' || template.isEmpty) {
      throw FormatException('${entry.id} is not a monster character template');
    }

    final hitPoints = _map(template['hitPoints']);
    final speed = _map(template['speed']);
    final abilities = {
      for (final key in Dnd5eRules.abilityLabels.keys)
        key: _integer(_map(template['abilities'])[key], fallback: 10),
    };
    final importedSections = {
      for (final item in _map(template['sections']).entries)
        if ('${item.value}'.trim().isNotEmpty) item.key: '${item.value}'.trim(),
    };
    final monster = _canonicalMonsterGroups(template);
    final generatedSections = <String, Object?>{
      for (final group in _monsterGroupSections.entries)
        if (_mapList(monster[group.key]).isNotEmpty)
          group.value: _readableGroup(_mapList(monster[group.key])),
    };
    final sections = <String, Object?>{
      ...generatedSections,
      ...importedSections,
    };
    final actions = _projectActions(monster);
    final maximumHp = _integer(hitPoints['maximum']);
    final templateRef = _text(template['templateRef'], fallback: entry.id);
    final character = <String, Object?>{
      ...template,
      'kind': _text(template['kind'], fallback: 'monster'),
      'templateRef': templateRef,
      'hitPoints': {...hitPoints, 'maximum': maximumHp},
      if (_text(hitPoints['formula']).isNotEmpty)
        'hitPointFormula': _text(hitPoints['formula']),
      'speed': {...speed, 'walk': _integer(speed['walk'], fallback: 30)},
      'abilities': abilities,
      'sections': sections,
    };
    final challengeRating = _text(template['challengeRating']);
    final creatureType = _text(template['creatureType'], fallback: '怪物');
    final size = _text(template['size']);

    return CharacterEditDraft(
      name: entry.name,
      level: 1,
      classSummary: challengeRating.isEmpty ? '怪物' : '怪物 · CR $challengeRating',
      raceSummary: [
        size,
        creatureType,
      ].where((value) => value.isNotEmpty).join(' '),
      currentHp: maximumHp,
      maxHp: maximumHp,
      armorClass: _integer(template['armorClass'], fallback: 10),
      speed: _integer(speed['walk'], fallback: 30),
      initiativeBonus: _integer(template['initiativeBonus']),
      abilities: abilities,
      saves: {for (final key in Dnd5eRules.abilityLabels.keys) key: false},
      skills: {for (final skill in Dnd5eRules.skills) skill.name: false},
      inventory: const [],
      currency: const {'cp': 0, 'sp': 0, 'ep': 0, 'gp': 0, 'pp': 0},
      notes: '',
      data: {
        'templateRef': templateRef,
        if (_text(template['description']).isNotEmpty)
          'description': _text(template['description']),
        'character': character,
        if (monster.isNotEmpty) 'monster': monster,
        if (actions.isNotEmpty) 'actions': actions,
        'markdownSections': sections,
      },
      contentReferences: [
        CharacterContentReference(
          slot: 'characterTemplate',
          entryKey: entry.id,
          sourceRevision: entry.revision,
          snapshot: {
            'name': entry.name,
            'type': entry.type,
            'templateRef': templateRef,
          },
        ),
      ],
    );
  }
}

Map<String, Object?> _canonicalMonsterGroups(Map<String, Object?> template) {
  final legacyActions = _map(template['actions']);
  final result = <String, Object?>{
    if (_text(template['description']).isNotEmpty)
      'description': _text(template['description']),
    if (template['senses'] != null) 'senses': template['senses'],
    if (template['languages'] != null) 'languages': template['languages'],
    if (template['challenge'] != null)
      'challenge': template['challenge']
    else if (_text(template['challengeRating']).isNotEmpty)
      'challenge': {
        'rating': _text(template['challengeRating']),
        if (template['proficiencyBonus'] != null)
          'proficiencyBonus': template['proficiencyBonus'],
      },
  };
  for (final key in _monsterGroupSections.keys) {
    final rawDirect = template[key];
    final direct =
        rawDirect is List ||
            (key != 'actions' &&
                rawDirect is Map &&
                _text(rawDirect['name']).isNotEmpty)
        ? _mapList(rawDirect)
        : const <Map<String, Object?>>[];
    if (direct.isNotEmpty) {
      result[key] = direct;
      continue;
    }
    final legacyKey = _legacyActionGroups[key];
    if (legacyKey != null) {
      final legacy = _mapList(legacyActions[legacyKey]);
      if (legacy.isNotEmpty) result[key] = legacy;
    }
  }
  return result;
}

List<Map<String, Object?>> _projectActions(Map<String, Object?> monster) {
  final result = <Map<String, Object?>>[];
  for (final group in _runtimeActionTypes.entries) {
    for (final action in _mapList(monster[group.key])) {
      final id = _text(action['id']);
      final name = _text(action['name']);
      if (id.isEmpty || name.isEmpty) continue;
      final damage = _map(action['damage']);
      result.add({
        ...action,
        'id': id,
        'name': name,
        'actionType': group.value,
        if (_text(action['description']).isNotEmpty)
          'description': _text(action['description']),
        if (_text(damage['expression']).isNotEmpty)
          'formula': _text(damage['expression']),
      });
    }
  }
  return result;
}

String _readableGroup(List<Map<String, Object?>> entries) {
  return entries
      .map((entry) {
        final name = _text(entry['name']);
        final description = _text(entry['description']);
        return [
          '### $name',
          if (description.isNotEmpty) description,
        ].join('\n\n');
      })
      .join('\n\n');
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is Map) return [_map(value)];
  if (value is! List) return const [];
  return value.whereType<Map>().map(_map).toList(growable: false);
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}

int _integer(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty ? fallback : text;
}

const _monsterGroupSections = <String, String>{
  'traits': '特性',
  'actions': '动作',
  'bonusActions': '附赠动作',
  'reactions': '反应',
  'legendaryActions': '传奇动作',
  'spellcasting': '施法',
};

const _legacyActionGroups = <String, String>{
  'actions': 'normal',
  'bonusActions': 'bonus',
  'reactions': 'reactions',
  'legendaryActions': 'legendary',
};

const _runtimeActionTypes = <String, String>{
  'actions': 'action',
  'bonusActions': 'bonusAction',
  'reactions': 'reaction',
  'legendaryActions': 'legendaryAction',
  'spellcasting': 'spellcasting',
};
