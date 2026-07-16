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

/// Whether [ContentMetadataView] should render for [entry].
///
/// 条目正文里自带的 [StatBlockBlock] 已经展示了结构化属性（法术的环阶/学派、
/// 装备的价格/伤害等），此时再渲染 [ContentMetadataView] 会重复显示同一份
/// 信息。只有当正文没有 statBlock 且 structured 非空时，才用统一的 metadata
/// 视图补齐展示。
bool shouldShowMetadataView(ContentEntry entry) {
  if (entry.structured.isEmpty) return false;
  return entry.body.whereType<StatBlockBlock>().isEmpty;
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
        if (shouldShowMetadataView(entry)) ContentMetadataView(entry: entry),
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
