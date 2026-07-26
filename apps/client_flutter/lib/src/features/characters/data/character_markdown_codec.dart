import 'package:markdown/markdown.dart' as md;
import 'package:yaml/yaml.dart';

import '../domain/character.dart';
import '../domain/character_document.dart';

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
  }) {
    final state = _stateFor(character);
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('format: dnd-table-character/v1')
      ..writeln('mode: ${mode.name}')
      ..writeln('id: ${_yamlScalar(character.id)}')
      ..writeln('owner: ${_yamlScalar(character.ownerUserId)}')
      ..writeln('system: ${_yamlScalar(character.system)}')
      ..writeln('createdAt: ${_yamlScalar(character.createdAt)}')
      ..writeln('updatedAt: ${_yamlScalar(character.updatedAt)}');
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
    buffer
      ..writeln()
      ..writeln('## 笔记')
      ..writeln()
      ..writeln(character.notes.trimRight())
      ..writeln();
    final extraSections = _map(character.dataMap['markdownSections']);
    for (final entry in extraSections.entries) {
      if (_knownSections.contains(_normalizeHeading(entry.key))) continue;
      buffer
        ..writeln('## ${entry.key}')
        ..writeln()
        ..writeln('${entry.value}'.trim())
        ..writeln();
    }
    return buffer.toString();
  }

  CharacterMarkdownImport decode(String source) {
    final envelope = _parseFrontMatter(source);
    final metadata = envelope.metadata;
    if (metadata['format'] != 'dnd-table-character/v1') {
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
    final level = _requiredInt(basics['等级'], '等级');
    final currentHp = _requiredInt(combat['当前 HP'], '当前 HP');
    final maxHp = _requiredInt(combat['最大 HP'], '最大 HP');
    final resources = _parseResources(sections['资源'], envelope.body);
    final conditions = _parseConditions(sections['状态'], envelope.body);
    final items = _parseItems(sections['装备'], envelope.body);
    final extensions = _deepMap(metadata['extensions'])
      ..removeWhere((key, _) => !key.contains('.'));
    final state = CharacterDocument.fromJson({
      'hitPoints': {
        'current': currentHp,
        'maximum': maxHp,
        'temporary': _requiredInt(combat['临时 HP'], '临时 HP'),
      },
      'deathSaves': {
        'successes': _requiredInt(combat['死亡豁免成功'], '死亡豁免成功'),
        'failures': _requiredInt(combat['死亡豁免失败'], '死亡豁免失败'),
      },
      'resources': resources.map((item) => item.toJson()).toList(),
      'conditions': conditions.map((item) => item.toJson()).toList(),
      'items': items.map((item) => item.toJson()).toList(),
      'extensions': extensions,
    });
    final unknownSections = <String, Object?>{};
    for (final entry in sections.entries) {
      if (_knownSections.contains(_normalizeHeading(entry.key))) continue;
      final text = entry.value.map(_nodeText).join('\n\n').trim();
      if (text.isNotEmpty) unknownSections[entry.key] = text;
    }
    final notes = sections['笔记']?.map(_nodeText).join('\n').trim() ?? '';
    final now = DateTime.now().toUtc().toIso8601String();
    final data = <String, Object?>{
      'characterState': state.toJson(),
      if (unknownSections.isNotEmpty) 'markdownSections': unknownSections,
    };
    final character = CharacterSheet(
      id: _metadataText(metadata, 'id', fallback: _localId()),
      ownerUserId: _metadataText(metadata, 'owner', fallback: 'local'),
      name: basics['名称']?.trim().isNotEmpty == true
          ? basics['名称']!.trim()
          : title,
      avatarUrl: _metadataText(metadata, 'avatar').nullIfEmpty,
      system: _metadataText(metadata, 'system', fallback: 'dnd5e-2024'),
      level: level,
      classSummary: basics['职业']?.trim() ?? '',
      raceSummary: basics['种族']?.trim() ?? '',
      currentHp: state.hitPoints.current,
      maxHp: state.hitPoints.maximum,
      armorClass: _requiredInt(combat['AC'], 'AC'),
      speed: _requiredInt(combat['速度'], '速度'),
      initiativeBonus: _requiredInt(combat['先攻'], '先攻'),
      abilities: {
        for (final entry in _abilityLabels.entries)
          entry.key: _requiredInt(abilities[entry.value], entry.value),
      },
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
  '笔记',
};

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
