import 'package:flutter/material.dart';

import 'content_detail_page.dart';
import 'content_library_controller.dart';
import 'content_search_page.dart';

class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({
    required this.controller,
    required this.onImportRequested,
    super.key,
  });

  final ContentLibraryController controller;
  final VoidCallback onImportRequested;

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  void _showDetailDialog(String entryKey) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 960,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
          ),
          child: ContentDetailPage(
            entryKey: entryKey,
            controller: widget.controller,
            onOpenEntry: (nextEntryKey) {
              Navigator.of(dialogContext).pop();
              Future<void>.delayed(Duration.zero, () {
                if (mounted) _showDetailDialog(nextEntryKey);
              });
            },
            onImportRequested: widget.onImportRequested,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ContentSearchPage(
          controller: widget.controller,
          onSelect: (entry) => _showDetailDialog(entry.id),
          onImportRequested: widget.onImportRequested,
        ),
      ),
    );
  }
}
