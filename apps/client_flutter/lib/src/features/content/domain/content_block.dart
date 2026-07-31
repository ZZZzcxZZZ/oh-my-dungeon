sealed class ContentBlock {
  const ContentBlock();

  String get text => '';

  Map<String, Object?> toJson();

  factory ContentBlock.fromJson(Map<String, Object?> json) {
    final type = json['type'];
    return switch (type) {
      'heading' => HeadingBlock(
        level: (json['level'] as num?)?.toInt() ?? 1,
        text: json['text']! as String,
      ),
      'paragraph' => ParagraphBlock(text: json['text']! as String),
      'list' => ListBlock(
        ordered: json['ordered'] as bool? ?? false,
        items: (json['items'] as List<Object?>)
            .map((item) => item as String)
            .toList(),
      ),
      'table' => TableBlock(
        headers: (json['headers'] as List<Object?>)
            .map((header) => header as String)
            .toList(),
        rows: (json['rows'] as List<Object?>)
            .map(
              (row) =>
                  (row as List<Object?>).map((cell) => cell as String).toList(),
            )
            .toList(),
      ),
      'quote' => QuoteBlock(text: json['text']! as String),
      'callout' => CalloutBlock(
        variant: json['variant'] as String? ?? 'info',
        text: json['text']! as String,
      ),
      'image' => ImageBlock(
        asset: json['asset']! as String,
        alt: json['alt'] as String? ?? '',
      ),
      'statBlock' => StatBlockBlock(
        fields: Map<String, String>.from(json['fields'] as Map),
      ),
      'entryLink' => EntryLinkBlock(
        targetId: json['targetId']! as String,
        text: json['text']! as String,
      ),
      'diceExpression' => DiceExpressionBlock(
        expression: json['expression']! as String,
        label: json['label'] as String? ?? '',
      ),
      _ => throw FormatException('Unsupported content block type: $type'),
    };
  }
}

final class HeadingBlock extends ContentBlock {
  const HeadingBlock({this.level = 1, required this.text});

  final int level;
  @override
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'heading',
    'level': level,
    'text': text,
  };
}

final class ParagraphBlock extends ContentBlock {
  const ParagraphBlock({required this.text});

  @override
  final String text;

  @override
  Map<String, Object?> toJson() => {'type': 'paragraph', 'text': text};
}

final class ListBlock extends ContentBlock {
  const ListBlock({this.ordered = false, required this.items});

  final bool ordered;
  final List<String> items;

  @override
  Map<String, Object?> toJson() => {
    'type': 'list',
    'ordered': ordered,
    'items': items,
  };
}

final class TableBlock extends ContentBlock {
  const TableBlock({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Map<String, Object?> toJson() => {
    'type': 'table',
    'headers': headers,
    'rows': rows,
  };
}

final class QuoteBlock extends ContentBlock {
  const QuoteBlock({required this.text});

  @override
  final String text;

  @override
  Map<String, Object?> toJson() => {'type': 'quote', 'text': text};
}

final class CalloutBlock extends ContentBlock {
  const CalloutBlock({this.variant = 'info', required this.text});

  final String variant;
  @override
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'callout',
    'variant': variant,
    'text': text,
  };
}

final class ImageBlock extends ContentBlock {
  const ImageBlock({required this.asset, this.alt = ''});

  final String asset;
  final String alt;

  @override
  Map<String, Object?> toJson() => {
    'type': 'image',
    'asset': asset,
    'alt': alt,
  };
}

final class StatBlockBlock extends ContentBlock {
  const StatBlockBlock({required this.fields});

  final Map<String, String> fields;

  @override
  Map<String, Object?> toJson() => {'type': 'statBlock', 'fields': fields};
}

final class EntryLinkBlock extends ContentBlock {
  const EntryLinkBlock({required this.targetId, required this.text});

  final String targetId;
  @override
  final String text;

  @override
  Map<String, Object?> toJson() => {
    'type': 'entryLink',
    'targetId': targetId,
    'text': text,
  };
}

final class DiceExpressionBlock extends ContentBlock {
  const DiceExpressionBlock({required this.expression, this.label = ''});

  final String expression;
  final String label;

  @override
  Map<String, Object?> toJson() => {
    'type': 'diceExpression',
    'expression': expression,
    'label': label,
  };
}
