import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/content_block.dart';

class ContentBlockView extends StatelessWidget {
  const ContentBlockView({
    required this.blocks,
    this.onOpenEntry,
    this.readAsset,
    this.packageId,
    super.key,
  });

  final List<ContentBlock> blocks;
  final ValueChanged<String>? onOpenEntry;
  final Future<Uint8List?> Function(String packageId, String relativePath)?
      readAsset;
  final String? packageId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks) _buildBlock(context, block),
      ],
    );
  }

  Widget _buildBlock(BuildContext context, ContentBlock block) {
    return switch (block) {
      HeadingBlock(:final level, :final text) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(text, style: _headingStyle(context, level)),
        ),
      ParagraphBlock(:final text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text),
        ),
      ListBlock(:final ordered, :final items) =>
        _ListView(ordered: ordered, items: items),
      TableBlock(:final headers, :final rows) =>
        _TableView(headers: headers, rows: rows),
      QuoteBlock(:final text) => _QuoteView(text: text),
      CalloutBlock(:final variant, :final text) =>
        _CalloutView(variant: variant, text: text),
      ImageBlock(:final asset, :final alt) => _ImageBlockView(
          asset: asset,
          alt: alt,
          packageId: packageId,
          readAsset: readAsset,
        ),
      StatBlockBlock(:final fields) => _StatBlockView(fields: fields),
      EntryLinkBlock(:final targetId, :final text) => Material(
          type: MaterialType.transparency,
          child: ListTile(
            title: Text(text),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenEntry == null ? null : () => onOpenEntry!(targetId),
          ),
        ),
      DiceExpressionBlock(:final expression, :final label) =>
        _DiceExpressionView(expression: expression, label: label),
    };
  }

  TextStyle? _headingStyle(BuildContext context, int level) {
    final theme = Theme.of(context);
    return switch (level) {
      1 => theme.textTheme.titleLarge,
      2 => theme.textTheme.titleMedium,
      _ => theme.textTheme.titleSmall,
    };
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.ordered, required this.items});

  final bool ordered;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ordered ? '${i + 1}. ' : '\u2022 '),
                Expanded(child: Text(items[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          for (final header in headers) DataColumn(label: Text(header)),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [for (final cell in row) DataCell(Text(cell))],
            ),
        ],
      ),
    );
  }
}

class _QuoteView extends StatelessWidget {
  const _QuoteView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.outline, width: 3),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    );
  }
}

class _CalloutView extends StatelessWidget {
  const _CalloutView({required this.variant, required this.text});

  final String variant;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (backgroundColor, foregroundColor) = switch (variant) {
      'info' => (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      'warning' =>
        (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
      'success' =>
        (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
      'danger' => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      _ => (colorScheme.surfaceContainerLow, colorScheme.onSurface),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: foregroundColor)),
    );
  }
}

class _ImageBlockView extends StatefulWidget {
  const _ImageBlockView({
    required this.asset,
    required this.alt,
    this.packageId,
    this.readAsset,
  });

  final String asset;
  final String alt;
  final String? packageId;
  final Future<Uint8List?> Function(String packageId, String relativePath)?
      readAsset;

  @override
  State<_ImageBlockView> createState() => _ImageBlockViewState();
}

class _ImageBlockViewState extends State<_ImageBlockView> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    final packageId = widget.packageId;
    final readAsset = widget.readAsset;
    if (packageId != null && readAsset != null) {
      _future = readAsset(packageId, widget.asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) {
      return _ImagePlaceholder(alt: widget.alt);
    }
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return _ImagePlaceholder(alt: widget.alt);
        }
        return Image.memory(bytes, semanticLabel: widget.alt);
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.alt});

  final String alt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(alt.isEmpty ? '（图片）' : alt),
    );
  }
}

class _StatBlockView extends StatelessWidget {
  const _StatBlockView({required this.fields});

  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in fields.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.value),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DiceExpressionView extends StatelessWidget {
  const _DiceExpressionView({required this.expression, required this.label});

  final String expression;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              expression,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodySmall),
            ],
            const Spacer(),
            FilledButton.tonal(
              onPressed: () {},
              child: const Text('投骰'),
            ),
          ],
        ),
      ),
    );
  }
}
