import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import 'content_block_view.dart';
import 'content_character_rules_view.dart';
import 'content_metadata_view.dart';

List<ContentBlock> deduplicatedContentBody(ContentEntry entry) {
  var firstVisible = 0;
  if (entry.body.isNotEmpty &&
      entry.body.first is HeadingBlock &&
      _normalized(entry.body.first.text) == _normalized(entry.name)) {
    firstVisible += 1;
  }
  if (firstVisible < entry.body.length &&
      entry.body[firstVisible] is ParagraphBlock &&
      entry.summary.trim().isNotEmpty &&
      _normalized(entry.body[firstVisible].text) ==
          _normalized(entry.summary)) {
    firstVisible += 1;
  }
  return entry.body.sublist(firstVisible);
}

String _normalized(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

class ContentEntryReader extends StatelessWidget {
  const ContentEntryReader({
    required this.entry,
    this.onOpenEntry,
    this.readAsset,
    this.packageId,
    this.showRules = true,
    super.key,
  });

  final ContentEntry entry;
  final ValueChanged<String>? onOpenEntry;
  final Future<Uint8List?> Function(String packageId, String relativePath)?
  readAsset;
  final String? packageId;
  final bool showRules;

  @override
  Widget build(BuildContext context) {
    final body = deduplicatedContentBody(entry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entry.summary.trim().isNotEmpty) ...[
          Text(entry.summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
        ],
        ContentMetadataView(entry: entry),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 20),
          ContentBlockView(
            blocks: body,
            packageId: packageId,
            readAsset: readAsset,
            onOpenEntry: onOpenEntry,
          ),
        ],
        if (showRules) ContentCharacterRulesView(entry: entry),
      ],
    );
  }
}
