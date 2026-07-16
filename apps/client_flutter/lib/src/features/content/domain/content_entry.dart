import 'content_block.dart';
import '../../rules/domain/character_rule_definition.dart';

/// 条目来源标识。运行时字段，不参与 JSON 序列化，由具体 Repository 决定。
enum ContentOrigin { local, campaign }

class ContentRelation {
  const ContentRelation({required this.type, required this.targetId});

  static const allowedTypes = {
    'subclassOf',
    'featureOf',
    'spellOf',
    'requires',
    'replaces',
    'related',
  };

  final String type;
  final String targetId;

  factory ContentRelation.fromJson(Map<String, Object?> json) {
    final type = json['type'];
    final targetId = json['targetId'];
    if (type is! String || !allowedTypes.contains(type)) {
      throw FormatException('Unknown content relation type: $type');
    }
    if (targetId is! String || targetId.trim().isEmpty) {
      throw const FormatException('Content relation targetId is required');
    }
    return ContentRelation(type: type, targetId: targetId);
  }

  Map<String, Object?> toJson() => {'type': type, 'targetId': targetId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentRelation &&
          type == other.type &&
          targetId == other.targetId;

  @override
  int get hashCode => Object.hash(type, targetId);
}

class ContentSource {
  const ContentSource({required this.label});

  static const ContentSource empty = ContentSource(label: '');

  final String label;

  factory ContentSource.fromJson(Map<String, Object?> json) {
    return ContentSource(label: json['label'] as String? ?? '');
  }

  Map<String, Object?> toJson() => {'label': label};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ContentSource && label == other.label;

  @override
  int get hashCode => label.hashCode;
}

class ContentEntry {
  const ContentEntry({
    required this.id,
    required this.type,
    required this.slug,
    required this.name,
    required this.body,
    required this.revision,
    this.aliases = const <String>[],
    this.summary = '',
    this.structured = const <String, Object?>{},
    this.tags = const <String>[],
    this.source = ContentSource.empty,
    this.origin = ContentOrigin.local,
    this.relations = const <ContentRelation>[],
    this.rules,
  });

  final String id;
  final String type;
  final String slug;
  final String name;
  final List<ContentBlock> body;
  final int revision;
  final List<String> aliases;
  final String summary;
  final Map<String, Object?> structured;
  final List<String> tags;
  final ContentSource source;
  final List<ContentRelation> relations;
  final CharacterRuleDefinition? rules;

  /// 运行时来源标识，不写入 JSON。组合 Repository 会为战役缓存条目设置为 [ContentOrigin.campaign]。
  final ContentOrigin origin;

  factory ContentEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final type = json['type'];
    final slug = json['slug'];
    final name = json['name'];
    final bodyJson = json['body'];
    final revision = json['revision'];
    if (id == null ||
        type == null ||
        slug == null ||
        name == null ||
        bodyJson == null ||
        revision == null) {
      throw FormatException('Missing required ContentEntry fields: $json');
    }
    final body = (bodyJson as List<Object?>)
        .map((block) => ContentBlock.fromJson(block as Map<String, Object?>))
        .toList();
    final aliasesJson = json['aliases'] as List<Object?>?;
    final structuredJson = json['structured'];
    final tagsJson = json['tags'] as List<Object?>?;
    final sourceJson = json['source'];
    final relationsJson = json['relations'];
    final rulesJson = json['rules'];
    return ContentEntry(
      id: id as String,
      type: type as String,
      slug: slug as String,
      name: name as String,
      body: body,
      revision: (revision as num).toInt(),
      aliases:
          aliasesJson?.map((item) => item as String).toList() ??
          const <String>[],
      summary: json['summary'] as String? ?? '',
      structured: structuredJson == null
          ? const <String, Object?>{}
          : Map<String, Object?>.from(structuredJson as Map),
      tags:
          tagsJson?.map((item) => item as String).toList() ?? const <String>[],
      source: sourceJson == null
          ? ContentSource.empty
          : ContentSource.fromJson(sourceJson as Map<String, Object?>),
      relations: relationsJson is List
          ? relationsJson
                .map(
                  (item) => ContentRelation.fromJson(
                    Map<String, Object?>.from(item as Map),
                  ),
                )
                .toList(growable: false)
          : const <ContentRelation>[],
      rules: rulesJson == null
          ? null
          : CharacterRuleDefinition.fromJson(
              Map<String, Object?>.from(rulesJson as Map),
            ),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'slug': slug,
    'name': name,
    'body': body.map((block) => block.toJson()).toList(),
    'revision': revision,
    'aliases': aliases,
    'summary': summary,
    'structured': structured,
    'tags': tags,
    'source': source.toJson(),
    if (relations.isNotEmpty)
      'relations': relations.map((relation) => relation.toJson()).toList(),
    if (rules != null) 'rules': rules!.toJson(),
  };

  /// 复制条目并替换来源字段。仅用于运行时组合 Repository。
  ContentEntry withOrigin(ContentOrigin origin) {
    return ContentEntry(
      id: id,
      type: type,
      slug: slug,
      name: name,
      body: body,
      revision: revision,
      aliases: aliases,
      summary: summary,
      structured: structured,
      tags: tags,
      source: source,
      origin: origin,
      relations: relations,
      rules: rules,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentEntry &&
          id == other.id &&
          type == other.type &&
          slug == other.slug &&
          name == other.name &&
          revision == other.revision &&
          summary == other.summary &&
          source == other.source &&
          origin == other.origin &&
          _listEquals(relations, other.relations);

  @override
  int get hashCode => Object.hash(
    id,
    type,
    slug,
    name,
    revision,
    summary,
    source,
    origin,
    Object.hashAll(relations),
  );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
