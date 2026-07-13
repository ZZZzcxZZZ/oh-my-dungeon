import 'content_block.dart';

class ContentSource {
  const ContentSource({required this.label});

  static const ContentSource empty = ContentSource(label: '');

  final String label;

  factory ContentSource.fromJson(Map<String, Object?> json) {
    return ContentSource(label: json['label'] as String? ?? '');
  }

  Map<String, Object?> toJson() => {'label': label};
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
    return ContentEntry(
      id: id as String,
      type: type as String,
      slug: slug as String,
      name: name as String,
      body: body,
      revision: (revision as num).toInt(),
      aliases: aliasesJson?.map((item) => item as String).toList() ??
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
      };
}
