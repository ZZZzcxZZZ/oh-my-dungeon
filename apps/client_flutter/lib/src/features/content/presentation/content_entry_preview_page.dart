import 'package:flutter/material.dart';

import '../domain/content_entry.dart';
import 'widgets/content_entry_reader.dart';

/// Lightweight Wiki reader for flows that already hold an offline entry set.
class ContentEntryPreviewPage extends StatelessWidget {
  const ContentEntryPreviewPage({
    required this.entry,
    required this.entries,
    super.key,
  });

  final ContentEntry entry;
  final List<ContentEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(entry.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    entry.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  ContentEntryReader(
                    entry: entry,
                    onOpenEntry: (entryId) =>
                        _openLinkedEntry(context, entryId),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLinkedEntry(BuildContext context, String entryId) {
    final linked = entries
        .where((candidate) => candidate.id == entryId)
        .firstOrNull;
    if (linked == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前资料包中找不到该条目')));
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            ContentEntryPreviewPage(entry: linked, entries: entries),
      ),
    );
  }
}

/// Opens a compact offline reader without taking the player away from the sheet.
Future<void> showContentEntryPreviewDialog(
  BuildContext context, {
  required ContentEntry entry,
  required List<ContentEntry> entries,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _ContentEntryPreviewDialog(initialEntry: entry, entries: entries),
  );
}

class _ContentEntryPreviewDialog extends StatefulWidget {
  const _ContentEntryPreviewDialog({
    required this.initialEntry,
    required this.entries,
  });

  final ContentEntry initialEntry;
  final List<ContentEntry> entries;

  @override
  State<_ContentEntryPreviewDialog> createState() =>
      _ContentEntryPreviewDialogState();
}

class _ContentEntryPreviewDialogState
    extends State<_ContentEntryPreviewDialog> {
  late ContentEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.initialEntry;
  }

  void _openLinkedEntry(String entryId) {
    final linked = widget.entries
        .where((candidate) => candidate.id == entryId)
        .firstOrNull;
    if (linked == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前资料包中找不到该条目')));
      return;
    }
    setState(() => _entry = linked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 840,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const Key('content-detail-close'),
                      tooltip: '关闭详情',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    ContentEntryReader(
                      entry: _entry,
                      onOpenEntry: _openLinkedEntry,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
