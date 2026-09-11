import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:yaml/yaml.dart';

import '../domain/character.dart';
import '../domain/character_content_reference.dart';
import '../domain/character_document.dart';
import '../domain/dnd5e_rules.dart';

enum CharacterMarkdownMode { profile, campaignSnapshot }

class CharacterMarkdownImport {
  const CharacterMarkdownImport({
    required this.character,
    required this.state,
    required this.mode,
  });

  final CharacterSheet character;
  final CharacterDocument state;
  final CharacterMarkdownMode mode;
}

class CharacterMarkdownFormatException implements Exception {
  const CharacterMarkdownFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CharacterMarkdownCodec {
  const CharacterMarkdownCodec();

  String encode(
    CharacterSheet character, {
    CharacterMarkdownMode mode = CharacterMarkdownMode.profile,
    int revision = 1,
  }) {
    final state = _stateFor(character);
    final canonicalSnapshot = base64UrlEncode(
      utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'data': character.dataMap,
          'contentReferences': character.contentReferences
              .map((reference) => reference.toJson())
              .toList(growable: false),
        }),
      ),
    );
    final contentHash = sha256
        .convert(utf8.encode(jsonEncode(character.toJson())))
        .toString();
    final characterProfile = _map(character.dataMap['character']);
    final kind = _metadataText(characterProfile, 'kind', fallback: 'player');
    final speed = _map(characterProfile['speed']);
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('format: dnd-table-character/v2')
      ..writeln('kind: ${_safeCharacterKind(kind)}')
      ..writeln('name: ${_yamlScalar(character.name)}')
      ..writeln('mode: ${mode.name}')
      ..writeln('id: ${_yamlScalar(character.id)}')
      ..writeln('revision: ${revision.clamp(1, 1 << 31)}')
      ..writeln('contentHash: sha256:$contentHash')
      ..writeln('generatedAt: ${character.updatedAt}')
      ..writeln('owner: ${_yamlScalar(character.ownerUserId)}')
      ..writeln('system: ${_yamlScalar(character.system)}')
      ..writeln('level: ${character.level}');
    for (final field in const [
      'templateRef',
      'size',
      'creatureType',
      'alignment',
      'challengeRating',
      'proficiencyBonus',
    ]) {
      if (characterProfile[field] != null &&
          '${characterProfile[field]}'.trim().isNotEmpty) {
        buffer.writeln('$field: ${_yamlScalar(characterProfile[field])}');
      }
    }
    buffer
      ..writeln('armorClass: ${character.armorClass}')
      ..writeln('hitPoints:')
      ..writeln('  current: ${state.hitPoints.current}')
      ..writeln('  maximum: ${state.hitPoints.maximum}');
    if (characterProfile['hitPointFormula'] != null) {
      buffer.writeln(
        '  formula: ${_yamlScalar(characterProfile['hitPointFormula'])}',
      );
    }
    buffer
      ..writeln('speed:')
      ..writeln('  walk: ${_integer(speed['walk'] ?? character.speed)}')
      ..writeln('abilities:')
      ..write(_encodeYamlMap(character.abilityMap, indent: 2))
      ..writeln('initiativeBonus: ${character.initiativeBonus}')
      ..writeln('createdAt: ${_yamlScalar(character.createdAt)}')
      ..writeln('updatedAt: ${_yamlScalar(character.updatedAt)}');
    buffer.writeln('snapshot: ${_yamlScalar(canonicalSnapshot)}');
    if (character.avatarUrl != null) {
      buffer.writeln('avatar: ${_yamlScalar(character.avatarUrl!)}');
    }
    buffer
      ..writeln('extensions:')
      ..write(_encodeYamlMap(state.extensions, indent: 2))
      ..writeln('---')
      ..writeln()
      ..writeln('# ${character.name}')
      ..writeln()
      ..writeln(
        '> ${character.level} 级 ${character.raceSummary} ${character.classSummary}'
            .trim(),
      )
      ..writeln()
      ..writeln('## 基础资料')
      ..writeln()
      ..writeln('| 字段 | 值 |')
      ..writeln('| --- | --- |')
      ..writeln('| 名称 | ${_cell(character.name)} |')
      ..writeln('| 等级 | ${character.level} |')
      ..writeln('| 种族 | ${_cell(character.raceSummary)} |')
      ..writeln('| 职业 | ${_cell(character.classSummary)} |')
      ..writeln()
      ..writeln('## 属性')
      ..writeln()
      ..writeln('| 属性 | 数值 |')
      ..writeln('| --- | ---: |');
    for (final entry in _abilityLabels.entries) {
      buffer.writeln(
        '| ${entry.value} | ${_integer(character.abilityMap[entry.key])} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## 豁免')
      ..writeln()
      ..writeln('| 属性 | 熟练 |')
      ..writeln('| --- | --- |');
    for (final entry in _abilityLabels.entries) {
      buffer.writeln(
        '| ${entry.value} | ${character.saveMap[entry.key] == true ? '是' : '否'} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## 技能')
      ..writeln()
      ..writeln('| 技能 | 熟练 |')
      ..writeln('| --- | --- |');
    for (final entry in character.skillMap.entries) {
      buffer.writeln(
        '| ${_cell(entry.key)} | ${entry.value == true ? '是' : '否'} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## 战斗')
      ..writeln()
      ..writeln('| 字段 | 值 |')
      ..writeln('| --- | ---: |')
      ..writeln('| 当前 HP | ${state.hitPoints.current} |')
      ..writeln('| 最大 HP | ${state.hitPoints.maximum} |')
      ..writeln('| 临时 HP | ${state.hitPoints.temporary} |')
      ..writeln('| AC | ${character.armorClass} |')
      ..writeln('| 速度 | ${character.speed} |')
      ..writeln('| 先攻 | ${character.initiativeBonus} |')
      ..writeln('| 死亡豁免成功 | ${state.deathSaves.successes} |')
      ..writeln('| 死亡豁免失败 | ${state.deathSaves.failures} |')
      ..writeln()
      ..writeln('## 资源')
      ..writeln()
      ..writeln('| 名称 | 当前 | 最大 | 恢复 | 自定义 |')
      ..writeln('| --- | ---: | ---: | --- | --- |');
    for (final resource in state.resources) {
      buffer.writeln(
        '| ${_cell(resource.name)} <!-- dnd:id=${_comment(resource.id)} --> '
        '| ${resource.current} | ${resource.maximum} '
        '| ${_restoreLabel(resource.restoreOn)} '
        '| ${resource.custom ? '是' : '否'} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## 状态')
      ..writeln();
    if (state.conditions.isEmpty) {
      buffer.writeln('- 无');
    } else {
      for (final condition in state.conditions) {
        final remaining = condition.remaining == null
            ? ''
            : '，剩余 ${condition.remaining}';
        buffer.writeln(
          '- ${condition.type}$remaining '
          '<!-- dnd:id=${_comment(condition.id)} -->',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## 装备')
      ..writeln()
      ..writeln('| 名称 | 数量 | 装备 | 同调 |')
      ..writeln('| --- | ---: | --- | --- |');
    for (final item in state.items) {
      buffer.writeln(
        '| ${_cell(item.name)} <!-- dnd:id=${_comment(item.id)} --> '
        '| ${item.quantity} | ${item.equipped ? '是' : '否'} '
        '| ${item.attuned ? '是' : '否'} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## 货币')
      ..writeln()
      ..writeln('| 币种 | 数量 |')
      ..writeln('| --- | ---: |');
    for (final entry in character.currencyMap.entries) {
      buffer.writeln('| ${_cell(entry.key)} | ${_integer(entry.value)} |');
    }
    if (character.description.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## 描述')
        ..writeln()
        ..writeln(character.description)
        ..writeln();
    }
    final monster = _map(character.dataMap['monster']);
    for (final group in _monsterGroupSections.entries) {
      final entries = _mapList(monster[group.key]);
      if (entries.isEmpty) continue;
      buffer
        ..writeln()
        ..writeln('## ${group.value}')
        ..writeln();
      for (final entry in entries) {
        _writeMonsterEntry(buffer, entry);
      }
    }
    final ruleSnapshots = _map(character.dataMap['ruleSnapshots']);
    final contentRefs = _map(character.dataMap['contentRefs']);
    _writeRuleSnapshotSection(
      buffer,
      title: '规则特性',
      entryIds: _stringList(contentRefs['features']),
      snapshots: ruleSnapshots,
    );
    _writeRuleSnapshotSection(
      buffer,
      title: '法术',
      entryIds: _stringList(contentRefs['spells']),
      snapshots: ruleSnapshots,
    );
    _writeRuleSnapshotSection(
      buffer,
      title: '角色动作',
      entryIds: _actionEntryIds(character.dataMap['actions']),
      snapshots: ruleSnapshots,
    );
    if (character.notes.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## 笔记')
        ..writeln()
        ..writeln(character.notes.trimRight())
        ..writeln();
    }
    final extraSections = _map(character.dataMap['markdownSections']);
    for (final entry in extraSections.entries) {
      if (_knownSections.contains(_normalizeHeading(entry.key))) continue;
      final structuredGroup =
          _monsterSectionGroups[_normalizeHeading(entry.key)];
      if (structuredGroup != null &&
          _mapList(monster[structuredGroup]).isNotEmpty) {
        continue;
      }
      buffer
        ..writeln('## ${entry.key}')
        ..writeln()
        ..writeln('${entry.value}'.trim())
        ..writeln();
    }
    final monsterMetadata = <String, Object?>{
      for (final key in const ['senses', 'languages', 'challenge'])
        if (monster[key] != null) key: monster[key],
    };
    if (monsterMetadata.isNotEmpty) {
      buffer
        ..writeln('## 怪物资料')
        ..writeln();
      _writeMonsterMetadata(buffer, monsterMetadata);
    }
    return buffer.toString();
  }

  CharacterMarkdownImport decode(String source) {
    final envelope = _parseFrontMatter(source);
    final metadata = envelope.metadata;
    final canonicalSnapshot = _readCanonicalSnapshot(metadata['snapshot']);
    final format = metadata['format'];
    final isCharacterFormat =
        format == 'dnd-table-character/v2' ||
        format == 'dnd-table-character/v1';
    if (!isCharacterFormat) {
      throw const CharacterMarkdownFormatException('不支持的角色卡 Markdown 格式');
    }
    final normalizedBody = _normalizeTableWhitespace(envelope.body);
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
    ).parseLines(normalizedBody.split('\n'));
    final sections = _collectSections(nodes);
    final title = _firstHeading(nodes, 1);
    final basics = _tableMap(sections['基础资料'], keyColumn: 0, valueColumn: 1);
    final abilities = _tableMap(sections['属性'], keyColumn: 0, valueColumn: 1);
    final saves = _tableMap(sections['豁免'], keyColumn: 0, valueColumn: 1);
    final skills = _tableMap(sections['技能'], keyColumn: 0, valueColumn: 1);
    final combat = _tableMap(sections['战斗'], keyColumn: 0, valueColumn: 1);
    final currency = _tableMap(sections['货币'], keyColumn: 0, valueColumn: 1);
    final characterHitPoints = _map(metadata['hitPoints']);
    final characterAbilities = _map(metadata['abilities']);
    final characterSpeed = _map(metadata['speed']);
    final level = isCharacterFormat
        ? _characterFieldInt(
            basics['等级'],
            metadata['level'],
            field: '等级',
            fallback: 1,
          )
        : _requiredInt(basics['等级'], '等级');
    final currentHp = isCharacterFormat
        ? _characterFieldInt(
            combat['当前 HP'],
            characterHitPoints['current'],
            field: '当前 HP',
            fallback: 0,
          )
        : _requiredInt(combat['当前 HP'], '当前 HP');
    final maxHp = isCharacterFormat
        ? _characterFieldInt(
            combat['最大 HP'],
            characterHitPoints['maximum'],
            field: '最大 HP',
            fallback: currentHp,
          )
        : _requiredInt(combat['最大 HP'], '最大 HP');
    final resources = _parseResources(sections['资源'], envelope.body);
    final conditions = _parseConditions(sections['状态'], envelope.body);
    final items = _parseItems(sections['装备'], envelope.body);
    final extensions = _deepMap(metadata['extensions'])
      ..removeWhere((key, _) => !key.contains('.'));
    final state = CharacterDocument.fromJson({
      'hitPoints': {
        'current': currentHp,
        'maximum': maxHp,
        'temporary': isCharacterFormat
            ? _optionalInt(
                combat['临时 HP'] ?? characterHitPoints['temporary'],
                fallback: 0,
              )
            : _requiredInt(combat['临时 HP'], '临时 HP'),
      },
      'deathSaves': {
        'successes': isCharacterFormat
            ? _optionalInt(combat['死亡豁免成功'], fallback: 0)
            : _requiredInt(combat['死亡豁免成功'], '死亡豁免成功'),
        'failures': isCharacterFormat
            ? _optionalInt(combat['死亡豁免失败'], fallback: 0)
            : _requiredInt(combat['死亡豁免失败'], '死亡豁免失败'),
      },
      'resources': resources.map((item) => item.toJson()).toList(),
      'conditions': conditions.map((item) => item.toJson()).toList(),
      'items': items.map((item) => item.toJson()).toList(),
      'extensions': extensions,
    });
    final unknownSections = <String, Object?>{};
    for (final entry in sections.entries) {
      if (_knownSections.contains(_normalizeHeading(entry.key))) continue;
      final text = _nodesToReadableMarkdown(entry.value);
      if (text.isNotEmpty) unknownSections[entry.key] = text;
    }
    final notes = sections['笔记']?.map(_nodeText).join('\n').trim() ?? '';
    final description = sections['描述']?.map(_nodeText).join('\n').trim() ?? '';
    final monster = _parseMonsterGroups(envelope.body);
    final now = DateTime.now().toUtc().toIso8601String();
    final characterKind = _metadataText(metadata, 'kind', fallback: 'player');
    final challengeRating = _metadataText(metadata, 'challengeRating');
    final raceSummary = basics['种族']?.trim().isNotEmpty == true
        ? basics['种族']!.trim()
        : _characterRaceSummary(metadata);
    final classSummary = basics['职业']?.trim().isNotEmpty == true
        ? basics['职业']!.trim()
        : characterKind == 'monster'
        ? [
            '怪物',
            if (challengeRating.isNotEmpty) 'CR $challengeRating',
          ].join(' · ')
        : '';
    final resolvedAbilities = <String, int>{
      for (final entry in _abilityLabels.entries)
        entry.key: isCharacterFormat
            ? _optionalInt(
                abilities[entry.value] ?? characterAbilities[entry.key],
                fallback: 10,
              )
            : _requiredInt(abilities[entry.value], entry.value),
    };
    final characterData = isCharacterFormat
        ? <String, Object?>{
            'kind': characterKind,
            for (final field in const [
              'templateRef',
              'size',
              'creatureType',
              'alignment',
              'challengeRating',
              'proficiencyBonus',
            ])
              if (metadata[field] != null) field: metadata[field],
            if (characterHitPoints['formula'] != null)
              'hitPointFormula': characterHitPoints['formula'],
            'speed': characterSpeed,
          }
        : const <String, Object?>{};
    final canonicalData = _map(canonicalSnapshot['data']);
    final data = <String, Object?>{
      ...canonicalData,
      'characterState': state.toJson(),
      if (description.isNotEmpty) 'description': description,
      if (isCharacterFormat) 'character': characterData,
      if (monster.isNotEmpty) 'monster': monster,
      if (unknownSections.isNotEmpty) 'markdownSections': unknownSections,
    };
    final contentReferences = _mapList(
      canonicalSnapshot['contentReferences'],
    ).map(CharacterContentReference.fromJson).toList(growable: false);
    final character = CharacterSheet(
      id: _metadataText(metadata, 'id', fallback: _localId()),
      ownerUserId: _metadataText(metadata, 'owner', fallback: 'local'),
      name: basics['名称']?.trim().isNotEmpty == true
          ? basics['名称']!.trim()
          : _metadataText(metadata, 'name', fallback: title),
      avatarUrl: _metadataText(metadata, 'avatar').nullIfEmpty,
      system: _metadataText(metadata, 'system', fallback: 'dnd5e-2024'),
      level: level,
      classSummary: classSummary,
      raceSummary: raceSummary,
      currentHp: state.hitPoints.current,
      maxHp: state.hitPoints.maximum,
      armorClass: isCharacterFormat
          ? _optionalInt(combat['AC'] ?? metadata['armorClass'], fallback: 10)
          : _requiredInt(combat['AC'], 'AC'),
      speed: isCharacterFormat
          ? _optionalInt(combat['速度'] ?? characterSpeed['walk'], fallback: 30)
          : _requiredInt(combat['速度'], '速度'),
      initiativeBonus: isCharacterFormat
          ? _optionalInt(
              combat['先攻'] ?? metadata['initiativeBonus'],
              fallback: Dnd5eRules.abilityModifier(resolvedAbilities['dex']!),
            )
          : _requiredInt(combat['先攻'], '先攻'),
      abilities: resolvedAbilities,
      saves: {
        for (final entry in _abilityLabels.entries)
          entry.key: saves[entry.value]?.trim() == '是',
      },
      skills: {
        for (final entry in skills.entries)
          entry.key: entry.value.trim() == '是',
      },
      inventory: state.items.map((item) => item.toJson()).toList(),
      currency: {
        for (final entry in currency.entries)
          entry.key: _requiredInt(entry.value, '货币 ${entry.key}'),
      },
      notes: notes,
      data: data,
      createdAt: _metadataText(metadata, 'createdAt', fallback: now),
      updatedAt: _metadataText(metadata, 'updatedAt', fallback: now),
      contentReferences: contentReferences,
    );
    return CharacterMarkdownImport(
      character: character,
      state: state,
      mode: _metadataText(metadata, 'mode') == 'campaignSnapshot'
          ? CharacterMarkdownMode.campaignSnapshot
          : CharacterMarkdownMode.profile,
    );
  }
}

void _writeMonsterEntry(StringBuffer buffer, Map<String, Object?> entry) {
  final name = '${entry['name'] ?? ''}'.trim();
  if (name.isEmpty) return;
  final description = '${entry['description'] ?? ''}'.trim();
  buffer
    ..writeln('### $name')
    ..writeln();
  if (description.isNotEmpty) {
    buffer
      ..writeln(description)
      ..writeln();
  }
  final attack = _map(entry['attack']);
  final damage = _map(entry['damage']);
  final uses = _map(entry['uses']);
  final attackBonus = attack['bonus'] ?? entry['attackBonus'];
  if (attackBonus != null) {
    buffer.writeln('**命中加值：** ${_signedNumber(attackBonus)}');
  }
  if ('${attack['reach'] ?? ''}'.trim().isNotEmpty) {
    buffer.writeln('**触及：** ${attack['reach']}');
  }
  if ('${attack['range'] ?? ''}'.trim().isNotEmpty) {
    buffer.writeln('**射程：** ${attack['range']}');
  }
  if ('${damage['expression'] ?? ''}'.trim().isNotEmpty) {
    final damageType = '${damage['type'] ?? ''}'.trim();
    buffer.writeln(
      '**伤害：** `${damage['expression']}`${damageType.isEmpty ? '' : ' $damageType'}',
    );
  }
  if (uses['maximum'] != null) {
    buffer.writeln('**次数：** ${uses['maximum']}');
  }
  if ('${uses['restoreOn'] ?? ''}'.trim().isNotEmpty) {
    buffer.writeln('**恢复：** ${uses['restoreOn']}');
  }
  if (entry['cost'] != null) {
    buffer.writeln('**消耗：** ${entry['cost']}');
  }
  if ('${entry['ability'] ?? ''}'.trim().isNotEmpty) {
    buffer.writeln('**施法属性：** ${entry['ability']}');
  }
  if (entry['saveDc'] != null) {
    buffer.writeln('**豁免 DC：** ${entry['saveDc']}');
  }
  final spells = entry['spells'];
  if (spells is List && spells.isNotEmpty) {
    buffer.writeln('**法术：** ${spells.join('、')}');
  }
  final metadata = base64UrlEncode(utf8.encode(jsonEncode(entry)));
  buffer
    ..writeln()
    ..writeln('<!-- dnd:monster-entry=$metadata -->')
    ..writeln();
}

void _writeRuleSnapshotSection(
  StringBuffer buffer, {
  required String title,
  required List<String> entryIds,
  required Map<String, Object?> snapshots,
}) {
  final entries = entryIds
      .map((id) => _map(snapshots[id]))
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
  if (entries.isEmpty) return;
  buffer
    ..writeln()
    ..writeln('## $title')
    ..writeln();
  for (final entry in entries) {
    final name = '${entry['name'] ?? entry['id'] ?? '未命名条目'}'.trim();
    final summary = '${entry['summary'] ?? ''}'.trim();
    buffer
      ..writeln('### $name')
      ..writeln();
    if (summary.isNotEmpty) {
      buffer
        ..writeln(summary)
        ..writeln();
    }
    for (final block in _mapList(entry['body'])) {
      final text = '${block['text'] ?? ''}'.trim();
      if (text.isNotEmpty && text != summary) {
        buffer
          ..writeln(text)
          ..writeln();
      }
      final items = block['items'];
      if (items is List) {
        for (final item in items) {
          buffer.writeln('- $item');
        }
        if (items.isNotEmpty) buffer.writeln();
      }
    }
  }
}

List<String> _actionEntryIds(Object? value) => _mapList(value)
    .map((entry) => '${entry['entryId'] ?? ''}'.trim())
    .where((id) => id.isNotEmpty)
    .toSet()
    .toList(growable: false);

List<String> _stringList(Object? value) => value is List
    ? value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const <String>[];

Map<String, Object?> _readCanonicalSnapshot(Object? value) {
  final raw = '$value'.trim();
  if (raw.isEmpty || raw == 'null') return const <String, Object?>{};
  try {
    final encoded = base64Url.normalize(raw);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(encoded)));
    return decoded is Map
        ? Map<String, Object?>.from(decoded)
        : const <String, Object?>{};
  } catch (_) {
    return const <String, Object?>{};
  }
}

Map<String, Object?> _parseMonsterGroups(String body) {
  final result = <String, Object?>{};
  final metadataMatch = RegExp(
    r'<!--\s*dnd:monster-data=([A-Za-z0-9_=-]+)\s*-->',
  ).firstMatch(body);
  if (metadataMatch != null) {
    try {
      result.addAll(
        _deepMap(
          jsonDecode(utf8.decode(base64Url.decode(metadataMatch.group(1)!))),
        ),
      );
    } on FormatException {
      // The readable summary remains importable if hidden metadata was edited.
    }
  }
  final sectionPattern = RegExp(r'^##\s+([^\n]+)\s*$', multiLine: true);
  final headings = sectionPattern.allMatches(body).toList(growable: false);
  for (var index = 0; index < headings.length; index++) {
    final heading = _normalizeHeading(headings[index].group(1)!);
    final group = _monsterSectionGroups[heading];
    if (group == null) continue;
    final start = headings[index].end;
    final end = index + 1 < headings.length
        ? headings[index + 1].start
        : body.length;
    final section = body.substring(start, end);
    final entries = _parseMonsterEntries(section, group);
    if (entries.isNotEmpty) result[group] = entries;
  }
  return result;
}

List<Map<String, Object?>> _parseMonsterEntries(String section, String group) {
  final headingPattern = RegExp(r'^###\s+([^\n]+)\s*$', multiLine: true);
  final headings = headingPattern.allMatches(section).toList(growable: false);
  final entries = <Map<String, Object?>>[];
  for (var index = 0; index < headings.length; index++) {
    final name = headings[index].group(1)!.trim();
    final start = headings[index].end;
    final end = index + 1 < headings.length
        ? headings[index + 1].start
        : section.length;
    final source = section.substring(start, end);
    final metadataMatch = RegExp(
      r'<!--\s*dnd:monster-entry=([A-Za-z0-9_=-]+)\s*-->',
    ).firstMatch(source);
    var entry = <String, Object?>{'id': _slug(name)};
    if (metadataMatch != null) {
      try {
        final decoded = jsonDecode(
          utf8.decode(base64Url.decode(metadataMatch.group(1)!)),
        );
        if (decoded is Map) entry = _deepMap(decoded);
      } on FormatException {
        // The visible fields below still form a valid editable entry.
      }
    }
    final visible = source
        .replaceAll(RegExp(r'<!--\s*dnd:monster-entry=.*?-->'), '')
        .trim();
    final lines = visible.split('\n');
    final descriptionLines = <String>[];
    for (final line in lines) {
      if (line.trimLeft().startsWith('**')) break;
      descriptionLines.add(line);
    }
    entry['name'] = name;
    entry['description'] = descriptionLines.join('\n').trim();

    final attackBonus = _readMonsterInt(visible, '命中加值');
    if (attackBonus != null) {
      if (group == 'spellcasting' || entry.containsKey('attackBonus')) {
        entry['attackBonus'] = attackBonus;
      } else {
        entry['attack'] = {..._map(entry['attack']), 'bonus': attackBonus};
      }
    }
    final reach = _readMonsterText(visible, '触及');
    final range = _readMonsterText(visible, '射程');
    if (reach.isNotEmpty || range.isNotEmpty) {
      entry['attack'] = {
        ..._map(entry['attack']),
        if (reach.isNotEmpty) 'reach': reach,
        if (range.isNotEmpty) 'range': range,
      };
    }
    final damageMatch = RegExp(
      r'^\*\*伤害：\*\*\s*`([^`]+)`\s*(.*)$',
      multiLine: true,
    ).firstMatch(visible);
    if (damageMatch != null) {
      entry['damage'] = {
        'expression': damageMatch.group(1)!.trim(),
        if (damageMatch.group(2)!.trim().isNotEmpty)
          'type': damageMatch.group(2)!.trim(),
      };
    }
    final maximum = _readMonsterInt(visible, '次数');
    final restoreOn = _readMonsterText(visible, '恢复');
    if (maximum != null || restoreOn.isNotEmpty) {
      final uses = _map(entry['uses']);
      if (maximum != null) uses['maximum'] = maximum;
      if (restoreOn.isNotEmpty) uses['restoreOn'] = restoreOn;
      entry['uses'] = uses;
    }
    final cost = _readMonsterInt(visible, '消耗');
    if (cost != null) entry['cost'] = cost;
    final ability = _readMonsterText(visible, '施法属性');
    if (ability.isNotEmpty) entry['ability'] = ability;
    final saveDc = _readMonsterInt(visible, '豁免 DC');
    if (saveDc != null) entry['saveDc'] = saveDc;
    final spells = _readMonsterText(visible, '法术');
    if (spells.isNotEmpty) {
      entry['spells'] = spells
          .split(RegExp(r'[、,，]'))
          .map((spell) => spell.trim())
          .where((spell) => spell.isNotEmpty)
          .toList(growable: false);
    }
    entries.add(entry);
  }
  return entries;
}

int? _readMonsterInt(String source, String label) {
  final value = _readMonsterText(source, label).replaceFirst('+', '');
  return int.tryParse(value);
}

String _readMonsterText(String source, String label) {
  final match = RegExp(
    '^\\*\\*${RegExp.escape(label)}：\\*\\*\\s*(.+)\$',
    multiLine: true,
  ).firstMatch(source);
  return match?.group(1)?.trim() ?? '';
}

void _writeMonsterMetadata(StringBuffer buffer, Map<String, Object?> metadata) {
  final senses = metadata['senses'];
  final languages = metadata['languages'];
  final challenge = _map(metadata['challenge']);
  if (senses is List && senses.isNotEmpty) {
    buffer.writeln('- **感官：** ${senses.join('、')}');
  } else if ('$senses'.trim().isNotEmpty && senses != null) {
    buffer.writeln('- **感官：** $senses');
  }
  if (languages is List && languages.isNotEmpty) {
    buffer.writeln('- **语言：** ${languages.join('、')}');
  } else if ('$languages'.trim().isNotEmpty && languages != null) {
    buffer.writeln('- **语言：** $languages');
  }
  if (challenge.isNotEmpty) {
    final rating = '${challenge['rating'] ?? ''}'.trim();
    final proficiency = challenge['proficiencyBonus'];
    if (rating.isNotEmpty) {
      buffer.writeln(
        '- **挑战等级：** $rating'
        '${proficiency == null ? '' : '（熟练加值 +$proficiency）'}',
      );
    }
  }
  final encoded = base64UrlEncode(utf8.encode(jsonEncode(metadata)));
  buffer
    ..writeln()
    ..writeln('<!-- dnd:monster-data=$encoded -->')
    ..writeln();
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(_deepMap).toList(growable: false);
}

String _signedNumber(Object value) {
  final number = value is num ? value : num.tryParse('$value');
  if (number == null || number < 0) return '$value';
  return '+$value';
}

String _normalizeTableWhitespace(String source) {
  final lines = source.split('\n');
  final normalized = <String>[];
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (line.trim().isEmpty &&
        normalized.lastOrNull?.trimLeft().startsWith('|') == true) {
      var next = index + 1;
      while (next < lines.length && lines[next].trim().isEmpty) {
        next += 1;
      }
      if (next < lines.length && lines[next].trimLeft().startsWith('|')) {
        continue;
      }
    }
    normalized.add(line);
  }
  return normalized.join('\n');
}

class _MarkdownEnvelope {
  const _MarkdownEnvelope({required this.metadata, required this.body});

  final Map<String, Object?> metadata;
  final String body;
}

_MarkdownEnvelope _parseFrontMatter(String source) {
  final normalized = source.replaceAll('\r\n', '\n');
  if (!normalized.startsWith('---\n')) {
    throw const CharacterMarkdownFormatException('角色卡缺少 YAML 文件头');
  }
  final end = normalized.indexOf('\n---\n', 4);
  if (end < 0) {
    throw const CharacterMarkdownFormatException('角色卡 YAML 文件头未闭合');
  }
  try {
    final yaml = loadYaml(normalized.substring(4, end));
    return _MarkdownEnvelope(
      metadata: _deepMap(yaml),
      body: normalized.substring(end + 5),
    );
  } catch (error) {
    throw CharacterMarkdownFormatException('角色卡 YAML 无法解析：$error');
  }
}

Map<String, List<md.Node>> _collectSections(List<md.Node> nodes) {
  final sections = <String, List<md.Node>>{};
  String? current;
  for (final node in nodes) {
    if (node is md.Element && node.tag == 'h2') {
      current = _normalizeHeading(node.textContent);
      sections.putIfAbsent(current, () => []);
    } else if (current != null) {
      sections[current]!.add(node);
    }
  }
  return sections;
}

String _firstHeading(List<md.Node> nodes, int level) {
  for (final node in nodes) {
    if (node is md.Element && node.tag == 'h$level') {
      return node.textContent.trim();
    }
  }
  throw const CharacterMarkdownFormatException('角色卡缺少名称标题');
}

Map<String, String> _tableMap(
  List<md.Node>? nodes, {
  required int keyColumn,
  required int valueColumn,
}) {
  final rows = _tableRows(nodes);
  return {
    for (final row in rows)
      if (row.length > valueColumn)
        _stripComment(row[keyColumn]).trim(): _stripComment(
          row[valueColumn],
        ).trim(),
  };
}

List<List<String>> _tableRows(List<md.Node>? nodes) {
  final table = nodes?.whereType<md.Element>().where(
    (node) => node.tag == 'table',
  );
  if (table == null || table.isEmpty) return const [];
  final rows = <List<String>>[];
  void visit(md.Node node) {
    if (node is! md.Element) return;
    if (node.tag == 'tr') {
      final cells =
          node.children
              ?.whereType<md.Element>()
              .where((child) => child.tag == 'td')
              .map((child) => child.textContent.trim())
              .toList() ??
          const <String>[];
      if (cells.isNotEmpty) rows.add(cells);
      return;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      visit(child);
    }
  }

  visit(table.first);
  return rows;
}

List<CharacterResource> _parseResources(List<md.Node>? nodes, String source) {
  final rows = _tableRows(nodes);
  return [
    for (final row in rows)
      if (row.length >= 5)
        CharacterResource(
          id: _stableId(row[0], source, fallback: _slug(row[0])),
          name: _stripComment(row[0]).trim(),
          current: _requiredInt(row[1], '资源当前值'),
          maximum: _requiredInt(row[2], '资源最大值'),
          restoreOn: _restoreValue(row[3]),
          sourceRef: null,
          custom: row[4].trim() == '是',
        ),
  ];
}

List<CharacterCondition> _parseConditions(List<md.Node>? nodes, String source) {
  final list = nodes?.whereType<md.Element>().where((node) => node.tag == 'ul');
  if (list == null || list.isEmpty) return const [];
  return [
    for (final item
        in list.first.children?.whereType<md.Element>() ?? const <md.Element>[])
      if (_stripComment(item.textContent).trim() != '无')
        CharacterCondition(
          id: _stableId(
            item.textContent,
            source,
            fallback: _slug(item.textContent),
          ),
          type: _stripComment(item.textContent).split('，').first.trim(),
          remaining: _remaining(item.textContent),
          metadata: const {},
        ),
  ];
}

List<CharacterItem> _parseItems(List<md.Node>? nodes, String source) {
  final rows = _tableRows(nodes);
  return [
    for (final row in rows)
      if (row.length >= 4)
        CharacterItem(
          id: _stableId(row[0], source, fallback: _slug(row[0])),
          name: _stripComment(row[0]).trim(),
          templateRef: null,
          quantity: _requiredInt(row[1], '装备数量'),
          equipped: row[2].trim() == '是',
          attuned: row[3].trim() == '是',
          instanceData: const {},
        ),
  ];
}

String _stableId(String value, String source, {required String fallback}) {
  final direct = RegExp(r'dnd:id=([A-Za-z0-9_.:/-]+)').firstMatch(value);
  if (direct != null) return direct.group(1)!;
  final visible = _stripComment(value).trim();
  final candidates = RegExp(
    '<!--\\s*dnd:id=([A-Za-z0-9_.:/-]+)\\s*-->',
  ).allMatches(source);
  for (final candidate in candidates) {
    final start = (candidate.start - 120).clamp(0, source.length);
    final end = (candidate.end + 20).clamp(0, source.length);
    if (source.substring(start, end).contains(visible)) {
      return candidate.group(1)!;
    }
  }
  return fallback;
}

String _nodeText(md.Node node) {
  if (node is md.Element) return node.textContent.trim();
  if (node is md.Text) return node.text.trim();
  return '';
}

String _nodesToReadableMarkdown(List<md.Node> nodes) {
  final blocks = <String>[];
  for (final node in nodes) {
    if (node is md.Text) {
      if (node.text.trim().isNotEmpty) blocks.add(node.text.trim());
      continue;
    }
    if (node is! md.Element) continue;
    final heading = RegExp(r'^h([3-6])$').firstMatch(node.tag);
    if (heading != null) {
      blocks.add(
        '${'#' * int.parse(heading.group(1)!)} ${node.textContent.trim()}',
      );
      continue;
    }
    if (node.tag == 'ul' || node.tag == 'ol') {
      var index = 0;
      final items = <String>[];
      for (final child in node.children ?? const <md.Node>[]) {
        if (child is! md.Element || child.tag != 'li') continue;
        index += 1;
        final marker = node.tag == 'ol' ? '$index.' : '-';
        items.add('$marker ${child.textContent.trim()}');
      }
      if (items.isNotEmpty) blocks.add(items.join('\n'));
      continue;
    }
    if (node.tag == 'blockquote') {
      blocks.add(
        node.textContent.trim().split('\n').map((line) => '> $line').join('\n'),
      );
      continue;
    }
    final text = node.textContent.trim();
    if (text.isNotEmpty) blocks.add(text);
  }
  return blocks.join('\n\n').trim();
}

CharacterDocument _stateFor(CharacterSheet character) {
  final canonical = _map(character.dataMap['characterState']);
  return CharacterDocument.fromJson({
    ...canonical,
    'hitPoints': {
      ..._map(canonical['hitPoints']),
      'current': character.currentHp,
      'maximum': character.maxHp,
      'temporary':
          _map(canonical['hitPoints'])['temporary'] ?? character.temporaryHp,
    },
    'conditions': canonical['conditions'] ?? character.conditions,
    'items': canonical['items'] ?? character.inventoryList,
  });
}

String _encodeYamlMap(Map<String, Object?> values, {required int indent}) {
  if (values.isEmpty) return '${' ' * indent}{}\n';
  final buffer = StringBuffer();
  for (final entry in values.entries) {
    final prefix = ' ' * indent;
    if (entry.value is Map) {
      buffer
        ..writeln('$prefix${entry.key}:')
        ..write(_encodeYamlMap(_map(entry.value), indent: indent + 2));
    } else {
      buffer.writeln('$prefix${entry.key}: ${_yamlScalar(entry.value)}');
    }
  }
  return buffer.toString();
}

String _yamlScalar(Object? value) {
  if (value == null) return 'null';
  if (value is num || value is bool) return '$value';
  return "'${'$value'.replaceAll("'", "''")}'";
}

String _cell(String value) =>
    value.replaceAll('|', r'\|').replaceAll('\n', ' ');
String _comment(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9_.:/-]'), '-');
String _stripComment(String value) =>
    value.replaceAll(RegExp(r'<!--.*?-->'), '');
String _normalizeHeading(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').trim();
String _slug(String value) {
  final slug = _stripComment(value)
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff_-]'), '');
  return slug.isEmpty ? 'entry-${DateTime.now().microsecondsSinceEpoch}' : slug;
}

int? _remaining(String value) {
  final match = RegExp(r'剩余\s*(\d+)').firstMatch(value);
  return match == null ? null : int.parse(match.group(1)!);
}

int _requiredInt(Object? value, String field) {
  final parsed = int.tryParse('$value'.trim());
  if (parsed == null) {
    throw CharacterMarkdownFormatException('$field 必须是整数');
  }
  return parsed;
}

int _optionalInt(Object? value, {required int fallback}) {
  if (value is num) return value.toInt();
  return int.tryParse('$value'.trim()) ?? fallback;
}

int _characterFieldInt(
  Object? readableValue,
  Object? structuredValue, {
  required String field,
  required int fallback,
}) {
  if (readableValue != null) return _requiredInt(readableValue, field);
  return _optionalInt(structuredValue, fallback: fallback);
}

String _characterRaceSummary(Map<String, Object?> metadata) {
  final parts = [
    _metadataText(metadata, 'size'),
    _metadataText(metadata, 'creatureType'),
  ].where((value) => value.isNotEmpty).toList(growable: false);
  return parts.join(' ');
}

String _safeCharacterKind(String value) {
  return switch (value) {
    'player' || 'npc' || 'monster' || 'companion' => value,
    _ => 'player',
  };
}

int _integer(Object? value) => value is num ? value.toInt() : 0;
String _restoreLabel(String value) => switch (value) {
  'shortRest' => '短休',
  'none' => '不恢复',
  _ => '长休',
};
String _restoreValue(String value) => switch (value.trim()) {
  '短休' => 'shortRest',
  '不恢复' => 'none',
  _ => 'longRest',
};

String _metadataText(
  Map<String, Object?> metadata,
  String key, {
  String fallback = '',
}) {
  final value = metadata[key];
  return value == null ? fallback : '$value';
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.map((key, item) => MapEntry('$key', item)) : {};

Map<String, Object?> _deepMap(Object? value) {
  if (value is! Map) return {};
  return value.map(
    (key, item) => MapEntry(
      '$key',
      item is Map
          ? _deepMap(item)
          : item is List
          ? item.map((child) => child is Map ? _deepMap(child) : child).toList()
          : item,
    ),
  );
}

String _localId() => 'imported-${DateTime.now().microsecondsSinceEpoch}';

const _abilityLabels = <String, String>{
  'str': '力量',
  'dex': '敏捷',
  'con': '体质',
  'int': '智力',
  'wis': '感知',
  'cha': '魅力',
};

const _knownSections = {
  '基础资料',
  '属性',
  '豁免',
  '技能',
  '战斗',
  '资源',
  '状态',
  '装备',
  '货币',
  '描述',
  '笔记',
  '怪物资料',
  '规则特性',
  '法术',
  '角色动作',
};

const _monsterGroupSections = <String, String>{
  'traits': '特性',
  'actions': '动作',
  'bonusActions': '附赠动作',
  'reactions': '反应',
  'legendaryActions': '传奇动作',
  'spellcasting': '施法',
};

const _monsterSectionGroups = <String, String>{
  '特性': 'traits',
  '特质': 'traits',
  '动作': 'actions',
  '附赠动作': 'bonusActions',
  '反应': 'reactions',
  '传奇动作': 'legendaryActions',
  '施法': 'spellcasting',
};

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
